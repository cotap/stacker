require 'stacker/resolvers/resolver'

module Stacker
  module Resolvers

    class FileResolver < Resolver

      def resolve
        IO.read ref
      end

    end

  end
end
