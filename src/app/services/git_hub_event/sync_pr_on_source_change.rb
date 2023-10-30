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

module GitHubEvent
  class SyncPrOnSourceChange < EventProcessor

    def self.execute(org, repo, id)
      meta_pr_slug = org+'/'+repo+'/'+id
      logger.info "checking #{meta_pr_slug} because its source has changed"
      with_flock(meta_pr_slug) do
        meta_pr = MetaPullRequest.load(org,repo,id)
        (logger.info "skipping #{meta_pr.slug} because state is draft"; next) if meta_pr.draft?
        logger.info "updating #{meta_pr.slug} to #{meta_pr.update_config_file!}" if meta_pr.config_outdated?
      end

    end

    def pulls
      return [payload[:pull_request]]
    end

  end
end
