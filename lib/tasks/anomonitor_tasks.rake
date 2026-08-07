# frozen_string_literal: true

namespace :anomonitor do
  desc "Run a single Anomonitor collection + detection tick"
  task poll: :environment do
    points = Anomonitor::Poller.instance.tick
    puts "Collected #{points.size} metric points"
  end
end
