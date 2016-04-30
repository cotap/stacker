module Stacker
  class Resolver

    attr_reader :region, :parameters

    def initialize region, parameters
      @region, @parameters = region, parameters
    end

    def dependencies
      @dependencies ||= parameters.values.flatten.select { |value|
        value.is_a?(Hash)
      }.map { |ref|
        "#{ref.fetch('Stack')}.#{ref.fetch('Output')}"
      }
    end

    def resolved
      @resolved ||= Hash[parameters.map do |name, value|
        if value.is_a? Hash
          value = resolve_reference(value)
        elsif value.is_a? Array
          value = value.map do |ref|
            ref.is_a?(Hash) ? resolve_reference(ref) : ref
          end.join ','
        end
        [ name, value ]
      end]
    end

    private

    def resolve_reference(ref)
      stack = region.stack ref.fetch('Stack')
      stack.outputs.fetch ref.fetch('Output')
    end

  end
end
