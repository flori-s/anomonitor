# frozen_string_literal: true

module Anomonitor
  class MutesController < ApplicationController
    def index
      @mutes = Mute.recent.limit(100)
    end

    def create
      seconds = parse_duration(params[:duration].presence || "24h")
      Mute.create!(
        metric: params[:metric].presence,
        rule: params[:rule].presence,
        source: params[:source].presence,
        tenant: params[:tenant].presence,
        muted_until: Time.current + seconds,
        reason: params[:reason].presence
      )
      redirect_to mutes_path, notice: "Mute created until #{seconds / 3600.0}h from now."
    rescue StandardError => e
      redirect_to mutes_path, alert: e.message
    end

    def destroy
      Mute.find(params[:id]).destroy!
      redirect_to mutes_path, notice: "Mute removed."
    end

    private

    def parse_duration(value)
      case value.to_s
      when /\A(\d+)\s*h\z/i then Regexp.last_match(1).to_i * 3600
      when /\A(\d+)\s*m\z/i then Regexp.last_match(1).to_i * 60
      when /\A(\d+)\s*d\z/i then Regexp.last_match(1).to_i * 86_400
      else
        value.to_i.positive? ? value.to_i : 24 * 3600
      end
    end
  end
end
