ENV['RAILS_ENV'] = 'test'
require "bundler/setup"
require 'database_cleaner'
require "test/tracer"
require "tracing/matchers"
require "delayed/plugins/tracer"
require "pry"

require "support/migrate/create_delayed_jobs"
require "generators/delayed_job/templates/migration"

# Delayed::Worker.logger = Logger.new(STDOUT)
ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :database => ':memory:'
ActiveRecord::Base.logger = Delayed::Worker.logger
ActiveRecord::Migration.verbose = true

CreateDelayedJobs.up
AddMetadataToDelayedJobs.up

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.after(:each) do
    Delayed::Worker.reset
  end
end
