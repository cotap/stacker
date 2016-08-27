require 'aws-sdk'
require 'stacker/stack'

module Stacker
  class Region

    attr_reader :name, :defaults, :stacks, :templates_path

    def initialize(name, defaults, stacks, templates_path)
      @name = name
      @defaults = defaults
      @stacks = stacks.map do |options|
        begin
          Stack.new self, options.fetch('name'), options
        rescue KeyError => err
         Stacker.logger.fatal "Malformed YAML: #{err.message}"
         exit 1
        end
      end
      @templates_path = templates_path
    end

    def client
      @client ||= Aws::CloudFormation::Client.new region: name
    end

    def stack name
      stacks.find { |s| s.name == name } || Stack.new(self, name)
    end

  end
end
