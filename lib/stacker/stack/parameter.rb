require 'stacker/resolvers/stack_output_resolver'
require 'stacker/resolvers/file_resolver'

module Stacker
  class Stack

    # A Parameter represents a stack parameter. A parameter can be
    # either a literal value (e.g. a string, number, or array) or a
    # reference, otherwise known as a dependency. References parameter
    # values are represented as hashes with a single key indicating
    # the reference type. There is one exception to this rule;
    # references to stack outputs are expressed as hashes with two
    # keys, "Stack" and "Output".
    class Parameter

      extend Memoist

      attr_reader :value, :region

      def initialize value, region
        @region = region
        @value = if value.is_a?(Array)
          value.map { |v| Parameter.new v, region }
        else
          value
        end
      end

      def dependency?
        value.is_a?(Hash)
      end

      def dependencies
        if dependency?
          [ to_s ]
        elsif value.is_a?(Array)
          value.map(&:dependencies).flatten
        else
          [ ]
        end
      end

      def resolved
        if dependency?
          begin
            resolver.resolve
          rescue => err
            raise ParameterResolutionError.new value, err
          end
        elsif value.is_a?(Array)
          value.map(&:resolved).join ','
        else
          value
        end
      end
      memoize :resolved

      def to_s
        if dependency?
          value.values.map(&:to_s).sort.join('.')
        else
          value.to_s
        end
      end

      private

      def stack_output?
        dependency? && value['Stack'] && value['Output']
      end

      def resolver_class_name
        type = if stack_output?
          'StackOutput'
        elsif value.keys.size == 1
          value.keys.first
        else
          raise ReferenceError.new 'Too many top-level keys in reference value.'
        end

        "Stacker::Resolvers::#{type}Resolver"
      end

      def reference_value
        if stack_output?
          value
        else
          value.values.first
        end
      end

      def resolver
        resolver_class_name.constantize.new reference_value, region
      end

    end
  end
end
