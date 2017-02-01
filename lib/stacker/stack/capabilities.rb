require 'stacker/stack/component'

module Stacker
  class Stack
    class Capabilities < Component

      def local
        @local ||= Array(stack.options.fetch 'capabilities', [])
      end

      def remote
        # `capabilities` actually returns a
        # !ruby/array:Aws::Xml::DefaultList
        @remote ||= client.capabilities.to_a
      end

    end
  end
end
