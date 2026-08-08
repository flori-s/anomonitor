# frozen_string_literal: true

require "set"
require "digest"

module Anomonitor
  module Collectors
    # Detects schema drift across tenant schemas:
    # missing/extra tables and missing/extra columns vs the majority baseline.
    #
    # Requires Anomonitor.config.tenants to be set.
    # PostgreSQL (information_schema.table_schema as tenant) is supported.
    class SchemaDrift < Base
      def collect
        tenants = Tenancy.tenant_names
        if tenants.size < 2
          log_skip("need at least 2 tenants for schema drift (configure c.tenants)")
          return []
        end

        tables_by_tenant = load_tables(tenants)
        columns_by_tenant = load_columns(tenants)
        expected_tables = majority_keys(tables_by_tenant)
        expected_columns = majority_keys(columns_by_tenant)

        points = []
        tenants.each do |tenant|
          tenant_tables = tables_by_tenant[tenant] || Set.new
          tenant_columns = columns_by_tenant[tenant] || Set.new

          missing_tables = (expected_tables - tenant_tables).to_a.sort
          extra_tables = (tenant_tables - expected_tables).to_a.sort

          comparable_expected_cols = Set.new(
            expected_columns.select do |key|
              table = key.split(".", 2).first
              tenant_tables.include?(table)
            end
          )
          comparable_tenant_cols = Set.new(
            tenant_columns.select do |key|
              table = key.split(".", 2).first
              expected_tables.include?(table)
            end
          )
          missing_columns = (comparable_expected_cols - tenant_columns).to_a.sort
          extra_columns = (comparable_tenant_cols - expected_columns).to_a.sort

          points.concat(drift_points(tenant, "missing_tables", missing_tables))
          points.concat(drift_points(tenant, "extra_tables", extra_tables))
          points.concat(drift_points(tenant, "missing_columns", missing_columns))
          points.concat(drift_points(tenant, "extra_columns", extra_columns))
        end
        points
      rescue StandardError => e
        Anomonitor.logger.warn("[Anomonitor] SchemaDrift collector error: #{e.message}")
        []
      end

      private

      def load_tables(tenants)
        conn = ActiveRecord::Base.connection
        quoted = tenants.map { |t| conn.quote(t) }.join(", ")
        rows = conn.select_all(<<~SQL.squish)
          SELECT table_schema, table_name
          FROM information_schema.tables
          WHERE table_type = 'BASE TABLE'
            AND table_schema IN (#{quoted})
        SQL

        by_tenant = Hash.new { |h, k| h[k] = Set.new }
        rows.each do |row|
          table = row["table_name"].to_s
          next if excluded_table?(table)

          by_tenant[row["table_schema"].to_s] << table
        end
        by_tenant
      end

      def load_columns(tenants)
        conn = ActiveRecord::Base.connection
        quoted = tenants.map { |t| conn.quote(t) }.join(", ")
        rows = conn.select_all(<<~SQL.squish)
          SELECT table_schema, table_name, column_name
          FROM information_schema.columns
          WHERE table_schema IN (#{quoted})
        SQL

        by_tenant = Hash.new { |h, k| h[k] = Set.new }
        rows.each do |row|
          table = row["table_name"].to_s
          next if excluded_table?(table)

          key = "#{table}.#{row['column_name']}"
          by_tenant[row["table_schema"].to_s] << key
        end
        by_tenant
      end

      def majority_keys(by_tenant)
        counts = Hash.new(0)
        by_tenant.each_value do |keys|
          keys.each { |key| counts[key] += 1 }
        end
        threshold = (by_tenant.size / 2.0).ceil
        Set.new(counts.select { |_, c| c >= threshold }.keys)
      end

      def excluded_table?(name)
        Array(Anomonitor.config.schema_drift_exclude).any? do |pattern|
          File.fnmatch?(pattern.to_s, name, File::FNM_EXTGLOB)
        end
      end

      # Always emit (including zeros) so the detector can resolve sticky alerts when drift clears.
      # Display truncates items; items_digest fingerprints the full sorted set.
      def drift_points(tenant, metric, items)
        digest =
          if items.empty?
            nil
          else
            Digest::SHA256.hexdigest(items.join("\0"))[0, 16]
          end

        [
          point(
            source: "schema_drift",
            metric: metric,
            value: items.size,
            tags: {
              tenant: tenant,
              items: items.first(25).join(","),
              items_list: items,
              item_count: items.size,
              items_digest: digest
            }.compact
          )
        ]
      end
    end
  end
end
