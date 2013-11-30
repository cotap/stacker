require 'memoist'
require 'stacker/differ'
require 'stacker/resolver'
require 'stacker/stack/component'

module Stacker
  class Stack
    class Parameters < Component

      extend Memoist

      def available
        @available ||= stack.region.defaults.fetch('Parameters', {}).merge(
          stack.options.fetch('Parameters', {})
        )
      end

      def required
        @required ||= stack.template.local.fetch 'Parameters', {}
      end

      def local
        @local ||= available.slice *required.keys
      end

      def missing
        @missing ||= required.keys - local.keys
      end

      def remote
        @remote ||= client.parameters
      end

      def resolved
        @resolved ||= resolver.resolved
      end

      def resolver
        @resolver ||= Resolver.new stack.region, local
      end

      def diff *args
        Differ.yaml_diff Hash[resolved.sort], Hash[remote.sort], *args
      end
      memoize :diff

    end
  end
end
