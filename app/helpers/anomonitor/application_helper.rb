# frozen_string_literal: true

module Anomonitor
  module ApplicationHelper
    include ActionView::Helpers::NumberHelper
    include ActionView::Helpers::DateHelper

    def poller_mode(status = nil)
      mode = status && (status[:poll_mode] || status["poll_mode"])
      mode || Anomonitor.config.poll_mode
    end

    def poller_mode_label(status = nil)
      poller_mode(status).to_s == "cron" ? "cron" : "thread"
    end

    def poller_cron?(status = nil)
      poller_mode(status).to_s == "cron"
    end

    def poller_state_label(status)
      if poller_cron?(status)
        status[:last_run_at] || status["last_run_at"] ? "scheduled" : "waiting for first poll"
      else
        (status[:running] || status["running"]) ? "running" : "stopped"
      end
    end

    def poller_state_badge_class(status)
      if poller_cron?(status)
        (status[:last_run_at] || status["last_run_at"]) ? "ok" : "warn"
      else
        (status[:running] || status["running"]) ? "ok" : "warn"
      end
    end

    def poller_schedule_label(status)
      if poller_cron?(status)
        "rails anomonitor:poll"
      else
        "#{status[:poll_interval] || status["poll_interval"] || Anomonitor.config.poll_interval}s"
      end
    end

    def poller_last_run_label(status)
      last = status[:last_run_at] || status["last_run_at"]
      return "never" unless last

      "#{time_ago_in_words(last)} ago"
    end

    def format_metric(value)
      return "—" if value.nil?

      number_with_precision(value, precision: 0, delimiter: ",")
    end

    def job_status_badge_class(status)
      case status.to_s
      when "failed" then "danger"
      when "locked" then "warn"
      when "pending" then "ok"
      else ""
      end
    end
  end
end
