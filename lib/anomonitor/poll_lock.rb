# frozen_string_literal: true

module Anomonitor
  class PollLock
    LOCK_KEY = 8_604_071_000 # stable advisory lock id for Anomonitor
    LOCK_FILE = "tmp/anomonitor_poll.lock"

    def self.with_lock(enabled: Anomonitor.config.poll_lock)
      return yield unless enabled

      new.with_lock { yield }
    end

    def with_lock
      if postgres?
        with_pg_lock { yield }
      else
        with_file_lock { yield }
      end
    end

    private

    def postgres?
      return false unless defined?(ActiveRecord::Base)

      adapter = ActiveRecord::Base.connection.adapter_name.to_s.downcase
      adapter.include?("postgres")
    rescue StandardError
      false
    end

    def with_pg_lock
      conn = ActiveRecord::Base.connection
      locked = conn.select_value("SELECT pg_try_advisory_lock(#{LOCK_KEY})")
      unless locked == true || locked == "t" || locked == 1
        Anomonitor.logger.info("[Anomonitor] Poll skipped — advisory lock held by another process")
        return []
      end

      yield
    ensure
      begin
        conn&.execute("SELECT pg_advisory_unlock(#{LOCK_KEY})")
      rescue StandardError
        nil
      end
    end

    def with_file_lock
      path = lock_path
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, File::RDWR | File::CREAT, 0o644) do |file|
        unless file.flock(File::LOCK_EX | File::LOCK_NB)
          Anomonitor.logger.info("[Anomonitor] Poll skipped — file lock held by another process")
          return []
        end
        yield
      end
    end

    def lock_path
      root = defined?(Rails) && Rails.respond_to?(:root) && Rails.root ? Rails.root : Dir.pwd
      File.join(root.to_s, LOCK_FILE)
    end
  end
end
