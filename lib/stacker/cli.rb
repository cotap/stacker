require 'active_support/core_ext/object/try'
require 'benchmark'
require 'stacker'
require 'thor'
require 'yaml'

module Stacker
  class Cli < Thor
    include Thor::Actions

    default_path = ENV['STACKER_PATH'] || '.'
    default_region = ENV['STACKER_REGION'] || 'us-east-1'
    default_env = ENV['STACKER_ENVIRONMENT'] || 'development'

    method_option :path, type: :string, default: default_path,
      banner: 'project path'

    method_option :region, type: :string, default: default_region,
      banner: 'AWS region name'

    method_option :environment, type: :string, default: default_env,
      banner: 'Environment name (e.g. production, staging)'

    method_option :allow_destructive, type: :boolean, default: false,
      banner: 'allow destructive updates'

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
        begin
          Stacker.logger.debug stack.status.indent
        rescue Aws::CloudFormation::Errors::ValidationError,
               Stacker::Stack::Error => err
          Stacker.logger.error err.message
        end
      end
    end

    desc "diff [STACK_NAME]", "Show outstanding stack differences"
    def diff stack_name = nil
      with_one_or_all(stack_name) do |stack|
        begin
          resolve stack
          next unless full_diff stack
        rescue Aws::CloudFormation::Errors::ValidationError,
               Stacker::Stack::Error => err
          Stacker.logger.error err.message
        end
      end
    end

    desc "update [STACK_NAME]", "Create or update stack"
    def update stack_name = nil
      with_one_or_all(stack_name) do |stack|
        begin
          resolve stack

          if stack.exists?
            next unless full_diff stack

            if yes? "Update remote template with these changes (y/n)?"
              time = Benchmark.realtime do
                stack.update allow_destructive: options['allow_destructive']
              end
              Stacker.logger.info formatted_time stack_name, 'updated', time
            else
              Stacker.logger.warn 'Update skipped'
            end
          else
            if yes? "#{stack.name} does not exist. Create it (y/n)?"
              time = Benchmark.realtime do
                stack.create
              end
              Stacker.logger.info formatted_time stack_name, 'created', time
            else
              Stacker.logger.warn 'Create skipped'
            end
          end
        rescue Aws::CloudFormation::Errors::ValidationError,
               Stacker::Stack::Error => err
          Stacker.logger.error err.message
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

    def formatted_time stack, action, benchmark
      "Stack #{stack} #{action} in: #{(benchmark / 60).floor} min and #{(benchmark % 60).round} seconds."
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

      Stacker.logger.info stack.pretty_change_set
      true
    end

    def region
      @region ||= begin
        config_path =  region_config_path
        if File.exists? config_path
          begin
            config = YAML.load_file(config_path)
          rescue Psych::SyntaxError => err
            Stacker.logger.fatal err.message
            exit 1
          end

          defaults = config.fetch 'defaults', {}
          stacks = config.fetch 'stacks', {}
          region_options = {
            stack_prefix: environment_config.fetch('prefix', '')
          }

          Region.new options['region'], defaults, stacks, templates_path,
                     region_options
        else
          Stacker.logger.fatal "#{options['region']}.yml does not exist. Please configure or use stacker init"
          exit 1
        end
      end
    end

    def region_config_path
      region_path = if environments?
        File.join working_path, 'environments', options['environment']
      else
        File.join working_path, 'regions'
      end
      File.join region_path, "#{options['region']}.yml"
    end

    def environments_path
      File.join working_path, 'environments'
    end

    def environments?
      File.exists? environments_path
    end

    def environment_config
      config_path = File.join environments_path, 'config.yml'
      return {} unless File.exists? config_path
      YAML.load_file(config_path).fetch('environments', {}).fetch(
        options['environment'],
        {}
      )
    end

    def resolve stack
      return {} if stack.parameters.dependencies.none?

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

    rescue Stacker::Stack::StackPolicyError => err
      if options['allow_destructive']
        Stacker.logger.fatal err.message
      else
        Stacker.logger.fatal 'Stack update policy prevents replacing or destroying resources.'
        Stacker.logger.warn 'Try running again with \'--allow-destructive\''
      end
      exit 1
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
