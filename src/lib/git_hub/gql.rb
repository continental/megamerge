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
  class GQL < BaseModel
    class << self
      def add(repo_with_owner, type, query, classInstance = nil)
        return if query.blank?
        org, repo = repo_with_owner.split('/')

        store[org] = {:mutation => "", :query => "", :repo => Repository.from_name(repo_with_owner)} unless store.include?(org)

        if classInstance.nil?
          store[org][type] += query
        else
          hash = "h_" + query.hash.abs.to_s 
          store[org][type] += hash + ": " + query
          hash_to_instance[hash] = classInstance
        end

        #logger.info store.to_json
      end


      def execute(strict_mode = false)
        resp = {}
        # exec gql calls
        store.each do |key, data|
          do_gql_request(data[:repo], { :query => "mutation { #{data[:mutation]} }" }.to_json, strict_mode) unless data[:mutation].blank?
          resp.merge!(do_gql_request(data[:repo], { :query => "query { #{data[:query]} }" }.to_json, strict_mode)[:data]) unless data[:query].blank?
        end

        # update class instances
        hash_to_instance.each do |key, instance|
          instance.update_from_gql(resp[key.to_sym]) if resp.key?(key.to_sym) && instance.class.method_defined?(:update_from_gql)
        end

        resp
      ensure
        # clear after executed  
        @hash_to_instance = {}
        @store = {} 
      end


      def do_gql_request(repo, query, strict_mode)
        begin
          tries ||= 3
          response = repo.post('/api/graphql', query)
        rescue => e
          raise e unless e.message.include? "502 Bad Gateway"
            logger.info e.message
            sleep(1)
            retry unless (tries -= 1).zero?
        end

        if response.key?(:errors)

          # skip error print if unable to get branch protecton rule
          ignore_error = response[:errors].all? do |error|
            error = error.to_h
            #logger.info " -> #{error.to_json} #{error.dig(:type).eql? 'FORBIDDEN'} #{error.dig(:path).include? 'branchProtectionRule'}"
            next true if (error.dig(:type).eql? "FORBIDDEN") && !error.dig(:path).nil? && (error.dig(:path).include? "branchProtectionRule")
            false
          end

          logger.info "request:\n #{query} \n reponse:\n #{response.to_json}" unless ignore_error
          raise "Error in GQL request: #{response[:errors][0][:message]}" if !response.key?(:data) || strict_mode
        end
        response
      end

      JSON_ESCAPE_MAP = {
        '\\'    => '\\\\',
        '</'    => '<\/',
        "\r\n"  => '\n',
        "\n"    => '\n',
        "\r"    => '\n',
        '"'     => '\\"' }
    
      def escape(json)
        json.gsub(/(\\|<\/|\r\n|[\n\r"])/) { JSON_ESCAPE_MAP[$1] }
      end

      def hash_to_instance
        @hash_to_instance ||= {}
      end

      def store
        @store ||= {}
      end

      def MUTATION
        :mutation
      end

      def QUERY
        :query
      end
    end
  end
end
