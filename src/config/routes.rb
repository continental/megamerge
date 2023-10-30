# frozen_string_literal: true

Rails.application.routes.draw do
  root 'session#index'

  get    '/',       to: 'session#index'
  get    '/logout', to: 'session#logout'
  get    '/oauth',  to: 'session#oauth'
  get    '/oauth/*redirect',  to: 'session#oauth'
  get    '/healthcheck', to: proc { [200, {}, ['ok']] }, as: 'health-check'

  scope '/', constraints: { organization: /[\w\.\-]+/, repository: /[\w\.\-]+/ } do
    scope 'create',
          constraints: {
            source_branch: /[\w\.\-\%]+/,
            target_branch: /[\w\.\-\%]+/,
            config_file: /[\w\.\-]+/
          },
          format: false do
      get  '/',                                                                     to: 'merge#step3',          as: 'step1'
      get  '/:organization',                                                        to: 'merge#step3',          as: 'step2'
      get  '/:organization/:repository',                                            to: 'merge#step3',          as: 'step3'
      get  '/:organization/:repository/:source_branch/:target_branch',              to: 'merge#step4',          as: 'step4'
      get  '/:organization/:repository/:source_branch/:target_branch/:config_file', to: 'merge#show',           as: 'final',       format: 'html'
    end

    scope 'view/:organization/:repository', format: false do
      get    '/',        to: 'merge#show_repository'
      get    '/find_all_sub_prs', to: 'merge#find_all_sub_prs'
      get    '/:pull_id', to: 'merge#show', constraints: { pull_id: /\d+/ }, as: 'view_pr'
    end

    scope 'check/:organization/:repository', format: false do
      get '/pull/:pull_id',  to: 'settings#checks_pullreq', constraints: { pull_id: /\d+/ }
    end

    scope 'do', constraints: { pull_id: /\d+/ }, format: false do
      post   '/save/:organization/:repository/',           to: 'merge#save'
      get    '/merge/:organization/:repository/:pull_id',  to: 'merge#final_merge'
      get    '/delete/:organization/:repository/:pull_id', to: 'merge#delete_source_branches'
      get    '/close/:organization/:repository/:pull_id',  to: 'merge#close_pr'
      get    '/reopen/:organization/:repository/:pull_id', to: 'merge#reopen_pr'
      get    '/r4r/:organization/:repository/:pull_id',    to: 'merge#r4r'
      get    '/search_subrepos',                           to: 'merge#search_subrepos'
    end

    scope 'api/v1/:organization/:repository' do
      get '/labels', to: 'label#labels'
      get '/:issue_num/labels', to: 'label#labels_for_issue'
      post '/:issue_num/labels', to: 'label#add_labels_to_issue'
      put '/:issue_num/labels', to: 'label#replace_all_labels'
      get '/rate_limit', to: 'api/v1/pull#check_rate_limit'

      scope 'pull' do
        get '/:number', to: 'api/v1/pull#pull'
        post '/', to: 'api/v1/pull#create'
        post '/:number/commit/message', to: 'api/v1/pull#commit_message'
        get '/:number/hash', to: 'api/v1/pull#update_config_file'
        get '/:number/ready_for_review', to: 'api/v1/pull#ready_for_review'
      end
    end
  end

  post '/webhook', to: 'webhook#event'
end
