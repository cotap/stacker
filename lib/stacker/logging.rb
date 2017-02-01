require 'coderay'
require 'delegate'
require 'indentation'
require 'logger'
require 'rainbow'

module Stacker
  module_function

  class << self

    class PrettyLogger < SimpleDelegator
      def initialize logger
        super

        old_formatter = logger.formatter

        logger.formatter =  proc do |level, time, prog, msg|
          unless msg.start_with?("\e")
            color = case level
                    when 'FATAL' then :red
                    when 'WARN'  then :yellow
                    when 'INFO'  then :blue
                    when 'DEBUG' then '333333'
                    else              :default
                    end
            msg = msg.color(color)
          end

          old_formatter.call level, time, prog, msg
        end
      end

      %w[ debug info warn fatal ].each do |level|
        define_method level do |msg, opts = {}|
          if opts.include? :highlight
            msg = CodeRay.scan(msg, opts[:highlight]).terminal
          end
          __getobj__.__send__ level, msg
        end
      end

      def inspect object
        info object.to_yaml[4..-1].strip.indent, highlight: :yaml
      end
    end

    def logger= logger
      @logger = PrettyLogger.new logger
    end

    def logger
      @logger ||= begin
        logger = Logger.new STDOUT
        logger.level = Logger::DEBUG
        logger.formatter = proc { |_, _, _, msg| "#{msg}\n" }
        PrettyLogger.new logger
      end
    end

  end
end
