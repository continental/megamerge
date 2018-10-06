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
  # Github access as app client
  class App < OctokitProxy
    # Github App Tokens have a maximum lifetime of 10 minutes
    # Can't use exactly 10 minutes as github complains that the token
    # lasts too long.
    TOKEN_TIMEOUT = 9.minutes

    # Cache timeout buffer
    # Refreshes the token 1 minute before official expiry
    TOKEN_TIMEOUT_BUFFER = 1.minute

    def self.app_id
      Rails.application.config.github[:app_id]
    end

    protected

    def client
      regen = false
      token = cache.fetch(
        :jwt_token,
        race_condition_ttl: 5.seconds,
        expires_in: TOKEN_TIMEOUT - TOKEN_TIMEOUT_BUFFER
      ) do
        regen = true
        jwt_token
      end
      if regen
        @client = Octokit::Client.new(bearer_token: token)
      else
        @client ||= Octokit::Client.new(bearer_token: token)
      end
    end

    def handle_bad_credentials!(e)
      cache.delete(:jwt_token)
    end

    def jwt_token
      JWT.encode(payload, private_key, 'RS256')
    end

    def payload
      iat = Time.now.utc.to_i
      {
        iat: iat,
        exp: iat + TOKEN_TIMEOUT,
        iss: app_id
      }
    end

    def app_id
      self.class.app_id
    end

    def private_key
      puts private_pem.to_yaml
      OpenSSL::PKey::RSA.new(private_pem)
    end

    def private_pem
      Rails.application.config.github[:private_key]
    end
  end
end
