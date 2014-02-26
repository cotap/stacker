require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/module/delegation'
require 'aws-sdk'
require 'memoist'
require 'stacker/stack/capabilities'
require 'stacker/stack/parameters'
require 'stacker/stack/template'

module Stacker
  class Stack

    class Error < StandardError;     end
    class DoesNotExistError < Error; end
    class MissingParameters < Error; end
    class UpToDateError < Error;     end

    extend Memoist

    CLIENT_METHODS = %w[
      creation_time
      description
      exists?
      last_updated_time
      status
      status_reason
    ]

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

    def update blocking = true
      if parameters.missing.any?
        raise MissingParameters.new(
          "Required parameters missing: #{parameters.missing.join ', '}"
        )
      end

      Stacker.logger.info 'Updating stack'

      client.update(
        template: template.local,
        parameters: parameters.resolved,
        capabilities: capabilities.local
      )

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

    def wait_while_status wait_status
      while flush_cache(:status) && status == wait_status
        Stacker.logger.debug "#{name} Status => #{status}"
        sleep 5
      end
      Stacker.logger.info "#{name} Status => #{status}"
    end

  end
end

