module Stacker
  module Resolvers

    class Resolver

      attr_reader :ref, :region

      def initialize ref, region
        @ref = ref
        @region = region
      end

      def resolve
        raise NotImplementedError
      end

    end

  end
end
