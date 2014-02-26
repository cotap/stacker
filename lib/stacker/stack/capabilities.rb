require 'stacker/stack/component'

module Stacker
  class Stack
    class Capabilities < Component

      def local
        @local ||= Array.wrap(stack.options.fetch 'capabilities', [])
      end

      def remote
        @remote ||= client.capabilities
      end

    end
  end
end
