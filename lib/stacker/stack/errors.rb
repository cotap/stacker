require 'jsonlint'

module Stacker
  class Stack

    class Error < StandardError; end
    class StackPolicyError < Error; end
    class DoesNotExistError < Error; end
    class MissingParameters < Error; end
    class UpToDateError < Error; end

    class TemplateSyntaxError < Error

      def initialize(path)
        @path = path
      end

      def message
        <<END_MSG
Syntax error(s) in template.
#{path}:
#{errors}
END_MSG
      end

      private

      attr_reader :path

      def errors
        @errors ||= begin
          linter = JsonLint::Linter.new
          linter.check path
          linter.errors.values.join "\n"
        end
      end

    end

  end
end
