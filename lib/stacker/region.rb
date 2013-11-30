require 'aws-sdk'
require 'stacker/stack'

module Stacker
  class Region

    attr_reader :name, :defaults, :stacks, :templates_path

    def initialize(name, defaults, stacks, templates_path)
      @name = name
      @defaults = defaults
      @stacks = stacks.map { |name, opts| Stack.new self, name, opts || {} }
      @templates_path = templates_path
    end

    def client
      @client ||= AWS::CloudFormation.new region: name
    end

    def stack name
      stacks.find { |s| s.name == name } || Stack.new(self, name)
    end

  end
end
