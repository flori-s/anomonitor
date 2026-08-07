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

    puts "Collected #{points.size} metric points (poll_mode=#{Anomonitor.config.poll_mode})"
  end
end
