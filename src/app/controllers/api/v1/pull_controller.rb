# frozen_string_literal: true

require_dependency 'git_hub/bot'

module Api
  module V1
    class PullController < ApplicationController
      skip_before_action :require_login
      skip_before_action :verify_authenticity_token
      before_action :check_bearer

      rescue_from StandardError, with: :error_generic
      rescue_from Octokit::Error, with: :error_octokit
      rescue_from ActionController::ParameterMissing, with: :error_parameter

      # TODO: Add parameter validation

      def pull
        pr = Api::ParentPull.call(params[:organization], params[:repository], params[:number])
        return render json: { error: 'Not a megamerge pull request' }, status: :not_found if pr.nil?

        render json: PullRequestSerializer.from_pull_request(pr)
      end

      def create
        params = create_params

        pr = SaveMegaMergeState.call(
          user,
          params[:meta_repo],
          params[:sub_repos]
        )

        return render json: { message: 'Missing access rights' }, status: :unauthorized if pr.nil?
        
        # fix: additional load/API call, else wrong init values might taken for json
        pr_json = PullRequestSerializer.from_pull_request(pr).to_json
        pr = Api::ParentPull.call(params[:organization], params[:repository], JSON.parse(pr_json)['id'])
        render json: PullRequestSerializer.from_pull_request(pr)
      end
      
      def update_config_file
        begin
          # use API to trigger config file update procedure.
          # Check if the requested MM PR is updated with the latest hashes and optionally do the update if needed
          meta_pr_slug = params[:organization]+'/'+params[:repository]+'/'+params[:number]
          logger.info "checking #{meta_pr_slug} because its was triggered by API call"
          meta_pr = MetaPullRequest.load(params[:organization], params[:repository], params[:number])

          if meta_pr.config_outdated?
            commit_hash = meta_pr.update_config_file!
            update_status = commit_hash.nil? ? "ERROR" : "OK" # if commit failed error, else ok
            logger.info "updating #{meta_pr.slug} to #{commit_hash}"  # log new hash
          else
            update_status = 'OK'
          end

          return render json: { 'result': update_status }
        # Rescues any error, an puts the exception object in `e`
        rescue => e
          if e.message.include? "rate limit"  # e.class == Octokit::Forbidden error
            render json: { result: "RATELIMIT", details: "MegaMerge got too many API calls at once" }
          else
            render json:{ result: "ERROR", details: e.message }
          end

        end
      end

      def check_summary
        # Check and return the following:
        # Dismiss stale pull request approvals (check on meta repo target branch): Disabled => OK
        # Restrict who can push matching branches (check on meta and sub repositories): Disabled => OK
        # MM access to repositories: MM has access to all repositories!
        # {
        # 	"dismiss_stale_pr": "OK",
        # 	"restricted_push": "OK",
        # 	"repo_access": "OK"
        # }

        checks= SettingsController.new
        checks.checks_pullreq_from_params(params[:repository], params[:organization], params[:number])

        if ((checks.stale_pull_req) && (checks.stale_pull_req==true))
          stale = "NOK" # Enabled => NOK!
        else
          stale = "OK" # Disabled => OK
        end

        if (checks.restrict_push.empty?)
          push = "OK" # Disabled => OK
        else
          push = "NOK!" # Enabled => NOK
        end

        if !(checks.repos_missing_mm.empty?)
          access = "NOK, Missing:  #{checks.repos_missing_mm}"
        else
          if checks.pr_problems
            access = "NOK, Problem with Repo access, Repositories where MM has access: #{checks.repos_bot.join(", ")}"
          else
            access = "OK"
          end
        end

        return render json: { dismiss_stale_pr: stale, restricted_push: push,  repo_access: access}

      end

      def check_rate_limit
        @rep = params[:repository]
        @org = params[:organization]
        @prid = params[:pull_id]

        def  gql_ratelimit_query
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
        
        # API rate limit for bot client
        @bot_client ||= GitHub::Bot.from_organization(@org)
        @rate_limit_bot ||=@bot_client.rate_limit()
        @rate_limit_remaining_bot ||=@bot_client.rate_limit.remaining().to_json

        # API rate limit for current user
        @rate_limit_user ||=@user.rate_limit()
        @rate_limit_remaining_user ||=@user.rate_limit.remaining().to_json

        #GraphQL limit for current user
        _gql_ratelimit_query = gql_ratelimit_query()
        GitHub::GQL.add("#{@org}/#{@rep}", GitHub::GQL.QUERY, _gql_ratelimit_query)
        @gql_response = GitHub::GQL.execute

        #GraphQl limit for bot client
        if (@bot_client.last_response)
          @gql_rate_bot = @bot_client.last_response.data[:resources][:graphql]
        end

        return render json:{ User_Rate_Limit_Remaining: @rate_limit_remaining_user, GQL_User_Rate_Limit_Remaining: @gql_response, Bot_Rate_Limit_Remaining: @rate_limit_remaining_bot, GQL_Bot_Rate_Limit_Remaining: @gql_rate_bot }

      end

      def commit_message
        pr = Api::ParentPull.call(params[:organization], params[:repository], params[:number])
        return render json: { error: 'Not a megamerge pull request' }, status: :not_found if pr.nil?

        pr.merge_commit_message = commit_message_params

        with_flock(pr.slug) do
          pr.write_own_state!
        end

        render json: PullRequestSerializer.from_pull_request(pr)
      end

      def ready_for_review
        meta_pr = MetaPullRequest.load(params[:organization], params[:repository], params[:number])
        meta_pr.set_draft_state!(false)
        meta_pr.update_config_file!

        return render json:{ Draft: false }
      end

      private

      def user
        @user ||= GitHub::User.new(bearer_token)
      end

      def commit_message_params
        params.require(:message)
      end

      def create_params
        params[:meta_repo] = meta_repo_params.to_enum.to_h
        params[:sub_repos] = sub_repos_params[:sub_repos]

        params
      end

      def meta_repo_params
        meta_params =
          params
          .require(:meta_repo)
          .permit(:source_branch, :target_branch, :title, :body, :config_file, :merge_commit_message)
          .tap do |meta_repo_params|
            meta_repo_params.require(%i[source_branch target_branch title config_file])
          end

        meta_params[:organization] = params[:organization]
        meta_params[:repository] = params[:repository]

        meta_params
      end

      def sub_repos_params
        params[:sub_repos] ||= []
        params.permit(sub_repos: %i[organization repository source_branch target_branch config_file])
      end

      def check_bearer
        if bearer_token
          RequestStore.store[:client] = user.client
        else
          render json: { error: 'Missing bearer token', status: :unauthorized }
        end
      end

      def bearer_token
        return @bearer_token if @bearer_token

        pattern = /^Bearer /
        header = request.headers['Authorization']
        @bearer_token ||= header.gsub(pattern, '') if header&.match(pattern)
      end

      def error_generic(err)
        render json: { message: err }, status: :internal_server_error
      end

      def error_octokit(err)
        render json: err.response_body, status: err.response_status
      end

      def error_parameter(err)
        render json: { message: err }, status: :bad_request
      end
    end
  end
end
