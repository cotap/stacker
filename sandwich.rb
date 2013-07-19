require 'aws-sdk'
require 'logger'
require 'optparse'
require 'yaml'

module Logging
  def logger
    Logging.logger
  end

  def self.logger
    @logger ||= Logger.new(STDOUT)
    @logger.level = Logger::DEBUG
    original_formatter = Logger::Formatter.new
    @logger.formatter =  proc { |severity, datetime, progname, msg|
      original_formatter.call(severity, datetime, progname, msg.dump)
    }
    @logger ||= Logger.new(STDOUT)
  end
end


class CloudFormationStack
  include Logging

  SLEEP_TIME = 10
  attr_accessor :client, :name, :template, :stack

  def initialize(client, name, template, parameters, capabilities)
    logger.debug "Initializing Stack: #{name}"
    @client = client
    @name = name
    @template = template
    @parameters = parameters
    @capabilities = capabilities
    @stack = nil
    @outputs = nil
  end

  def get_or_create(blocking=true)
    if @client.stacks[@name].exists?
      @stack = @client.stacks[@name]
      logger.info("Using existing Stack: {#@name} ")
    else
      self.create
    end
    if blocking
      self.wait_until_create
    end
    return @stack
  end

  def create
    logger.info("Creating stack: {#@name}")
    logger.debug("Template => #{@template}")
    logger.debug("Parameters => #{@parameters}")
    logger.debug("Capabilities => #{@capabilities}")
    begin
      @stack = @client.stacks.create(@name, IO.read(@template),
                                     :parameters => @parameters,
                                     :capabilities => @capabilities)
    rescue AWS::CloudFormation::Errors::ValidationError => error
      logger.fatal("#{error}")
      exit
    end

    return @stack
  end

  def get_status
    return @stack.status
  end

  def wait_until_create
    status = self.get_status
    while status == "CREATE_IN_PROGRESS"
      logger.debug("#{@name} Status => #{status}")
      sleep(SLEEP_TIME)
      status = self.get_status
    end
    logger.info("#{@name} Status => #{status}")
  end

  def get_outputs
    if self.get_status == "CREATE_COMPLETE" && @outputs.nil?
      logger.info("Getting current outputs for #{@name}")
      @outputs = {}
      @stack.outputs.each do |output|
        @outputs[output.key] = output.value
      end
    end
    logger.info("#{@name} Outputs => #{@outputs}")
    return @outputs
  end

  def self.build_parameters(existing_stacks, parameters)
    params = {}
    parameters = parameters || {}
    parameters.each do |config|
      param_name = config['param_name']
      if config['value'].is_a?(Hash)
        stack = existing_stacks[config['value']['stack']]
        param_value = stack.get_outputs[config['value']['output']]
      else
        param_value = config['value']
      end
      params[param_name] = param_value
    end
    return params
  end

end


if __FILE__ == $0
  begin
      cfm_client = AWS::CloudFormation.new
      options = {}
      OptionParser.new do |opts|
        opts.banner = "Usage: build_stacks.rb [options]"
        opts.on('-c', '--config PATH', String, "Path to config file") do |path|
          options[:config] = path
        end
        opts.on('-t', '--templates PATH', String, "Path to templates root folder") do |path|
          options[:templates] = path
        end
      end.parse!

      config = YAML.load_file(options[:config])
      stacks = {}

      config['stacks'].each do |stack_config|
        parameters = CloudFormationStack.build_parameters(stacks, stack_config['parameters'])
        capabilities = stack_config['capabilities'] || {}
        template_path = File.join(options[:templates], stack_config['template'])
        stack = CloudFormationStack.new(cfm_client,
                                        stack_config['name'],
                                        template_path,
                                        parameters,
                                        capabilities)
        stack.get_or_create
        stacks[stack_config['name']] = stack
      end
  rescue Interrupt => e
    puts 'Ctrl+C was pressed. Exiting now...'
  end
end
