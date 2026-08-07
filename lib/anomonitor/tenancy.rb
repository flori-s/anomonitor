# frozen_string_literal: true

module Anomonitor
  # Resolves tenant schema names and switches connection context.
  #
  #   Anomonitor.configure do |c|
  #     c.tenants = -> { CustomerTenant.pluck(:name) }
  #     c.exclude_tenants = %w[public]
  #     c.tenant_switch = ->(name, &block) { Apartment::Tenant.switch(name, &block) }
  #   end
  module Tenancy
    module_function

    def tenant_names
      cfg = Anomonitor.config
      raw = cfg.tenants
      list =
        case raw
        when Proc then Array(raw.call)
        when nil then []
        else Array(raw)
        end

      excluded = Array(cfg.exclude_tenants).map(&:to_s)
      list.map(&:to_s).reject { |name| name.empty? || excluded.include?(name) }.uniq.sort
    rescue StandardError => e
      Anomonitor.logger.warn("[Anomonitor] Failed to resolve tenants: #{e.message}")
      []
    end

    def switch(name, &block)
      switcher = Anomonitor.config.tenant_switch
      if switcher
        switcher.call(name, &block)
      elsif defined?(::Apartment::Tenant)
        ::Apartment::Tenant.switch(name, &block)
      else
        yield
      end
    end

    def multi_tenant?
      tenant_names.any?
    end
  end
end
