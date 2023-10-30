# frozen_string_literal: true

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  config.web_console.whitelisted_ips = ['0.0.0.0/0']

  # Do not eager load code on boot.
  config.eager_load = true
  config.enable_dependency_loading = true

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join('tmp', 'disable-cache').exist?
    config.action_controller.perform_caching = false
    config.cache_store = :null_store
  else
    config.action_controller.perform_caching = true
    config.cache_store = :file_store, "#{root}/tmp/cache/" # this is the default in production
    config.public_file_server.headers = {
      'Cache-Control' => "public, max-age=#{2.days.to_i}"
    }
  end
  # Store uploaded files on the local file system (see config/storage.yml for options)
  # config.active_storage.service = :local

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  config.action_mailer.perform_caching = false
  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log
  # Raise an error on page load if there are pending migrations.
  #config.active_record.migration_error = :page_load
  # Highlight code that triggered database queries in logs.
  #config.active_record.verbose_query_logs = true

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true

  # Suppress logger output for asset requests.
  config.quiet = true

  # Adds additional error checking when serving assets at runtime.
  # Checks for improperly declared sprockets dependencies.
  # Raises helpful error messages.
  config.assets.raise_runtime_errors = true

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true

  config.log_level = :info
  config.lograge.enabled = true

  # Prepend all log lines with the following tags.
  config.log_tags = [->(request) { request.headers['X-GitHub-Event'] }]

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  #config.file_watcher = ActiveSupport::EventedFileUpdateChecker
  config.file_watcher = ActiveSupport::FileUpdateChecker
  config.reload_classes_only_on_change = false

  # Suppress partials
  config.action_view.logger = nil
  
  config.logger = MegamergeLogger.new("log.txt", 2, 25.megabytes)
  config.logger.formatter = proc { |severity, datetime, progname, msg| msg }

end
