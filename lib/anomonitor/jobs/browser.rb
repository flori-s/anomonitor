# frozen_string_literal: true

module Anomonitor
  module Jobs
    # Fetches live job rows from every enabled job collector backend.
    class Browser
      DEFAULT_LIMIT = 100
      STATUSES = %w[all pending failed locked].freeze

      def self.fetch(filters = {})
        new(filters).fetch
      end

      def self.enabled_sources
        new.enabled_sources
      end

      def self.status_options(source = nil)
        if source.to_s.start_with?("table:")
          name = source.to_s.delete_prefix("table:")
          table = Anomonitor.config.tables.find { |t| t.name.to_s == name }
          return %w[all pending failed] if table && !table.delayed_job_style?
        end

        STATUSES
      end

      def initialize(filters = {})
        @filters = normalize(filters)
      end

      def fetch
        rows = []
        adapters.each do |adapter|
          next if @filters[:source] && adapter.source_key != @filters[:source]

          rows.concat(Array(adapter.fetch(@filters)))
        rescue StandardError => e
          Anomonitor.logger.warn("[Anomonitor] Jobs browser (#{adapter.source_key}) error: #{e.message}")
        end

        rows.sort_by { |r| r.sort_at }.reverse.first(@filters[:limit])
      end

      def enabled_sources
        adapters.map(&:source_key)
      end

      private

      def normalize(filters)
        raw = filters.respond_to?(:to_unsafe_h) ? filters.to_unsafe_h : filters
        raw = raw.to_h.transform_keys(&:to_sym)
        status = raw[:status].to_s
        status = "all" unless STATUSES.include?(status)

        {
          source: raw[:source].presence,
          status: status,
          tenant: raw[:tenant].presence,
          queue: raw[:queue].presence,
          limit: (raw[:limit] || DEFAULT_LIMIT).to_i.clamp(1, 500)
        }
      end

      def adapters
        list = []
        cfg = Anomonitor.config.collectors
        list << Browsers::Sidekiq.new if cfg.sidekiq
        list << Browsers::DelayedJob.new if cfg.delayed_job
        list << Browsers::SolidQueue.new if cfg.solid_queue
        Anomonitor.config.tables.each do |table|
          list << Browsers::Table.new(table)
        end
        list
      end
    end
  end
end
