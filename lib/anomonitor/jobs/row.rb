# frozen_string_literal: true

module Anomonitor
  module Jobs
    Row = Struct.new(
      :source,
      :id,
      :name,
      :status,
      :queue,
      :tenant,
      :run_at,
      :failed_at,
      :error,
      :tags,
      :detail,
      keyword_init: true
    ) do
      def sort_at
        failed_at || run_at || Time.at(0)
      end

      def detail_text
        return nil if detail.nil? || detail.empty?

        detail.map { |k, v| "#{k}: #{v}" }.join("\n")
      end
    end
  end
end
