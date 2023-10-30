# frozen_string_literal: true

# Copyright (c) 2021 Continental Automotive GmbH
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
  # Github access through bot client
  class Bot < App
    # The default github access token lifetime is 1 hour.
    # Give 2 minutes as a buffer for refreshing it
    ACCESS_TOKEN_EXPIRATION = 58.minutes

    attr_accessor :id, :organization

    def self.from_organization(organization)
      # The ID should change very infrequently. This will only happen
      # if the App is uninstalled or reinstalled.
      id = cache.fetch(
        :"#{organization}_installation_id",
        race_condition_ttl: 5.seconds,
        expires_in: ACCESS_TOKEN_EXPIRATION
      ) do
        data = GitHub::App.new.find_app_installations.find do |install|
          install[:account][:login] == organization
        end
        data&.[](:id)
      end
      raise "unable to find app installation for org #{organization}" if id.nil?

      new(id: id, organization: organization)
    end

    def self.organization_repos(organization)
      from_organization(organization)
        .list_installation_repos[:repositories].map { |repo| repo[:name] }
    end

    def initialize(id: nil, organization: nil)
      @id = id
      @organization = organization
    end

    protected

    def client
      
      regen = false
      access_token = cache.fetch(
        :"#{organization}_access_token_#{id}",
        race_condition_ttl: 5.seconds,
        expires_in: ACCESS_TOKEN_EXPIRATION
      ) do
        regen = true
        super.create_app_installation_access_token(id)[:token]
      end
      if regen
        #@client = Octokit::Client.new(access_token: access_token)
        @client = OctokitClientProxy.new(access_token: access_token)
      else
        #@client ||= Octokit::Client.new(access_token: access_token)
        @client ||= OctokitClientProxy.new(access_token: access_token)
      end
    end

    def handle_bad_credentials!(_e)
      cache.delete(:"#{organization}_access_token_#{id}")
      cache.delete(:"#{organization}_installation_id")
      super
    end
  end
end
