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

class MetaPullRequest
  module MetaActions
    MEGAMERGE_COMMIT_PREFIX = '[Megamerge]'
    MEGAMERGE_TEMP_BRANCH_PREFIX = 'refs/mm/'
    DEFAULT_BRANCH_PREFIX = 'refs/heads/'

    def create!
      return id if id?

      logger.info "creating pull request in #{repository.name} (draft: #{draft?})"
      description = self.body
      temp_body = MegaMerge::ParentEncoder.encode(self)
      merge_instance!(repository.create_pull_request(target_branch, source_branch, title, temp_body, draft?))
      self.body = description
      # save body state in description otherwise after create the header in the description will be shown twice
      id
    end

    def create_branch!
      return if id? # if pr exists already we dont have to create the branch...

      repository.create_branch!(source_branch, target_branch) unless source_branch_exists?
      @source_branch_exists = true
    end

    def refresh!
      new_meta = MetaPullRequest.load(repository.organization, repository.repository, id)
      merge_instance!(new_meta)
      #fill_from_decoded!(MegaMerge::ParentDecoder.decode(body))
      self
    end

    def refresh_all_repos!(load_templates = false)
      GitHub::GQL.add(repository.name, GitHub::GQL.QUERY, Repository.create_gql_query(repository.organization, repository.repository, load_templates), repository )
      children.each { |child| 
        #logger.info "lazy loading: #{child.to_json}"
        repo = child.repository
        GitHub::GQL.add(repo.name, GitHub::GQL.QUERY, Repository.create_gql_query(repo.organization, repo.repository, load_templates), repo )
      }

      GitHub::GQL.execute    
    end

    def merge!
      #repository.merge_pr!(id, message: merge_commit_message || title, squash: squash?)
      GitHub::GQL.add(repository.name, GitHub::GQL.MUTATION, create_gql_merge_mutation)
      GitHub::GQL.execute(true)
      #logger.info "merge mut: #{mutation}"
    end

    def close_stale_children!(new_children)
      children.map do |child|
        new_pr = new_children.find { |new_child| child.repository == new_child.repository }
        next unless child.stale?(new_pr)

        child.close!
        child.delete_temp_branches!
        child.repository.organization + '/' + child.repository.repository
      end.compact
    end

    def create_children!
      children.each { |child| child.create!(child.title || title, draft?) }
    end

    def refresh_children!
      return if @children.nil? # childs were not loaded yet anyway
      @children_lazy_load = children.map { |child| {:name => child.repository.name, 
                                                    :id => child.id,
                                                    :config_file => child.config_file,
                                                    :merge_method => child.merge_method } }
      @children = nil 
      #children.map(&:refresh!)
    end

    def merge_children!
      batch_size = 5   # how many repos are allowed to be merged in one GQL request
      children.each_with_index  do |child, i|
        GitHub::GQL.add(child.repository.name, GitHub::GQL.MUTATION, child.create_gql_merge_mutation)
        GitHub::GQL.execute if (i % batch_size) == 0
      end
      #logger.info "merge mut: #{mutation}"
      GitHub::GQL.execute
    end

    # GQL disabled as it can not create refs/mm/* branches right now
   # def create_temp_branches!(meta_config)
   #   logger.info 'creating temp branches'
#
   #   mutation = (
   #     children.collect { |child| 
   #       if !child.closed? && !child.merge_commit_sha.nil?
   #         child.repository.create_gql_update_branches([MEGAMERGE_TEMP_BRANCH_PREFIX + child.id.to_s + '/' + child.merge_commit_sha[0..7]], child.merge_commit_sha)
   #       
   #       end
   #     }
   #   ).join
   #   logger.info "create temp: #{mutation}"
   #   repository.gql_mutation mutation
