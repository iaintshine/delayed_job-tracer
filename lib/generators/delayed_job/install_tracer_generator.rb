require "rails/generators"
require "rails/generators/active_record"

module DelayedJob
  class InstallTracerGenerator < Rails::Generators::Base
    include ActiveRecord::Generators::Migration
    source_root File.expand_path("../templates", __FILE__)

    def add_migration
      migration_template "migration.rb", "db/migrate/add_metadata_to_delayed_jobs.rb"
    end
  end
end

