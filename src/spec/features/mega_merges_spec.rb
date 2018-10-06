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

RSpec.configure do |config|
  config.include AuthHelpers
  config.include Helpers
end

RSpec.feature 'MegaMerges', type: :feature do
  before do
    login
  end

  describe 'navigate steps', type: :controller, js: true do
    it 'should pass step1' do
      visit step1_path
      select_select2('installation', organization)
      expect(page).to have_current_path(step2_path(organization))
    end

    it 'should pass step2' do
      visit step2_path organization
      select_select2('repository', repository)
      find_by_id('continue').click
      expect(page).to have_current_path(step3_path(organization, repository))
    end

    it 'should pass step3 by entering a target branch name' do
      visit step3_path organization, repository
      fill_in('source_branch_input', with: source_branch)
      select_select2('target_branch', target_branch)
      expect(page).to have_css('select#source_branch[disabled]', visible: false)
      find_by_id('continue').click
      expect(page).to have_current_path(step4_path(organization, repository, source_branch, target_branch))
    end

    it 'should pass step3 by entering an existing target branch name' do
      repo.create_branch!(source_branch, target_branch)

      visit step3_path organization, repository
      select_select2('source_branch', source_branch)
      select_select2('target_branch', target_branch)
      find_by_id('continue').click
      expect(page).to have_current_path(step4_path(organization, repository, source_branch, target_branch))

      repo.delete_branch(source_branch)
    end

    it 'should pass step4 by selecting the xml file' do
      visit step4_path organization, repository, source_branch, target_branch
      select_select2('fileSelect', xml_file)
      find_by_id('continue').click
      expect(page).to have_current_path(final_path(organization, repository, source_branch, target_branch, xml_file))
    end

    it 'should pass step4 by selecting the gitmodules file' do
      visit step4_path organization, repository, source_branch, target_branch
      select_select2('fileSelect', gitmodules_file)
      find_by_id('continue').click
      expect(page).to have_current_path(final_path(organization, repository, source_branch, target_branch, gitmodules_file))
    end

    it 'should display a new pull request on show' do
      visit final_path organization, repository, source_branch, target_branch, xml_file
      expect(find_hidden_input('meta_repo[pull_id]').value).to eq('0')
      expect(find_hidden_input('meta_repo[repository]').value).to eq(repository)
      expect(find_hidden_input('meta_repo[organization]').value).to eq(organization)
      expect(find_hidden_input('meta_repo[source_branch]').value).to eq(source_branch)
      expect(find_hidden_input('meta_repo[shadow_branch]').value).to eq(shadow_branch)
      expect(find_hidden_input('meta_repo[config_file]').value).to eq(xml_file)
      expect(find_input('meta_repo[title]').value).to eq(default_title)
    end

    it 'should add a sub repository' do
      visit final_path organization, repository, source_branch, target_branch, xml_file
      find_by_id('add-sub-repo').click
      subrepo = sub_repos.first
      select_select2('addSubRepoName', subrepo[:repository], open: false)
      row = find_by_id("subrepos/#{subrepo[:organization]}/#{subrepo[:repository]}")
      expect(find_hidden_input('sub_repos[][pull_id]', row).value).to eq('0')
    end

    it 'should add multiple sub repositories' do
      visit final_path organization, repository, source_branch, target_branch, xml_file
      find_by_id('add-sub-repo').click
      subrepo = sub_repos.first
      select_select2('addSubRepoName', subrepo[:repository], open: false)
      row = find_by_id("subrepos/#{subrepo[:organization]}/#{subrepo[:repository]}")
      expect(find_hidden_input('sub_repos[][pull_id]', row).value).to eq('0')

      find_by_id('add-sub-repo').click
      subrepo = sub_repos.second
      select_select2('addSubRepoName', subrepo[:repository], open: false)
      row = find_by_id("subrepos/#{subrepo[:organization]}/#{subrepo[:repository]}")
      expect(find_hidden_input('sub_repos[][pull_id]', row).value).to eq('0')
    end

    it 'should remove an added sub repository' do
      visit final_path organization, repository, source_branch, target_branch, xml_file
      find_by_id('add-sub-repo').click
      subrepo = sub_repos.first
      select_select2('addSubRepoName', subrepo[:repository], open: false)
      row = find_by_id("subrepos/#{subrepo[:organization]}/#{subrepo[:repository]}")
      expect(find_hidden_input('sub_repos[][pull_id]', row).value).to eq('0')

      find_by_id("subrepos/#{subrepo[:organization]}/#{subrepo[:repository]}-btn-x").click
      expect(page).to have_no_css("#subrepos/#{subrepo[:organization]}/#{subrepo[:repository]}")
    end
  end
end
