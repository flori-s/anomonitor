# frozen_string_literal: true

class Anomonitor::InstallGenerator < Rails::Generators::Base
  source_root File.expand_path("templates", __dir__)

  desc "Install Anomonitor initializer"

  def copy_initializer
    template "anomonitor.rb", "config/initializers/anomonitor.rb"
  end

  def show_readme
    say <<~MSG

      Next steps:
        1. rails anomonitor:install:migrations  (or railties:install:migrations FROM=anomonitor)
        2. rails db:migrate
        3. mount Anomonitor::Engine => "/anomonitor" in config/routes.rb
        4. Set ANOMONITOR_WEBHOOK_URL and tune config/initializers/anomonitor.rb
    MSG
  end
end
