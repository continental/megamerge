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

class SettingsController < ApplicationController
  rescue_from StandardError, with: :handle_any_exception
  rescue_from Octokit::Error, with: :handle_octokit_exception 
  rescue_from Octokit::NotFound, with: :handle_octokit_notfound 


  def handle_octokit_exception(e)
    logger.error e.backtrace.to_s
    redirect_to step3_path, danger: e.message.split(' // ', 2).first
  end

  def handle_any_exception(e)
    logger.error e.message + "\n" + e.backtrace.join("\n")
    redirect_to step1_path, danger: 'An Exception has occured. Please contact the Megamerger Team' + '<br>' + e.message.split(' // ', 2).first
  end

  def handle_octokit_notfound(e)
    logger.error "Pull Request link is not valid or MM does not have access there!\n"+e.backtrace.to_s
    redirect_to step3_path, danger: "Pull Request link is not valid or MM does not have access there!\n"+e.message.split(' // ', 2).first
  end

  def  gql_ratelimit_query()
    "
    viewer {
      login
    }
    rateLimit {
      limit
      cost
      remaining
      resetAt
    }
    "
  end


  def check_repo_settings(repos_bot)
    _pr = Api::ParentPull.call(@orgg, @rep, @prid)
    @repos_missing_mm = Array.new
    if !((repos_bot) && (repos_bot.include? _pr.repository.name))
      @repos_missing_mm << _pr.repository.name
    end

    # get branch protection rules for target branch meta repo
    @branch_prot = _pr.repository.branch_protection(_pr.target_branch)

    @restrict_push = Array.new
    if (@branch_prot)
      if (@branch_prot[:required_pull_request_reviews])
        @stale_pull_req =  @branch_prot[:required_pull_request_reviews][:dismiss_stale_reviews]
      end
      if (@branch_prot[:restrictions])
        @restrict_push <<  _pr.repository.name
      end
    end

    #get branch protection rules for target branch sub repos
    @subBranchProt = Array.new
    begin
      _pr.children.map do |child|
        # if !child.repository.branch_protection(child.target_branch).nil?
        if (child.repository.branch_protection(child.target_branch))
          _temp = child.repository.branch_protection(child.target_branch)
          _temp[:name] = child.repository.name
          @subBranchProt <<  _temp
          if (_temp[:restrictions])
            @restrict_push << child.repository.name
          end
        end

        unless (repos_bot) && (repos_bot.include? child.repository.name) # fails if child is in different org
          child_org = child.repository.name.split('/')[0]
          unless (child_org == @orgg)
            tmp_bot, bot_client, rate_limit_bot, org_install_info = create_repo_bots(child_org)
            unless (tmp_bot) && (tmp_bot.include? child.repository.name)
              @repos_missing_mm << child.repository.name
            end
          else
            @repos_missing_mm << child.repository.name
          end
        end
      end
    rescue Octokit::NotFound => e
      @pr_problems = e.message
    rescue NoMethodError => e
      @pr_problems = e.message
    end

  end

  attr_accessor :stale_pull_req, :restrict_push, :repos_missing_mm, :pr_problems

  def create_repo_bots(orgg)
    # get repositories where MM has access in organization
    repos_bot ||= GitHub::Bot.organization_repos(orgg)
    #get MM installation info for the organization
    org_install_info ||= GitHub::App.new.find_organization_installation(orgg)

    # API rate limit for bot client
    bot_client ||= GitHub::Bot.from_organization(orgg)
    rate_limit_bot ||=bot_client.rate_limit()
    #@rate_limit_remaining_bot ||=@bot_client.rate_limit.remaining().to_json


    if (repos_bot)
      repos_bot = repos_bot.map { |repo|  "#{orgg}/" + repo }
      if (org_install_info)
        if (org_install_info[:repository_selection].eql? "selected")
          org_install_info[:repository_selection]=repos_bot.join(", ")
        end
      end
    end

    return repos_bot, bot_client, rate_limit_bot, org_install_info
  end

  attr_accessor :repos_bot

  # called by API pull_controller
  def checks_pullreq_from_params(rep, orgg, prid)
    @rep = rep
    @orgg = orgg
    @prid = prid

    repos_bot, bot_client, rate_limit_bot, org_install_info = self.create_repo_bots(orgg)
    self.check_repo_settings(repos_bot)
  end

  # called in GUI
  def checks_pullreq
    @rep = params[:repository]
    @orgg = params[:organization]
    @prid = params[:pull_id]

    @repos_bot, @bot_client, @rate_limit_bot, @org_install_info = self.create_repo_bots(@orgg)

    # API rate limit for current user
    @rate_limit_user ||=@user.rate_limit()
    #@rate_limit_remaining_user ||=@user.rate_limit.remaining().to_json

    #GraphQL limit for current user
    _gql_ratelimit_query = gql_ratelimit_query()
    GitHub::GQL.add("#{@orgg}/#{@rep}", GitHub::GQL.QUERY,_gql_ratelimit_query)
    @gql_response = GitHub::GQL.execute

    #GraphQl limit for bot client
    if (@bot_client.last_response)
      @gql_rate_bot = @bot_client.last_response.data[:resources][:graphql]
    end

    self.check_repo_settings(@repos_bot)

  end
    
end
