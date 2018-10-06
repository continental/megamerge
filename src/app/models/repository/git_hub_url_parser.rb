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

class Repository
  module GitHubUrlParser
    def from_url(url)
      if url =~ /^https?:\/\//
        parse_url(url)
      elsif url =~ /^git@/
        parse_ssh(url)
      end
    end

    private

    def parse_url(url)
      parse(url, /^https?:\/\/[^\/]*\/([^\/]*)\/([^\/]*)\/.git$/)
    end

    def parse_ssh(url)
      parse(url, /^git@[^:]*:([^\/]*)\/([^\/]*)\.git$/)
    end

    def parse(url, regexp)
      match = url.match(regexp)
      return nil if match.nil?
      Repository.new(
        organization: match[1],
        repository: match[2]
      )
    end
  end
end
