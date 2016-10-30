require 'jsonlint'
require 'yamllint'

module Stacker
  class Stack

    class Error < StandardError; end
    class StackPolicyError < Error; end
    class DoesNotExistError < Error; end
    class MissingParameters < Error; end
    class UpToDateError < Error; end
    class CannotDescribeChangeSet < Error; end

    class StackUndeclared < Error

      def initialize(name)
        @name = name
      end

      def message
        "Stack with id #{@name} is not declared"
      end

    end

    class TemplateDoesNotExistError < Error

      def initialize(name)
        @name = name
      end

      def message
        "No template found with name '#{@name}'"
      end

    end

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
          linter.check path
          linter.errors.values.join "\n"
        end
      end

      def linter
        linter ||= if path.ends_with? '.json'
          JsonLint::Linter.new
        else
          YamlLint::Linter.new
        end
      end

    end

  end
end
