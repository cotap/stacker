require 'stacker'
require 'thor'
require 'yaml'

module Stacker
  class Cli < Thor
    include Thor::Actions

    default_path = ENV['STACKER_PATH'] || '.'
    default_region = ENV['STACKER_REGION'] || 'us-east-1'

    method_option :path, default: default_path, banner: 'project path'
    method_option :region, default: default_region, banner: 'AWS region name'
    def initialize(*args); super(*args) end

    desc "list", "list stacks"
    def list
      Stacker.logger.inspect region.stacks.map(&:name)
    end

    desc "show STACK_NAME", "show details of a stack"
    def show stack_name
      with_one_or_all stack_name do |stack|
        Stacker.logger.inspect(
          'Description'  => stack.description,
          'Status'       => stack.status,
          'Updated'      => stack.last_updated_time || stack.creation_time,
          'Capabilities' => stack.capabilities.remote,
          'Parameters'   => stack.parameters.remote,
          'Outputs'      => stack.outputs
        )
      end
    end

    desc "status [STACK_NAME]", "show stack status"
    def status stack_name = nil
      with_one_or_all(stack_name) do |stack|
        Stacker.logger.debug stack.status.indent
      end
    end

    desc "diff [STACK_NAME]", "show outstanding stack differences"
    def diff stack_name = nil
      with_one_or_all(stack_name) do |stack|
        resolve stack
        next unless full_diff stack
      end
    end

    desc "update [STACK_NAME]", "create or update stack"
    def update stack_name = nil
      with_one_or_all(stack_name) do |stack|
        resolve stack

        if stack.exists?
          next unless full_diff stack

          if yes? "Update remote template with these changes (y/n)?"
            stack.update
          else
            Stacker.logger.warn 'Update skipped'
          end
        else
          if yes? "#{stack.name} does not exist. Create it (y/n)?"
            stack.create
          else
            Stacker.logger.warn 'Create skipped'
          end
        end
      end
    end

    desc "dump [STACK_NAME]", "download stack template"
    def dump stack_name = nil
      with_one_or_all(stack_name) do |stack|
        if stack.exists?
          diff = stack.template.diff :down, :color
          next Stacker.logger.warn 'Stack up-to-date' if diff.length == 0

          Stacker.logger.debug "\n" + diff.indent
          if yes? "Update local template with these changes (y/n)?"
            stack.template.dump
          else
            Stacker.logger.warn 'Pull skipped'
          end
        else
          Stacker.logger.warn "#{stack.name} does not exist"
        end
      end
    end

    desc "fmt [STACK_NAME]", "re-format template"
    def fmt stack_name = nil
      with_one_or_all(stack_name) do |stack|
        if stack.template.exists?
          Stacker.logger.warn 'Formatting...'
          stack.template.write
        else
          Stacker.logger.warn "#{stack.name} does not exist"
        end
      end
    end

    private

    def full_diff stack
      templ_diff = stack.template.diff :color
      param_diff = stack.parameters.diff :color

      if (templ_diff + param_diff).length == 0
        Stacker.logger.warn 'Stack up-to-date'
        return false
      end

      Stacker.logger.info "\n#{templ_diff.indent}\n" if templ_diff.length > 0
      Stacker.logger.info "\n#{param_diff.indent}\n" if param_diff.length > 0

      true
    end

    def region
      @region ||= begin
        config = YAML.load_file(
          File.join working_path, 'regions', "#{options['region']}.yml"
        )

        defaults = config.fetch 'defaults', {}
        stacks = config.fetch 'stacks', {}

        Region.new options['region'], defaults, stacks, templates_path
      end
    end

    def resolve stack
      return {} if stack.parameters.resolver.dependencies.none?
      Stacker.logger.debug 'Resolving dependencies...'
      stack.parameters.resolved
    end

    def with_one_or_all stack_name = nil, &block
      yield_with_stack = proc do |stack|
        Stacker.logger.info "#{stack.name}:"
        yield stack
        Stacker.logger.info ''
      end

      if stack_name
        yield_with_stack.call region.stack(stack_name)
      else
        region.stacks.each(&yield_with_stack)
      end

    rescue Stacker::Stack::Error => err
      Stacker.logger.fatal err.message
      exit 1
    end

    def templates_path
      File.join working_path, 'templates'
    end

    def working_path
      File.expand_path options['path']
    end

  end
end
