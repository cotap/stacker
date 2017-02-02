require 'active_support/core_ext/string/inflections'
require 'json'
require 'yaml'
require 'memoist'
require 'stacker/differ'
require 'stacker/stack'
require 'stacker/stack/component'

module Stacker
  class Stack
    class Template < Component

      FORMAT_VERSION = '2010-09-09'

      extend Memoist

      def exists?
        File.exists? path
      end

      def local_raw
        File.read path
      end
      memoize :local_raw

      def local
        raise TemplateDoesNotExistError.new name unless exists?
        @local ||= begin
          template = if json?
            JSON.parse local_raw
          else
            YAML.load local_raw
          end
          template['AWSTemplateFormatVersion'] ||= FORMAT_VERSION
          template
        end
      rescue JSON::ParserError, Psych::SyntaxError
        raise TemplateSyntaxError.new path
      end

      def remote_raw
        stack.region.client.get_template(
          stack_name: stack.name
        ).template_body
      end
      memoize :remote_raw

      def remote
        @remote ||= json? ? JSON.parse(remote_raw) : YAML.parse(remote_raw)
      rescue Aws::CloudFormation::Errors::ValidationError => err
        if err.message =~ /does not exist/
          raise DoesNotExistError.new err.message
        else
          raise Error.new err.message
        end
      end

      def diff *args
        if json?
          Differ.json_diff local, remote, *args
        else
          Differ.diff local_raw, remote_raw, *args
        end
      end
      memoize :diff

      def write value = local
        File.write path, JSONFormatter.format(value)
      end

      def dump
        write remote
      end

      private

      def name
        stack.options.fetch('template_name', stack.name)
      end

      def path_with_ext ext
        File.join(
          stack.region.templates_path,
          "#{name}.#{ext}"
        )
      end

      def path
        json = path_with_ext 'json'
        yaml = path_with_ext 'yml'
        File.exists?(json) ? json : yaml
      end
      memoize :path

      def json?
        path.end_with? '.json'
      end

      def yaml?
        path.end_with? '.yml'
      end

      class JSONFormatter
        STR = '\"[^\"]+\"'

        def self.format object
          formatted = JSON.pretty_generate object

          # put empty arrays on a single line
          formatted.gsub! /: \[\s*\]/m, ': []'

          # put { "Ref": ... } on a single line
          formatted.gsub! /\{\s+\"Ref\"\:\s+(?<ref>#{STR})\s+\}/m,
            '{ "Ref": \\k<ref> }'

          # put { "Fn::GetAtt": ... } on a single line
          formatted.gsub! /\{\s+\"Fn::GetAtt\"\: \[\s+(?<key>#{STR}),\s+(?<val>#{STR})\s+\]\s+\}/m,
            '{ "Fn::GetAtt": [ \\k<key>, \\k<val> ] }'

          formatted + "\n"
        end
      end

    end
  end
end
