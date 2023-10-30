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

module Helpers
  def select_select2(id, value, open: true, **opts)
    page.execute_script("$(document.getElementById('#{id}')).val('#{value}')")
    page.execute_script("$(document.getElementById('#{id}')).trigger('change')")
    # find("#select2-#{id}-results li", exact_text: value, **opts).click
  end

  def find_hidden_input(name, el = nil)
    find_input(name, el, visible: false)
    # find("input[name=\"#{name}\"", visible: false)
  end

  def find_input(name, el = nil, options = {})
    if el
      el.find("input[name=\"#{name}\"", options)
    else
      find("input[name=\"#{name}\"", options)
    end
  end

  def have_hidden_input(name, el = nil, options = {})
    if el
      el.has_css?("input[name=\"#{name}\"", options)
    else
      has_css?("input[name=\"#{name}\"", options)
    end
  end

  def organization
    Rails.application.config.test_repository[:organization]
  end

  def repository
    Rails.application.config.test_repository[:repository]
  end

  def sub_repos
    Rails.application.config.test_repository[:sub_repos]
  end

  def source_branch
    Rails.application.config.test_repository[:source_branch]
  end

  def shadow_branch
    source_branch
  end

  def target_branch
    Rails.application.config.test_repository[:target_branch]
  end

  def default_title
    "[#{source_branch}] #{source_branch} -> #{target_branch}"
  end

  def xml_file
    'default.xml'
  end

  def gitmodules_file
    '.gitmodules'
  end

  def repo
    @repo ||= Repository.new(organization: organization, repository: repository)
  end

  def create_sub_repo_branches!
    sub_repos.each do |sub_repo|
      client = Repository.from_params(sub_repo)
      sha = client.contents(
        path: sub_repo[:file_to_change],
        ref: sub_repo[:target_branch]
      )[:sha]
      client.create_branch!(sub_repo[:source_branch], sub_repo[:target_branch])
      client.update_contents(
        sub_repo[:file_to_change],
        'Test update content',
        sha,
        Time.current.to_s,
        branch: sub_repo[:source_branch]
      )
    end
  end

  def create_sub_repo_prs!
    create_sub_repo_branches!
    sub_repos.each do |sub_repo|
      client = Repository.from_params(sub_repo)
      client.create_pull_request(sub_repo[:target_branch], sub_repo[:source_branch], 'test')
    end
  end

  def delete_parent_pr!
    repo.pull_requests(state: 'open').each do |pull|
      repo.close_pull_request(pull[:number])
    end
    silence_errors { repo.delete_branch(source_branch) }
    silence_errors { repo.delete_branch(shadow_branch) }
  end

  def delete_sub_repo_prs!
    sub_repos.each do |sub_repo|
      client = Repository.from_params(sub_repo)
      client.pull_requests(state: 'open').each do |pull|
        client.close_pull_request(pull[:number])
      end
      silence_errors { client.delete_branch(sub_repo[:source_branch]) }
    end
  end
end
