require 'stacker/resolvers/resolver'

module Stacker
  module Resolvers

    class StackOutputResolver < Resolver

      def resolve
        stack = region.stack ref.fetch('Stack')
        stack.outputs.fetch ref.fetch('Output')
      end

    end

  end
end