#
   # end


    def create_temp_branches!(meta_config)
      logger.info 'creating temp branches'
      changed_children = []
      meta_config.updated_projects.map { |name, _project|
        children.each {|child|
          changed_children.push child if child.full_identifier.eql?(_project.key)
        }
      }
      changed_children.each do |cc|
        if !cc.merge_commit_sha.nil? && !cc.closed? && cc.merge_commit_sha != cc.source_branch  # if sha == ref then we dont have a sha at all
          Repository.from_name(cc.repository.name)
                    .create_ref!('mm/' + cc.id.to_s + '/' + cc.merge_commit_sha[0..7], cc.merge_commit_sha)
        end
      end
    end

    def update_config_file!(finalmerge = false)
      (logger.info "update_config_file: no childs to update #{children.inspect}"; return) if children.count == 0
      commit_to_base_on =
        if id? && can_rebase_source_branch?
          repository.commit(target_branch)
        else
          id? ? latest_user_commit : repository.commit(source_branch)
        end

      logger.info "config changes based on #{commit_to_base_on[:sha]}, affected: #{affected_config_files.inspect}"

      if finalmerge
        begin
          tries ||= 10
          logger.info "Waiting for children to be merged..."
          children.each do |child|
            if !child.merged?
              #check if child is merged inbetween
              logger.info "   #{child.slug}: Merged: #{child.merged?}"
              child.refresh!
            end
          end   
          raise unless children.all? { |child| child.merged? }
        rescue
          sleep(1)
          retry unless (tries -= 1).zero?
          logger.info "NOT ALL CHILDREN MERGED!" 
        end
      end

      children.each do |child|
        logger.info "#{child.slug}: #{child.merged?} #{child.merge_commit_sha} #{child.mergeable_state}"
      end

      meta_config.update!(children, self)

      # only continue if children outdated, pr is new, or there is a merge conflict and we can reset
      return unless meta_config.dirty? || children_removed? || can_rebase_source_branch? && dirty? #repository.pull_request(id)[:mergeable_state] == "dirty"
      

      logger.info "adding new commit to #{repository.name}/#{id}, can rebase: #{can_rebase_source_branch?}"
      if finalmerge
        commit_message = "#{title}\n#{body}"
      else
        commit_message = "#{MetaPullRequest::MEGAMERGE_COMMIT_PREFIX} #{title} (updated config file)"
      end

      new_meta_config = MegaMerge::MetaRepository.create(affected_config_files, repository, commit_to_base_on[:sha])
      new_meta_config.update!(children, self)
      final_commit = new_meta_config.commit_changes(commit_to_base_on, source_branch, commit_message)

      create_temp_branches!(new_meta_config) unless finalmerge

      return final_commit
    end

    def write_own_state!
      content = MegaMerge::ParentEncoder.encode(self)
      update!(content: content)
    end

    def write_state!
      write_own_state!
      write_children_state!
    end

    def write_children_state!
      children.each do |child|
        decoded = MegaMerge::ChildDecoder.decode(child.body)
        child.body = decoded&.[](:body) || child.body
        content = MegaMerge::ChildEncoder.encode(child)
        child.update!(content: content, heading: title)
      end
    end

    def wait_for_commit(commit)
      7.times do |try|
        sleep(try)
        return if contains_commit?(commit)
        logger.info "Waiting for #{commit} to be in PR"
      end
      logger.info "MAJOR ERROR: commit still not in PR!!"
    end

    def try_merge!
      """
      Triggered by event handler
      checks several times if all merge conditions are met, if yes -> do the real mage
      the whole merge check needs to be repeated several times because github seems to respond
      with false status if busy (merge state == blocked)
      """
      
      # try to see if meta is mergeable
      3.times do |try_meta|
        logger.info "try merge of #{slug}"
        (logger.info "already merged"; return) if merged?
        (logger.info "automerge disabled"; return) unless automerge?
        (logger.info "missing reviews"; return) if (not reviews_done? and blocked?)
        
        if blocked? || state_unknown?
          logger.info "mergeable state #{mergeable_state}, retry ..."
          sleep(try_meta * 5)
          refresh!
          next
        end

        # try to see if childs are mergeable
        3.times do |try_childs|
          sleep(try_childs * 5)
          refresh_children!
          (logger.info "missing child reviews"; break) if (not children.all?(&:reviews_done?) and children.any?(&:blocked?))
          (logger.info "child blocked, retry ..."; next) if children.any?(&:blocked?)
          (logger.info "child state unkown, retry ..."; next) if children.any?{|child| child.state_unknown? && !child.merged?}
          (logger.info "Can not rebase one or multiple subs. Check your selected merge method"; break) if children.any?{|child| child.merge_method == "REBASE" && !child.rebaseable?}

          merge_state!
          return
        end
        logger.info "merge not possible!"
        logger.info "#{readable_mergeability}"
        add_merge_try_comment
        return
      end
    end

    def add_merge_try_comment
      comment = <<~TEXT
        <details>
          <summary>
          :x: Megamerge was unable to merge this Pull Request (see details) :x: 
          </summary>
          <br>
          #{readable_mergeability.gsub(/\n/, '<br />').html_safe}
        </details>
      TEXT
      
      repository.add_comment(id, comment)
    end

    def merge_state!
      """
      Triggered by event handler or directly by MergeMegaMerge class (merge button)
      merges the megamerge if possible
      """
      (logger.info 'not megamergeable';logger.info readable_mergeability; return) if !megamergeable?
      (logger.info 'children outdated'; return) if config_outdated?
      (logger.info 'config file inconsistent'; return) if config_inconsistent?
      raise "Can not rebase one or multiple subs. Check your selected merge method" if children.any?{|child| child.merge_method == "REBASE" && !child.rebaseable?}

      logger.info "beginning automerge of #{repository.name} #{id}"
      merge_children!
      latest_commit_before = repository.commit(source_branch).sha

      logger.info "reading checks from: #{latest_commit_before}"
      commit_statuses = PullRequest::PullRequestStatuses.from_github_data(repository.combined_status(latest_commit_before))

      latest_commit = update_config_file!(true) #final merge
      logger.info "latest commit on #{repository.name} #{id} is now #{latest_commit}" unless latest_commit.nil?

      wait_for_commit(latest_commit) unless latest_commit.nil? # this is required as we have to ensure that the commit is in the PR before we merge

      begin
        tries ||= 3
        logger.info "writing checks to: #{latest_commit}"
        commit_statuses.statuses.each { |status| status.create!(repository, latest_commit) } unless latest_commit.nil?
        #refresh! 
        merge!
      rescue Exception => e
        logger.info "error during finalmerge ... retry ... #{e.message.split(' // ',2).first}"
        sleep(1)
        retry unless (tries -= 1).zero?
        raise e
      end
    end

    def set_draft_state!(state)
      logger.info "setting draft state to #{state}"
      GitHub::GQL.add(repository.name, GitHub::GQL.MUTATION, create_gql_set_draft_state(state))
      children.each{ |child | GitHub::GQL.add(child.repository.name, GitHub::GQL.MUTATION, child.create_gql_set_draft_state(state)) }
      GitHub::GQL.execute
    end

    def close_state!
      close!
      children.each{ |child | GitHub::GQL.add(child.repository.name, GitHub::GQL.MUTATION, child.create_gql_close_mutation) }
      GitHub::GQL.execute
      delete_temp_branches!
    end

    def open_state!
      open!
      refresh!
      children.each{ |child | GitHub::GQL.add(child.repository.name, GitHub::GQL.MUTATION, child.create_gql_open_mutation) }
      GitHub::GQL.execute
    end

    def delete_temp_branches! 
      # GQL can not delete refs/mm/*, fallback to api V3
      children.each { |child| child.delete_temp_branches!}
      return

      #query = (children.collect{|child| child.repository.create_gql_list_refs(MEGAMERGE_TEMP_BRANCH_PREFIX + child.id.to_s + '/') }).join
      ##logger.info query
      ##resp = repository.gql_query query
      #return if resp.blank?
      #branches_to_delete = resp[:data].map{|repo| {repoId: repo.second.id, refs: repo.second.refs.nodes.map {|node| MEGAMERGE_TEMP_BRANCH_PREFIX + node[:name]}}}
      #logger.info "deleting temp branches: #{branches_to_delete.to_json}"
      #delete_mutation = branches_to_delete.collect{ |repo_and_branch| 
      #  Repository.create_gql_update_branches(repo_and_branch[:refs], "0000000000000000000000000000000000000000", repo_and_branch[:repoId])
      #}.join
      ##repository.gql_mutation delete_mutation

    end

    def delete_source_branches!
      return unless done?
      delete_temp_branches!


      children.each{ |child| child.delete_source_branch!}
      delete_source_branch!
      return 
      # GQL disabled due to github problems

      # childs
      children.each{ |child | GitHub::GQL.add(
        child.repository.name, 
        GitHub::GQL.MUTATION, 
        child.repository.create_gql_update_branches([DEFAULT_BRANCH_PREFIX + child.source_branch], "0000000000000000000000000000000000000000")
      )}
      # meta
      GitHub::GQL.add(
        repository.name, 
        GitHub::GQL.MUTATION, 
        repository.create_gql_update_branches([DEFAULT_BRANCH_PREFIX + source_branch], "0000000000000000000000000000000000000000")
      )

      GitHub::GQL.execute

    end

    def find_target_repositories(target_branch)
      # TODO can be optimized with GQL
      repos = meta_config.projects.map { |_, project| [Repository.new(organization: project.org, repository: project.name), project.config_file] }
      repos.select do |repo, _|
        begin
          repo.branches.any? { |branch| branch[:name].eql?(target_branch) }
          #rescue an NotFound error because of missing access rights to one of the repo
          rescue Octokit::NotFound
        end 
      end
    end

    def set_children_status!(status)
      # not possible in graphql right now
      logger.info "inheriting #{status.context} to children"
      children.each { |child| child.create_status!(status) }
    end
  end
end
