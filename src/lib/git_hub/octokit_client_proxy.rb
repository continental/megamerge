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
  class OctokitClientProxy

    def initialize(token)
      @new_client = Octokit::Client.new(token)
    end

    def method_missing(m, *args, &block)
      proxy_call(m, *args, &block)
    end

    def send(m, *args, &block)
      proxy_call(m, *args, &block)
    end

    def respond_to?(mid, priv)
      @new_client.respond_to?(mid, priv)
    end

    def proxy_call(m, *args, &block)
      starting = Time.now

      do_logging  = !(m.to_s.include? "create_blob") # Rails.env.production?

      logger.info "API CALL: #{m} #{args[0]} #{args[1]} " if do_logging  # unless 
      
      ret = @new_client.send(m, *args, &block)
      ending = Time.now

      if do_logging
        if args[1].eql? "/api/graphql"
          logger.print ((caller[6].include? "gql.rb") ? caller[7].to_s : caller[6].to_s) 
        else
          logger.print ((caller[1].include? "method_missing") ? caller[2].to_s : caller[1].to_s) 
        end
        logger.print  " #{ending - starting} sec" 

        logger.api_call ending - starting
      end
      ret
    end

    
    def self.logger
      Rails.logger
    end

    def logger
      self.class.logger
    end

  end
end
