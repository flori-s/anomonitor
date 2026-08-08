# frozen_string_literal: true

require "test_helper"

class ConfigurationValidatorTest < AnomonitorTestCase
  def test_warns_without_notifier
    warnings = Anomonitor::ConfigurationValidator.warnings
    assert warnings.any? { |w| w.include?("No notifier") }
  end

  def test_warns_on_thread_mode
    Anomonitor.configure { |c| c.poll_mode = :thread }
    warnings = Anomonitor::ConfigurationValidator.warnings
    assert warnings.any? { |w| w.include?("poll_mode=:thread") }
  end
end
