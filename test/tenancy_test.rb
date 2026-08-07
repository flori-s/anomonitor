# frozen_string_literal: true

require "test_helper"

class TenancyTest < AnomonitorTestCase
  def test_resolves_tenants_and_excludes_public
    Anomonitor.configure do |c|
      c.tenants = %w[public acme beta]
      c.exclude_tenants = %w[public]
    end

    assert_equal %w[acme beta], Anomonitor::Tenancy.tenant_names
    assert Anomonitor::Tenancy.multi_tenant?
  end

  def test_tenant_switch_callable
    seen = []
    Anomonitor.configure do |c|
      c.tenant_switch = ->(name, &block) {
        seen << name
        block.call
      }
    end

    result = Anomonitor::Tenancy.switch("acme") { :ok }
    assert_equal :ok, result
    assert_equal %w[acme], seen
  end

  def test_schema_drift_exclude_defaults
    assert_includes Anomonitor.config.schema_drift_exclude, "anomonitor_*"
  end
end
