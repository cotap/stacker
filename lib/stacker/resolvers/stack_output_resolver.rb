require 'stacker/resolvers/resolver'

module Stacker
  module Resolvers

    class StackOutputResolver < Resolver

      def resolve
        prefix = region.options.fetch(:stack_prefix, '')
        stack = region.stack "#{prefix}#{ref.fetch('Stack')}"
        stack.outputs.fetch ref.fetch('Output')
      end

    end

  end
end
