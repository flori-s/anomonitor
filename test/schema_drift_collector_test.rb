# frozen_string_literal: true

require "test_helper"

class SchemaDriftCollectorTest < AnomonitorTestCase
  def test_majority_baseline_emits_missing_and_extra
    Anomonitor.configure do |c|
      c.tenants = %w[acme beta gamma]
      c.schema_drift_exclude = %w[schema_migrations]
    end

    tables = [
      { "table_schema" => "acme", "table_name" => "users" },
      { "table_schema" => "acme", "table_name" => "orders" },
      { "table_schema" => "beta", "table_name" => "users" },
      { "table_schema" => "beta", "table_name" => "orders" },
      { "table_schema" => "gamma", "table_name" => "users" },
      { "table_schema" => "gamma", "table_name" => "legacy" }
    ]
    columns = [
      { "table_schema" => "acme", "table_name" => "users", "column_name" => "id" },
      { "table_schema" => "beta", "table_name" => "users", "column_name" => "id" },
      { "table_schema" => "gamma", "table_name" => "users", "column_name" => "id" },
      { "table_schema" => "gamma", "table_name" => "users", "column_name" => "legacy_col" }
    ]

    conn = Object.new
    def conn.quote(value)
      "'#{value}'"
    end
    queries = { tables: tables, columns: columns }
    conn.define_singleton_method(:select_all) do |sql|
      sql.to_s.include?("column_name") ? queries[:columns] : queries[:tables]
    end

    ActiveRecord::Base.stub :connection, conn do
      points = Anomonitor::Collectors::SchemaDrift.new.collect
      missing = points.find { |p| p.metric == "missing_tables" && p.tags[:tenant] == "gamma" }
      extra = points.find { |p| p.metric == "extra_tables" && p.tags[:tenant] == "gamma" }
      assert missing
      assert_equal 1, missing.value
      assert_includes missing.tags[:items_list], "orders"
      assert extra
      assert_equal 1, extra.value
      assert_includes extra.tags[:items_list], "legacy"

      extra_cols = points.find { |p| p.metric == "extra_columns" && p.tags[:tenant] == "gamma" }
      assert extra_cols
      assert_includes extra_cols.tags[:items_list], "users.legacy_col"
    end
  end

  def test_skips_with_fewer_than_two_tenants
    Anomonitor.configure { |c| c.tenants = %w[only] }
    assert_empty Anomonitor::Collectors::SchemaDrift.new.collect
  end
end
