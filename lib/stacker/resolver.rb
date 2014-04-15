module Stacker
  class Resolver

    attr_reader :region, :parameters

    def initialize region, parameters
      @region, @parameters = region, parameters
    end

    def dependencies
      @dependencies ||= parameters.select { |_, value|
        value.is_a?(Hash)
      }.map { |_, value|
        "#{value.fetch('Stack')}.#{value.fetch('Output')}"
      }
    end

    def resolved
      @resolved ||= Hash[parameters.map do |name, value|
        if value.is_a? Hash
          stack = region.stack value.fetch('Stack')
          value = stack.outputs.fetch value.fetch('Output')
        end
        [ name, value ]
      end]
    end

  end
end
