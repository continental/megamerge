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

require_dependency 'git_hub/bot'

# Responsible for all interactions with the repositories on GitHub itself.
# Acts as a proxy to the octokit Object. All actions defined by octokit can be
# called directly on the repository, but with the name ommitted
#   Example: octokit.pull_requests('org/repo') -> repository.pull_requests
#
# Some of the octokit actions have been overwritten. See repository/actions.rb for details.
#
# By default the repository will interact with github as the BotUser
class Repository < BaseModel
  # include ActiveModel::Serializers::JSON
  include Repository::GitHubUrlParser
  include Repository::Actions

  def self.from_params(params)
    new(
      organization: params[:organization],
      repository: params[:repository]
    )
  end

  def self.from_name(name)
    return if name.nil?

    org, repo = name.split('/')
    new(
      organization: org,
      repository: repo
    )
  end

  def self.from_github_data(data)
    org, repo = data[:full_name].split('/')
    new(
      organization: org,
      repository: repo,
      object_id: data[:node_id]
    )

  end

  def self.load(org, repo, load_templates = false)
    full_name = org + "/" + repo
    repoInstance = new()
    GitHub::GQL.add(full_name, GitHub::GQL.QUERY,  Repository.create_gql_query(org, repo, load_templates = true), repoInstance)
    GitHub::GQL.execute  
    repoInstance
  end

  def self.from_gql(data) 
    repo = new()
    repo.update_from_gql(data)
    repo
  end

  def update_from_gql(data) 
    org, repo = data[:nameWithOwner].split('/')
    
    @organization = org
    @repository = repo
    @forked_repos = data[:forks][:nodes].collect{|fork| {:full_name => fork[:nameWithOwner]}}
    @allow_squash_merge = data[:squashMergeAllowed]
    @allow_merge_commit = data[:mergeCommitAllowed]
    @allow_rebase_merge = data[:rebaseMergeAllowed]
    @pr_templates = data[:pullRequestTemplates]
    @object_id = data[:id]
  end

  attr_accessor :organization, :repository, :forked_repos, :allow_squash_merge, :object_id, :allow_merge_commit, :allow_rebase_merge
  attr_accessor :pr_templates
  alias owner organization

  validates! :organization, presence: true
  validates! :repository, presence: true

 # def self.name(organization, repository)
 #   "#{organization}/#{repository}"
 # end

  def ==(other)
    !other.nil? && other.organization == organization && other.repository == repository
  end

  def name
    "#{organization}/#{repository}"
  end

  def default_branch
    @default_branch ||= repo[:default_branch]
  end

  def default_template
    if @pr_templates.blank?
      ""
    else
      @pr_templates[0][:body]
    end
  end

  def forked_repos
    @forked_repos ||= forks
  end

  # branches gets called often. Caching this saves a lot of requests
  def branches
    @branches ||= client.branches(name)
  end

  def bot_client
    @bot_client ||= GitHub::Bot.from_organization(organization)
  end

  def allow_squash_merge
    return @allow_squash_merge unless @allow_squash_merge.nil?
    @allow_squash_merge ||= repo.allow_squash_merge
  end

  def allow_rebase_merge
    return @allow_rebase_merge unless @allow_rebase_merge.nil?
    @allow_rebase_merge ||= repo.allow_rebase_merge
  end

  def allow_merge_commit
    return @allow_merge_commit unless @allow_merge_commit.nil?
    @allow_merge_commit ||= repo.allow_merge_commit
  end

  def branch_protection(branch)
    @branch_protection ||= {}
    @branch_protection[branch] ||= bot_client.branch_protection(name, branch)
  end

  # disabled for now as no speedup is expected (also PRs should be raw github data as expected by the using code)
  #def pull_requests(state = 'all')
  #  request_string = create_gql_list_prs
  #  response = gql_query request_string
  #  
  #  #@prs = response[:data][:repository][:pullRequests][:nodes].map do |pr|
  #  #  PullRequest.from_gql(pr)
  #  #end
  #  #logger.info "data: #{@prs.first[:id].to_json}"
  #  @prs = response[:data][:repository][:pullRequests][:nodes]
  #  @prs.each{|pr| logger.info "data: #{pr[:number].to_json}"} 
  #  
  #  @prs
  #end


  def pull_requests_gql

    nodes = Rails.cache.fetch(
      "PRs_#{name}",
      expires_in: 15.minute
    ) do
      GitHub::GQL.add(name, GitHub::GQL.QUERY, create_gql_list_prs)
      response = GitHub::GQL.execute
      response[:repository][:pullRequests][:nodes]
    end

    nodes.map do |pr|
      PullRequest.from_gql(pr)
    end
  end


  def create_gql_list_prs(state = 'OPEN')
    query = 
      "repository(owner: \"#{organization}\", name: \"#{repository}\") {
        pullRequests(first: 100, states: #{state}, orderBy: {field: CREATED_AT, direction: DESC}) {
          nodes {
          " + PullRequest.gql_pr_fields + "
          }
        }
      }"
  end

  def create_gql_new_branch_mutation(name, baseRef) 
    hash = "h_" + SecureRandom.alphanumeric(10)
    "
    #{hash}: createRef(input: {
      name: \"#{name}\", 
      oid: \"#{baseRef}\",
      repositoryId: \"#{object_id}\"
    }) 
    {
      clientMutationId
    }
    "
  end

  def create_gql_update_branches(branches, newRef) 
    self.class.create_gql_update_branches(branches, newRef, object_id)
  end

  def self.create_gql_update_branches(branches, newRef, repo_object_id) 
    return "" if branches.empty?
    branch_mutation = (branches.collect{|branch|
      "
      {
        afterOid: \"#{newRef}\",
        name: \"#{branch}\", 
      }, 
      "
    }).join

    hash = "h_" + SecureRandom.alphanumeric(10)
    "
    #{hash}: updateRefs(input: 
      {
      refUpdates: 
      [
        #{branch_mutation}
      ]
        repositoryId: \"#{repo_object_id}\"
      }) {
      clientMutationId
    }
    "
  end

  def create_gql_delete_branch_mutation(object_id)
    hash = "h_" + SecureRandom.alphanumeric(10)
    "
    #{hash}: deleteRef(input: {refId: \"#{object_id}\"}) {
      clientMutationId
    }
    "
  end

  def self.create_gql_query(organization, repository, load_templates = false)
    #hash = "h_" + SecureRandom.alphanumeric(10)
    "
    repository(owner: \"#{organization}\", name: \"#{repository}\") {
      #{Repository.gql_query_params(load_templates)}
    }
    "
  end

  def self.gql_query_params(load_templates = false)
    templ = 
    "
    pullRequestTemplates {
      filename
			body
		}
    "

    "
    nameWithOwner
    id
    mergeCommitAllowed
    squashMergeAllowed
    rebaseMergeAllowed
    #{load_templates ? templ: ""}
    forks(first: 25) {
      totalCount
      nodes {
        nameWithOwner
      }
    }
    "
  end

  def create_gql_list_refs(prefix)
    hash = "h_" + SecureRandom.alphanumeric(10)
    "
    #{hash}: repository(owner: \"#{organization}\", name: \"#{repository}\") {
      id
      nameWithOwner
      refs (refPrefix:\"#{prefix}\", first:100) {
        nodes {name}
      }
    }
    "
  end

  def method_missing(mid, *args, &block)
    tries ||= 3
    if mid.to_s.eql? "post"
      opts =  {:headers => {Accept: "application/vnd.github.merge-info-preview+json, application/vnd.github.update-refs-preview+json"}}
      client.send :request, :post, args[0], args[1], opts
    elsif args.empty?
      client.send(mid, name, &block)
    else
      client.send(mid, name, *args, &block)
    end
  rescue Faraday::ConnectionFailed => e
    sleep(1)
    logger.info "connection failed to #{Rails.application.config.github[:server]}: #{e.message}"
    retry unless (tries -= 1).zero?
  end

  def respond_to_missing?(mid, priv = false)
    client.respond_to?(mid, priv)
  end

  def as_client(github_client)
    old_client = client
    @client = github_client
    res = yield(self)
    @client = old_client
    res
  end

  def client
    # botuser needs to be created per org
    if RequestStore.store[:is_webhook]
      @client = GitHub::Bot.from_organization(organization) 
    else
      @client ||= RequestStore.store[:client]
    end

  end
end
