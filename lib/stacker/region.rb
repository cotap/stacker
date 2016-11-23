require 'aws-sdk'
require 'stacker/stack'
require 'stacker/stack/errors'

module Stacker
  class Region

    attr_reader :name, :defaults, :stacks, :templates_path, :options

    def initialize(name, defaults, stacks, templates_path, options={})
      @name = name
      @defaults = defaults
      stack_prefix = options.fetch(:stack_prefix, '')
      @stacks = stacks.map do |options|
        begin
          options['template_name'] ||= options['name']
          options['name'] = stack_prefix + options['name']
          Stack.new self, options.fetch('name'), options
        rescue KeyError => err
         Stacker.logger.fatal "Malformed YAML: #{err.message}"
         exit 1
        end
      end
      @templates_path = templates_path
      @options = options
    end

    def client
      @client ||= Aws::CloudFormation::Client.new region: name
    end

    def stack name
      stacks.find { |s| s.name == name }.tap do |stk|
        raise Stack::StackUndeclared.new name unless stk
      end
    end

  end
end
