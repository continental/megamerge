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
  # Proxy the octokit object
  class OctokitProxy
    attr_accessor :client

    def method_missing(m, *args, &block)
      tries ||= 3
      raise "unable to find method #{m}" unless respond_to_missing?(m,true)
      client.send(m, *args, &block)
    rescue Octokit::Unauthorized => e
      raise e unless e.message.include? 'Bad credentials'
      handle_bad_credentials!(e)
    rescue Faraday::ConnectionFailed => e
      sleep(1)
      logger.info "connection failed to #{Rails.application.config.github[:server]}: #{e.message}"
      retry unless (tries -= 1).zero?
    rescue Octokit::BadGateway => e
      logger.info e.message
      sleep(1)
      retry unless (tries -= 1).zero?
    rescue Octokit::TooManyRequests => e
      logger.info e.message
      raise "secondary rate limit"
    rescue Octokit::Error => e # reraise octokit errors
      raise e
    rescue StandardError => e # catch everything else
      sleep(1)
      logger.info e.message
      logger.info e.backtrace.to_s
      retry unless (tries -= 1).zero?
    end

    def handle_bad_credentials!(e)
      raise e
    end

    def respond_to_missing?(mid, priv)
      client.respond_to?(mid, priv)
    end


    def self.logger
      Rails.logger
    end

    def logger
      self.class.logger
    end


    def self.cache
      Rails.cache
    end

    def cache
      self.class.cache
    end
  end
end
