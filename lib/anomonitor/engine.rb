# frozen_string_literal: true

module Anomonitor
  class Engine < ::Rails::Engine
    isolate_namespace Anomonitor

    config.generators do |g|
      g.test_framework :minitest
    end

    initializer "anomonitor.assets" do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.precompile += %w[anomonitor/application.css]
      end
    end

    # Migrations are installed into the host via:
    #   rails anomonitor:install:migrations
    # Do not also append the engine migrate path (duplicates + breaks
    # Apartment apps that wrap migrations with public-only guards).

    config.after_initialize do
      # :thread starts an in-process poller; :cron relies on `rails anomonitor:poll`
      next unless Anomonitor.config.poll_mode == :thread
      next unless Anomonitor.config.auto_start
      next if defined?(Rails::Console)
      next if File.basename($PROGRAM_NAME).include?("rake")
      next if Rails.env.test?

      Anomonitor::Poller.instance.start
    end
  end
end
