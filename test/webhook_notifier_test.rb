# frozen_string_literal: true

require "test_helper"
require "json"

class WebhookNotifierTest < AnomonitorTestCase
  def test_skips_when_url_blank
    anomaly = Anomonitor::Anomaly.create!(
      rule: "threshold",
      source: "sidekiq",
      metric: "queue_depth",
      value: 10,
      threshold: 5,
      severity: "high",
      cooldown_key: "test:1",
      sampled_at: Time.current
    )

    refute Anomonitor::Notifiers::Webhook.new(url: nil).deliver(anomaly)
  end

  def test_posts_json_payload
    anomaly = Anomonitor::Anomaly.create!(
      rule: "threshold",
      source: "sidekiq",
      metric: "queue_depth",
      value: 4200,
      threshold: 1000,
      severity: "high",
      cooldown_key: "test:2",
      sampled_at: Time.current,
      tags: { "queue" => "default" }
    )

    captured = {}
    fake_response = Object.new
    def fake_response.is_a?(klass)
      klass == Net::HTTPSuccess || super
    end
    def fake_response.code
      "200"
    end
    def fake_response.body
      "ok"
    end

    fake_http = Object.new
    fake_http.define_singleton_method(:use_ssl=) { |_| }
    fake_http.define_singleton_method(:open_timeout=) { |_| }
    fake_http.define_singleton_method(:read_timeout=) { |_| }
    fake_http.define_singleton_method(:request) do |req|
      captured[:body] = req.body
      captured[:content_type] = req["Content-Type"]
      fake_response
    end

    Net::HTTP.stub :new, fake_http do
      assert Anomonitor::Notifiers::Webhook.new(url: "https://hooks.example.com/x").deliver(anomaly)
    end

    payload = JSON.parse(captured[:body])
    assert_equal "anomonitor", payload["gem"]
    assert_equal "anomaly.detected", payload["event"]
    assert_equal 4200, payload["value"]
    assert_equal "application/json", captured[:content_type]
  end

  def test_slack_incoming_webhook_text_includes_tenant
    anomaly = Anomonitor::Anomaly.create!(
      rule: "threshold",
      source: "table:supp_jobs",
      metric: "queue_depth",
      value: 50,
      threshold: 10,
      severity: "high",
      cooldown_key: "test:slack",
      sampled_at: Time.current,
      tags: { "tenant" => "acme", "items" => "foo" }
    )

    captured = {}
    fake_response = Object.new
    def fake_response.is_a?(klass)
      klass == Net::HTTPSuccess || super
    end
    def fake_response.code
      "200"
    end
    def fake_response.body
      "ok"
    end

    fake_http = Object.new
    fake_http.define_singleton_method(:use_ssl=) { |_| }
    fake_http.define_singleton_method(:open_timeout=) { |_| }
    fake_http.define_singleton_method(:read_timeout=) { |_| }
    fake_http.define_singleton_method(:request) do |req|
      captured[:body] = req.body
      fake_response
    end

    Net::HTTP.stub :new, fake_http do
      assert Anomonitor::Notifiers::Webhook.new(url: "https://hooks.slack.com/services/T/B/X").deliver(anomaly)
    end

    payload = JSON.parse(captured[:body])
    assert payload["text"].include?("acme")
    assert payload["text"].include?("queue_depth")
    refute payload.key?("gem")
  end
end
