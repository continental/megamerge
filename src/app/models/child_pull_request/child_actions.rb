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

class ChildPullRequest
  module ChildActions

    #def close!
    #  super
    #  delete_temp_branches!
    #end
#
#
    #def delete_source_branch!
    #  super
    #  delete_temp_branches!
    #end

    def delete_temp_branches!
      logger.info("deleting temp branches for #{id}")
      repository.find_refs("mm/#{id}/")&.each{ |branch| repository.delete_ref(branch) } 
    end

    def megamergeable?
      super || merged? && merge_commit_sha == repository.commit(target_branch).sha
    end

  # fetches a single sub repo with pr templates loaded
    def refresh_repo!(load_templates = false)
      GitHub::GQL.add(repository.name, GitHub::GQL.QUERY, Repository.create_gql_query(repository.organization, repository.repository, load_templates), repository )
      GitHub::GQL.execute    
    end

  end
end
