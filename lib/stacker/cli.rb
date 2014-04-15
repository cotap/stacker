require 'benchmark'
require 'stacker'
require 'thor'
require 'yaml'

module Stacker
  class Cli < Thor
    include Thor::Actions

    default_path = ENV['STACKER_PATH'] || '.'
    default_region = ENV['STACKER_REGION'] || 'us-east-1'

    method_option :path,   default: default_path,   banner: 'project path'
    method_option :region, default: default_region, banner: 'AWS region name'
    def initialize(*args); super(*args) end

    desc "init [PATH]", "Create stacker project directories"
    def init path = nil
      init_project path || options['path']
    end

    desc "list", "List stacks"
    def list
      Stacker.logger.inspect region.stacks.map(&:name)
    end

    desc "show STACK_NAME", "Show details of a stack"
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

    desc "status [STACK_NAME]", "Show stack status"
    def status stack_name = nil
      with_one_or_all(stack_name) do |stack|
        Stacker.logger.debug stack.status.indent
      end
    end

    desc "diff [STACK_NAME]", "Show outstanding stack differences"
    def diff stack_name = nil
      with_one_or_all(stack_name) do |stack|
        resolve stack
        next unless full_diff stack
      end
    end

    desc "update [STACK_NAME]", "Create or update stack"
    def update stack_name = nil
      with_one_or_all(stack_name) do |stack|
        resolve stack

        if stack.exists?
          next unless full_diff stack

          if yes? "Update remote template with these changes (y/n)?"
            time = Benchmark.realtime do
              stack.update
            end
            Stacker.logger.info time stack_name, 'updated', time
          else
            Stacker.logger.warn 'Update skipped'
          end
        else
          if yes? "#{stack.name} does not exist. Create it (y/n)?"
            time = Benchmark.realtime do
              stack.create
            end
            Stacker.logger.info time stack_name, 'created', time
          else
            Stacker.logger.warn 'Create skipped'
          end
        end
      end
    end

    desc "dump [STACK_NAME]", "Download stack template"
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

    desc "fmt [STACK_NAME]", "Re-format template JSON"
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

    def init_project path
      project_path = File.expand_path path

      %w[ regions templates ].each do |dir|
        directory_path = File.join project_path, dir
        unless Dir.exists? directory_path
          Stacker.logger.debug "Creating directory at #{directory_path}"
          FileUtils.mkdir_p directory_path
        end
      end

      region_path = File.join project_path, 'regions', 'us-east-1.yml'
      unless File.exists? region_path
        Stacker.logger.debug "Creating region file at #{region_path}"
        File.open(region_path, 'w+') { |f| f.print <<-YAML }
defaults:
  parameters:
    CidrBlock: '10.0'
stacks:
  - name: VPC
YAML
      end
    end

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
        config_path =  File.join working_path, 'regions', "#{options['region']}.yml"
        if File.exists? config_path
          begin
            config = YAML.load_file(config_path)
          rescue Psych::SyntaxError => err
            Stacker.logger.fatal err.message
            exit 1
          end

          defaults = config.fetch 'defaults', {}
          stacks = config.fetch 'stacks', {}

          Region.new options['region'], defaults, stacks, templates_path
        else
          Stacker.logger.fatal "#{options['region']}.yml does not exist. Please configure or use stacker init"
          exit 1
        end
      end
    end

    def resolve stack
      return {} if stack.parameters.resolver.dependencies.none?
      Stacker.logger.debug 'Resolving dependencies...'
      stack.parameters.resolved
    end

    def time (stack, action, benchmark)
      return "Stack #{stack} #{action} in: #{(benchmark / 60).floor} min and #{(benchmark % 60).round} seconds."
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
