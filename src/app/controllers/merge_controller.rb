# frozen_string_literal: true

# Copyright (c) 2021 Continental Automotive GmbH
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
  rescue_from StandardError, with: :handle_any_exception
  rescue_from Octokit::Error, with: :handle_octokit_exception # mind the order of the rescue_from!
  rescue_from MegamergeException, with: :handle_megamerge_exception

  def handle_megamerge_exception(e)
    logger.error e.message
    redirect_to step3_path, danger: e.message
  end

  def handle_octokit_exception(e)
    logger.error e.backtrace.to_s
    #added log because of ActionController::UrlGenerationError in MergeController#step3
    logger.info e.message
    #logger.info "Is your Github Apps credentials and private key ok?"
    errormsg = e.message.split(' // ', 2).first
    if errormsg.include? "404 - Not Found"
      url = (errormsg.split(' ').second.sub "api/v3/repos/", "")[0...-1]
      errormsg = "Repository not found!<br> Make sure that you have access to:<a href='#{url}'>#{url}</a> "
    end
    redirect_to step3_path, danger: errormsg
  end

  def handle_any_exception(e)
    logger.error e.message + "\n" + e.backtrace.join("\n")
    redirect_to step3_path, danger: "An Exception of type #{e.class} has occured. Please contact the Megamerger Team <br>#{e.message.split(' // ', 2).first}"
  end

  def step3
    @organizations = @user.installations.map { |inst| inst[:account][:login] }
    return unless params[:organization]

    @repos = @user.installation_repositories(params[:organization])
    
    return unless params[:repository]

    @repo = Repository.from_params(params)
    @open_prs = @repo.pull_requests_gql

    @open_prs.each{ |pr | GitHub::GQL.add(@repo.name, GitHub::GQL.QUERY, pr.author.create_gql_get_name()) }
    resp = GitHub::GQL.execute
    @open_prs.each { |pr| pr.author.name = resp.dig("h_#{pr.author.login.hash.abs}".to_sym, :name) }

    @branches = @repo.branches.map { |branch| branch[:name] }

    session[:organization] = params[:organization]
    session[:repository] = params[:repository]
  rescue Octokit::NotFound
    redirect_to "/create", danger: "seems like <b>#{params[:organization]}/#{params[:repository]}</b>  was not found or is not accessable to you"
  rescue StandardError => e
    logger.error e.message + "\n" + e.backtrace.join("\n")
    redirect_to "/create", danger: "An Exception of type #{e.class} has occured. Please contact the Megamerger Team <br>#{e.message.split(' // ', 2).first}"
  end

  def step4
    params[:source_branch] = params[:source_branch].strip # remove whitespaces
    @files = AvailableConfigFiles.call(params[:organization],
                                       params[:repository],
                                       params[:target_branch],
                                       params[:source_branch])

    if @files.length.zero?
      redirect_to(step3_path(params[:organization],params[:repository]),
                  danger: "<i>#{params[:organization]}/#{params[:repository]}</i> \
                           is not a <b>Meta</b> Repository. \
                           Did you select the correct Repository?")
    end

    return if @files.is_a?(Array)

    redirect_to(
      %W[
        /create
        #{PullRequest.branch_slug(Repository.from_params(params),
                                  params[:source_branch],
                                  params[:target_branch])}
        #{@files}
      ].join('/')
    )
  end

  # route: /view/:organization/:repository/
  # params: data
  # description: queries a child pull request from pr data
  # return: render child pull request template /views/merge/_sub_repo.erb with child if successfull
  #         render error template /views/merge/_sub_repo_error.erb if unsuccessfull 
  def show_repository
    raise "no parameters supplied" if params[:data].nil?
    child = ChildPullRequest.from_params(params[:data])
    child.refresh_repo!(load_templates = true) 
    render partial: 'sub_repo', layout: false, locals: { child: child }
  rescue Octokit::Error => e
    render partial: 'sub_repo_error', layout: false, locals: { e: e }
    logger.error e.message + "\n" + e.backtrace.join("\n")
  rescue StandardError => e
    render partial: 'sub_repo_error', layout: false, locals: { e: e }
    logger.error e.message + "\n" + e.backtrace.join("\n")
  end

  # route: /create/:organization/:repository/:source_branch/:target_branch/:config_file
  # route: /view/:organization/:repository/:pull_id
  # params: organization, repository, source_branch, target_branch, pull_id, config_file, source_repo_full_name
  # description: queries an existing pr for /view route or creates a new pr for /create route
  # return: render html /views/merge/show.html.erb with @pr
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
 
    @pr.meta_config.find_includes unless @pr.done?  # else source branches might be already deleted and can't be read

    # search for repos with same source branch name and add them
    if !@pr.id?
      found_repos = @pr.find_target_repositories(@pr.source_branch) 

      @pr.children = found_repos.map do |repo, config_file |
        ChildPullRequest.from_params(
          organization: repo.organization,
          repository: repo,
          source_branch: @pr.source_branch,
          target_branch: @pr.target_branch,
          parent_full_name: repo.name,
          parent_id: 0,
          removeable: true,
          config_file: config_file
        )
      end
      
      @pr.refresh_all_repos!(load_templates = true) # load all repos at once
    end

    return if @pr.done?

    @repos_in_organization = @pr.meta_config.projects.keys #takes all the repos from the .xml files from the meta repository(including the repos that you don't have access to)
  end

  # route: /view/:organization/:repository/find_all_sub_prs
  # params: organization, repository, source_branch, target_branch, pull_id, config_file, source_repo_full_name
  # description: queries a pr finding all pr child subPRs
  # return: render /views/merge_sub_repos.erb template with @pr.children
  def find_all_sub_prs
    @pr = MegaMergePullRequest.call(params)
    # PR exists but default.xml was not set
    if @pr.nil?
      pr = PullRequest.from_github_data(
        Repository.from_params(params)
                  .pull_request(params[:pull_id])
      )
      redirect_to("/create/#{pr.branch_slug}") && return
    end
 
    @pr.meta_config.find_includes

    # search for repos with same source branch name and add them
    found_repos = @pr.find_target_repositories(@pr.source_branch) 

    if @pr.children.empty?
      @pr.children = []
    end
    # append all child_pr to pr.children unless they are already a part of that pr
    found_repos.each do |repo, config_file |
      child_pr = ChildPullRequest.from_params(
        organization: repo.organization,
        repository: repo,
        source_branch: @pr.source_branch,
        target_branch: @pr.target_branch,
        parent_full_name: repo.name,
        parent_id: 0,
        removeable: true,
        config_file: config_file
      )
      @pr.children.append(child_pr) unless child_pr.status[:text].include? "This is already part of PR"
    end
    @pr.refresh_all_repos!(load_templates = true) # load all repos at once

    render partial: 'sub_repos', layout: false, locals: { children: @pr.children }
  end

  def save
    meta_pr = SaveMegaMergeState.call(@user, params[:meta_repo], params[:sub_repos])
    repo = meta_pr.repository
    redirect_to(view_pr_path(repo.organization, repo.repository, meta_pr.id))
  end

  def final_merge
    MergeMegaMerge.call(params[:organization], params[:repository], params[:pull_id])
    redirect_back(fallback_location: view_pr_path(params[:organization], params[:repository], params[:pull_id]))
  end

  def close_pr
    CloseMegaMerge.call(params[:organization], params[:repository], params[:pull_id])
    redirect_back(fallback_location: view_pr_path(params[:organization], params[:repository], params[:pull_id]))
  end

  def reopen_pr
    ReopenMegaMerge.call(params[:organization], params[:repository], params[:pull_id])
    redirect_back(fallback_location: view_pr_path(params[:organization], params[:repository], params[:pull_id]))
  end

  def r4r
    ReadyForReviewMegaMerge.call(params[:organization], params[:repository], params[:pull_id])
    redirect_back(fallback_location: view_pr_path(params[:organization], params[:repository], params[:pull_id]))
  end

  def delete_source_branches
    DeleteMegaMergeBranches.call(params[:organization], params[:repository], params[:pull_id])
    redirect_back(fallback_location: view_pr_path(params[:organization], params[:repository], params[:pull_id]))
  end
end
