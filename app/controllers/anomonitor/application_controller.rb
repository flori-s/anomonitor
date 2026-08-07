# frozen_string_literal: true

module Anomonitor
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    layout "anomonitor/application"

    helper Anomonitor::Engine.helpers
  end
end
