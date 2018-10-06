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

class MergeController < ApplicationController
  rescue_from Octokit::NotFound, with: :redirect_to_step1
  rescue_from Octokit::Forbidden, with: :redirect_home

  def redirect_home
    redirect_to logout_path
  end

  def redirect_to_step1
    msg = +"Could not find #{params[:organization]}"
    msg += "/#{params[:repository]}" if params[:repository]
    msg += "/#{params[:target_branch]}" if params[:target_branch]
    redirect_to step1_path, danger: msg
  end

  def step1
    @installations = @user.installations.map { |inst| inst[:account][:login] }
  end

  def complete_step1
    redirect_to step2_path(params[:installation])
  end

  def step2
    @repos = @user.installation_repositories(params[:organization]).map do |repo|
      repo[:name]
    end
  rescue Octokit::Error => error
    redirect_to(
      step1_path,
      danger: "Something went wrong: #{error.message}. Please try again."
    )
  end

  def complete_step2
    redirect_to(step3_path(params[:organization], params[:repository]))
  end

  def step3
    repo = Repository.from_params(params)
    @open_prs = repo.pull_requests(state: 'open')
    @branches = repo.branches.map { |branch| branch[:name] }
  rescue Octokit::Error => error
    redirect_to(step2_path(params[:organization]),
                danger: "Something went wrong: #{error.message}. Please try again.")
  end

  def step4
    @files = AvailableConfigFiles.call(params[:organization],
                                       params[:repository],
                                       params[:target_branch])
    return if @files.is_a? Array
    redirect_to(
      %W[
        /create
        #{PullRequest.branch_slug(Repository.from_params(params),
                                  params[:source_branch],
                                  params[:target_branch])}
        #{@files}
      ].join('/')
    )
  rescue Octokit::Error => error
    redirect_to(
      step3_path(params[:organization], params[:repository]),
      danger: "Something went wrong: #{error.message}. Please try again."
    )
  end

  def show_repository
    @pr = MegaMergeChildPullRequest.call(params)
    render partial: 'show_repository', layout: false
  end

  def search_subrepos
    @pr = MegaMergePullRequest.call(params)
    @found_repos = @pr.find_target_repositories(params[:search_branch])
    render partial: 'search_subrepos', layout: false
  end

  def get_repositories
    render json: {
      results: @user.installation_repositories(params[:organization]).map do |repo|
        { id: repo.name, text: repo.name }
      end
    }.to_json
  end

  def show
    @pr = MegaMergePullRequest.call(params)
    # PR exists but default.xml was not set
    if @pr.nil?
      pr = PullRequest.from_github_data(
        Repository.from_params(params)
                  .pull_request(params[:pull_id])
      )
      redirect_to("/create/#{pr.branch_slug}") && return
    end

    return if @pr.done?
    # TODO: Add multi organization support. Need to adjust the show repo view for this
    # otherwise all the logic should be implemented. Simply remove the trim when done
    @repos_in_organization = @pr.target_file.projects.keys.map { |k| k.partition('/').last }
  end

  def save
    meta_pr = SaveMegaMergeState.call(@user, params[:meta_repo], params[:sub_repos], params[:sub_repo_actions])
    repo = meta_pr.repository
    redirect_to(view_pr_path(repo.organization, repo.repository, meta_pr.id))
  rescue Octokit::UnprocessableEntity => e
    redirect_to :back, danger: e.message
  end

  def final_merge
    MergeMegaMerge.call(params[:organization], params[:repository], params[:pull_id])
    redirect_to :back
  rescue Octokit::MethodNotAllowed => e
    redirect_to :back, danger: e.message
  end

  def close_pr
    CloseMegaMerge.call(params[:organization], params[:repository], params[:pull_id])
    redirect_to :back
  end

  def reopen_pr
    ReopenMegaMerge.call(params[:organization], params[:repository], params[:pull_id])
    # TODO: make an update here because temp hashes have changed, right now user has to do this by himself
    redirect_to :back
  end

  def delete_source_branches
    DeleteMegaMergeBranches.call(params[:organization], params[:repository], params[:pull_id])
    redirect_to :back
  end
end
