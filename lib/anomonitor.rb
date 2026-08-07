# frozen_string_literal: true

require "logger"
require "anomonitor/version"
require "anomonitor/configuration"
require "anomonitor/metric_point"
require "anomonitor/tenancy"
require "anomonitor/engine"

require "anomonitor/collectors/base"
require "anomonitor/collectors/sidekiq"
require "anomonitor/collectors/delayed_job"
require "anomonitor/collectors/solid_queue"
require "anomonitor/collectors/schema_drift"
require "anomonitor/collectors/table"
require "anomonitor/notifiers/webhook"
require "anomonitor/detector"
require "anomonitor/poller"

module Anomonitor
  class << self
    def configure
      yield config
    end

    def config
      @config ||= Configuration.new
    end

    def reset_config!
      @config = Configuration.new
    end

    def logger
      @logger ||= (defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger) || Logger.new($stdout)
    end
  end
end
