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

module MegaMerge
  # Encodes a child state into the pull request body
  class ChildEncoder
    attr_reader :pull_request

    def self.encode(child)
      new(child).encode
    end

    def initialize(child)
      @pull_request = child
    end

    def encode
      pull_request.body if pull_request.parent?
      Encoder.encode(body: pull_request.body, config: configuration) do
        header
      end
    end

    private

    def header
      <<~HEADER
        ---
        ## MegaMerge
        This Pull Request is part of a MegaMerge Pull Request #{pull_request.parent.md_link}.
        Do _NOT_ merge by hand unless you know what you are doing!
      HEADER
    end

    def configuration
      {
        type: Encoder::CHILD_TYPE,
        parent: pull_request.parent.repository.name,
        parent_id: pull_request.parent.id
      }
    end
  end
end
