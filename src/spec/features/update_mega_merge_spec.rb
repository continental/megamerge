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

require 'rails_helper'
require 'support/auth_helpers'
require 'support/helpers'
require 'support/show_page_helpers'

RSpec.configure do |config|
  config.include AuthHelpers
  config.include Helpers
  config.include ShowPageHelpers

  config.before(:context) do
    create_sub_repo_branches!
  end

  config.after(:context) do
    delete_parent_pr!
    delete_sub_repo_prs!
  end
end

RSpec.feature 'UpdateMegaMerge', type: :feature do
  describe 'save & update with single repository', type: :controller, js: true do
    def subrepo_selector(subrepo)
      "subrepo-#{subrepo[:organization]}-#{subrepo[:repository]}"
    end

    before do
      login
      visit final_path organization, repository, source_branch, target_branch, xml_file
      @subrepo = sub_repos.first
      add_sub_repo(@subrepo)
      # TODO: find better way than to sleep here
      sleep 1
      select_select2("#{subrepo_selector(@subrepo)}-source_branch", @subrepo[:source_branch])
      find_by_id('saveChangesButton').click
    end

    it 'should create missing pull requests' do
      row = select_sub_repo_row(@subrepo)
      pull_id = find_hidden_input('meta_repo[pull_id]').value.to_i
      sub_pull_id = find_hidden_input('sub_repos[][pull_id]', row).value.to_i

      expect(pull_id).to be > 0
      expect(find_hidden_input('meta_repo[source_branch]').value).to eq(source_branch)
      expect(find_hidden_input('meta_repo[shadow_branch]').value).to eq(shadow_branch)
      expect(sub_pull_id).to be > 0
    end
  end
end
