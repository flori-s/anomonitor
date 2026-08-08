# frozen_string_literal: true

namespace :anomonitor do
  desc "Run a single Anomonitor collection + detection tick (use with cron when poll_mode=:cron)"
  task poll: :environment do
    points =
      if defined?(Apartment::Tenant)
        home = Array(Anomonitor.config.exclude_tenants).first || "public"
        Apartment::Tenant.switch(home) { Anomonitor::Poller.instance.tick }
      else
        Anomonitor::Poller.instance.tick
      end

    puts "Collected #{Array(points).size} metric points (poll_mode=#{Anomonitor.config.poll_mode})"
  end

  desc "Retry failed anomaly webhook deliveries"
  task retry_webhooks: :environment do
    scope = Anomonitor::Anomaly.webhook_failed.order(created_at: :desc)
    total = scope.count
    ok = 0
    scope.find_each do |anomaly|
      ok += 1 if anomaly.retry_webhook!
    end
    puts "Retried #{total} failed webhooks — #{ok} delivered"
  end
end
