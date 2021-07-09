require "bundler/setup"
require "rensei"
require "super_diff/rspec"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do |example|
    unless (example.metadata[:ruby_version] || ("2.6.0"...)).cover? RUBY_VERSION
      skip
    end
  end
end
