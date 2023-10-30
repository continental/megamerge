# frozen_string_literal: true

# Copyright (c) 2018 Continental Automotive GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module GitHub
  # Github access over user token
  class User < OctokitProxy
    def self.token(code, options = {})
      token = Octokit.exchange_code_for_token(
        code,
        Rails.application.config.github[:client],
        Rails.application.config.github[:secret],
        options
      )
      token[:access_token]
    end

    attr_accessor :user, :client

    def initialize(token)
      #@client = Octokit::Client.new(access_token: token)
      @client = OctokitClientProxy.new(access_token: token)
      @user = @client.user
    end

    def installations
      find_user_installations[:installations]
    end

    def installation_repositories(organization)
      Rails.cache.fetch(
        "#{organization}_app_repos",
        expires_in: 15.minute
      ) do
        GitHub::Bot.from_organization(organization).list_app_installation_repositories[:repositories].map do |repo|
          repo[:name]
        end
      end
      
    end
    alias inst_repos installation_repositories

    def authorized(organization)
      # installation_repositories(organization).any? do
    end
    # def self.login(token)
    #   logger.info 'User authorization'
    #   new(access_token: token)
    #   # In the test environment we're using a personal access token, so
    #   # this check needs to be skipped
    #   # client.check_application_authorization(token) if ENV['RAILS_ENV'] != 'test'
    #   client
    # end
  end
end
