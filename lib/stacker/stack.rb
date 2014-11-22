require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/module/delegation'
require 'aws-sdk'
require 'memoist'
require 'stacker/stack/capabilities'
require 'stacker/stack/parameters'
require 'stacker/stack/template'

module Stacker
  class Stack

    class Error < StandardError; end
    class StackPolicyError < Error; end
    class DoesNotExistError < Error; end
    class MissingParameters < Error; end
    class UpToDateError < Error; end

    extend Memoist

    CLIENT_METHODS = %w[
      creation_time
      description
      exists?
      last_updated_time
      status
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

    attr_reader :region, :name, :options

    def initialize region, name, options = {}
      @region, @name, @options = region, name, options
    end

    def client
      @client ||= region.client.stacks[name]
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
        Hash[client.outputs.map { |output| [ output.key, output.value ] }]
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

      region.client.stacks.create(
        name,
        template.local,
        parameters: parameters.resolved,
        capabilities: capabilities.local
      )

      wait_while_status 'CREATE_IN_PROGRESS' if blocking
    rescue AWS::CloudFormation::Errors::ValidationError => err
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

      update_params = {
        template: template.local,
        parameters: parameters.resolved,
        capabilities: capabilities.local
      }

      unless allow_destructive
        update_params[:stack_policy_during_update_body] = SAFE_UPDATE_POLICY
      end

      client.update(update_params)

      wait_while_status 'UPDATE_IN_PROGRESS' if blocking
    rescue AWS::CloudFormation::Errors::ValidationError => err
      case err.message
      when /does not exist/
        raise DoesNotExistError.new err.message
      when /No updates/
        raise UpToDateError.new err.message
      else
        raise Error.new err.message
      end
    end

    private

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

    def wait_while_status wait_status
      while flush_cache(:status) && status == wait_status
        report_status
        sleep 5
      end
      report_status
    end

  end
end

