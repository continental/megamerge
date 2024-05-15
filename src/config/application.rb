# frozen_string_literal: true

require_relative 'boot'

#require 'rails/all'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'sprockets/railtie'
require 'rails/test_unit/railtie'
require 'active_model/railtie'
require 'active_job/railtie'
require 'octokit'
require 'yaml'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Megamerges
  class Application < Rails::Application
    Rails.application.config.eager_load_paths << Rails.root.join('lib')
    config.watchable_dirs['lib'] = [:rb]
    # Initialize configuration defaults for originally generated Rails version.

    config.load_defaults 5.0
    config.action_dispatch.perform_deep_munge = false

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    def port
      if Rack::Server.new.options[:Port] != 9292 # rails s -p PORT
        Rack::Server.new.options[:Port]
      else
        (ENV['PORT'] || '3000').to_i # ENV['PORT'] for foreman
      end
    end


    config.version_number = '3.12.1'
    # config.version_number+= '.' + File.read('build_version.txt') if File.exist?('build_version.txt')
    config.version_hash = 'unknown'
    config.version_hash = File.read('revision.txt') if File.exist?('revision.txt')

    STDERR.puts "credentials.yml file in root folder missing!!!" unless File.exist?('credentials.yml')
    temp_config = (YAML.load_file('credentials.yml') if File.exist?('credentials.yml')) || {}
    config.url = temp_config['homepage'] || "http://localhost:#{port}"
    config.manual = temp_config['manual'] || "http://localhost:#{port}/howto"
    config.github = {
      server: temp_config['server'] || 'https://www.github.com',
      api: temp_config['api'] || 'https://api.github.com',
      app_id: temp_config['app_id'] || '',
      client: temp_config['client']|| '',
      secret: temp_config['secret']|| '',
      private_key: temp_config['private_key'] || ''
    }

    authorize_context = {
      client_id: config.github[:client]
    }

    config.authorize_url = config.github[:server] + '/login/oauth/authorize?' + authorize_context.to_query

    Octokit.configure do |c|
      c.web_endpoint = config.github[:server]
      c.api_endpoint = config.github[:api]
      c.client_id = config.github[:client]
      c.client_secret = config.github[:secret]
      c.auto_paginate = true
    end
  end
end
