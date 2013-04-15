ENV["RAILS_ENV"] ||= "test"
require File.expand_path("../../config/environment", __FILE__)
require "rspec/rails"
require "rspec/autorun"
require "capybara/rspec"
require "capybara/poltergeist"

Capybara.javascript_driver = :poltergeist
WebMock.disable_net_connect!(allow_localhost: true)

Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

RSpec.configure do |config|
  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  config.use_transactional_fixtures = true

  config.infer_base_class_for_anonymous_controllers = false

  config.order = "random"

  config.include ActionView::TestCase::Behavior, example_group: { file_path: %r{spec/presenters} }

  VCR.configure do |c|
    c.cassette_library_dir = "spec/cassettes"
    c.hook_into :webmock
    c.ignore_hosts "127.0.0.1", "localhost"
  end

  if ENV["JENKINS_CI"]
    config.filter_run_excluding :upload
  end

  config.before(:suite) do
    Redis.current.select(1)
  end

  config.before do
    [Post, Comment].each { |model| model.paginates_per(Kaminari.config.default_per_page) }
    Redis.current.flushdb

    example.metadata[:truncate] = true if example.metadata[:js]

    DatabaseCleaner.strategy = example.metadata[:truncate] ? :truncation : :transaction
    DatabaseCleaner.start

    if example.metadata[:solr]
      Sunspot.remove_all!
    else
      Sunspot.session = Sunspot::Rails::StubSessionProxy.new(Sunspot.session)
    end
  end

  config.after do
    DatabaseCleaner.clean
    Timecop.return
    FileUtils.rm_rf(Rails.root.join("public/uploads/test"))

    if example.metadata[:solr]
      Sunspot.config.pagination.default_per_page = DEFAULT_PER_PAGE
    else
      Sunspot.session = Sunspot.session.original_session
    end
  end
end
