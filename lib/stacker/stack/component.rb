require 'stacker/stack'

module Stacker
  class Stack
    # an abstract base class for stack components (template, parameters)
    class Component

      attr_reader :stack

      def initialize stack
        @stack = stack
      end

      private

      def client
        stack.client
      end

    end
  end
end
