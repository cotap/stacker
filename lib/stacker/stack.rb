require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/module/delegation'
require 'aws-sdk'
require 'memoist'
require 'securerandom'

require 'stacker/stack/errors'
require 'stacker/stack/capabilities'
require 'stacker/stack/parameters'
require 'stacker/stack/template'

module Stacker
  class Stack

    extend Memoist

    CLIENT_METHODS = %w[
      creation_time
      description
      last_updated_time
      status_reason
    ]

    SAFE_UPDATE_POLICY = <<-JSON
{
  "Statement" : [
    {
      "Effect" : "Deny",
      "Action" : ["Update:Replace", "Update:Delete"],
      "Principal" : "*",
      "Resource" : "*"
    },
    {
      "Effect" : "Allow",
      "Action" : "Update:*",
      "Principal" : "*",
      "Resource" : "*"
    }
  ]
}
JSON

    STATUS_COMPLETE_REGEX = /(ROLLBACK|CREATE|UPDATE)_(COMPLETE|FAILED)/

    attr_reader :region, :name, :options

    def initialize region, name, options = {}
      @region, @name, @options = region, name, options
    end

    def client
      res = region.client.describe_stacks(stack_name: name)
      res.stacks.first
    rescue Aws::CloudFormation::Errors::ValidationError
      nil
    end

    def exists?
      !!client
    end

    def status
      if client
        client.stack_status
      else
        "#{name}:\nStack with id #{name} does not exist"
      end
    end

    delegate *CLIENT_METHODS, to: :client
    memoize *CLIENT_METHODS

    %w[complete failed in_progress].each do |stage|
      define_method(:"#{stage}?") { status =~ /#{stage.upcase}/ }
    end

    def template
      @template ||= Template.new self
    end

    def parameters
      @parameters ||= Parameters.new self
    end

    def capabilities
      @capabilities ||= Capabilities.new self
    end

    def outputs
      @outputs ||= begin
        return {} unless complete?
        Hash[client.outputs.map do |output|
               [ output.output_key, output.output_value ]
             end]
      end
    end

    def create blocking = true
      if exists?
        Stacker.logger.warn 'Stack already exists'
        return
      end

      if parameters.missing.any?
        raise MissingParameters.new(
          "Required parameters missing: #{parameters.missing.join ', '}"
        )
      end

      Stacker.logger.info 'Creating stack'

      params = parameters.resolved.map do |k, v|
        {
          parameter_key: k,
          parameter_value: v
        }
      end

      region.client.create_stack(
        stack_name: name,
        template_body: template.local_raw,
        parameters: params,
        capabilities: capabilities.local
      )

      wait_until_complete if blocking
    rescue Aws::CloudFormation::Errors::ValidationError, ArgumentError => err
      raise Error.new err.message
    end

    def update options = {}
      options.assert_valid_keys(:blocking, :allow_destructive)

      blocking = options.fetch(:blocking, true)
      allow_destructive = options.fetch(:allow_destructive, false)

      if parameters.missing.any?
        raise MissingParameters.new(
          "Required parameters missing: #{parameters.missing.join ', '}"
        )
      end

      Stacker.logger.info 'Updating stack'

      unless allow_destructive
        raise StackPolicyError if describe_change_set.any? do |c|
          c[:change][:replacement] == 'True' ||
            c[:change][:action] =~ /remove/i
        end
      end

      region.client.execute_change_set(
        change_set_name: change_set,
        stack_name: name
      )

      if blocking
        sleep 4 # Wait a bit for the stack to begin updating
        wait_until_complete
      end
    rescue Aws::CloudFormation::Errors::ValidationError => err
      case err.message
      when /does not exist/
        raise DoesNotExistError.new err.message
      when /No updates/
        raise UpToDateError.new err.message
      else
        raise Error.new err.message
      end
    end

    def describe_change_set
      retries = 6
      changes = []
      while changes.empty?
        resp = region.client.describe_change_set(
          change_set_name: change_set,
          stack_name: name
        )
        changes = resp.changes
        if changes.empty?
          raise CannotDescribeChangeSet.new 'Empty change set' if retries == 0
          retries -= 1
          sleep (1 * (6 - retries) * 3)
        end
      end
      changes.map do |c|
        rc = c.resource_change
        {
          type: c.type,
          change: {
            logical_resource_id: rc.logical_resource_id,
            action: rc.action,
            replacement: rc.replacement,
          }
        }
      end
    end
    memoize :describe_change_set

    def pretty_change_set
      riw = describe_change_set.map do |c|
        c[:change][:logical_resource_id].length
      end.max
      fmt = "%-6s %-#{riw}s %-5s"

      ([fmt % ['Action', 'Resource', 'Replacement?'], '='*(riw+20)] +
        describe_change_set.map do |c|
        change = c[:change]
        fmt % [
          change[:action],
          change[:logical_resource_id],
          change[:replacement]
        ]
      end).join("\n")
    end

    private

    def change_set_name
      "stacker-#{SecureRandom.hex}"
    end
    memoize :change_set_name

    def change_set
      change_set_name.tap do |csname|
        region.client.create_change_set(
          stack_name: name,
          template_body: template.local_raw,
          parameters: parameters.resolved.map do |k, v|
            if v.is_a? Stacker::Stack::Parameter::UsePreviousValue
              {
                parameter_key: k,
                use_previous_value: true
              }
            else
              {
                parameter_key: k,
                parameter_value: v
              }
            end
          end,
          capabilities: capabilities.local,
          change_set_name: csname
        )
      end
    rescue Aws::CloudFormation::Errors::ValidationError => err
      raise Error.new err.message
    end
    memoize :change_set

    def report_status
      case status
      when /_COMPLETE$/
        Stacker.logger.info "#{name} Status => #{status}"
      when /_ROLLBACK_IN_PROGRESS$/
        failure_event = client.events.enum(limit: 30).find do |event|
          event.resource_status =~ /_FAILED$/
        end
        failure_reason = failure_event.resource_status_reason
        if failure_reason =~ /stack policy/
          raise StackPolicyError.new failure_reason
        else
          Stacker.logger.fatal "#{name} Status => #{status}"
          raise Error.new "Failure Reason: #{failure_reason}"
        end
      else
        Stacker.logger.debug "#{name} Status => #{status}"
      end
    end

    def wait_until_complete
      while !(status =~ STATUS_COMPLETE_REGEX)
        report_status
        sleep 5
      end
      report_status
    end

  end
end
