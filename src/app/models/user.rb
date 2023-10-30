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

class User < BaseModel
  def self.from_github_data(client, data)
    User.new(
      client: client,
      login: data[:login],
      html_url: data[:html_url]
    )
  end

  def self.from_gql(client, data)
    User.new(
      client: client,
      login: data[:login],
      html_url: "empty"
    )
  end

  def update_from_gql(data) 
    @name = data[:name] if data.key?(:name)
  end

  attr_accessor :client, :login, :html_url, :name

  def create_gql_get_name()
    query = 
      "h_#{login.hash.abs}: user(login: \"#{login}\") {
        name
      }"
  end

  def name
    @name ||= client.user(login).name if login?
  rescue StandardError
    @name ||= login
  end

  def login?
    !login.nil?
  end
end
