# frozen_string_literal: true

Rails.application.routes.draw do
  root 'session#index'

  get    '/',       to: 'session#index'
  get    '/logout', to: 'session#logout'
  get    '/oauth',  to: 'session#oauth'

  scope '/', constraints: { organization: /[\w\.\-]+/, repository: /[\w\.\-]+/ } do
    scope 'create',
          constraints: {
            source_branch: /[\w\.\-\%]+/,
            target_branch: /[\w\.\-\%]+/,
            config_file: /[\w\.\-]+/
          },
          format: false do
      get  '/',                                                                     to: 'merge#step1',          as: 'step1'
      post '/',                                                                     to: 'merge#complete_step1', as: 'complete_step1'
      get  '/:organization',                                                        to: 'merge#step2',          as: 'step2'
      post '/:organization',                                                        to: 'merge#complete_step2', as: 'complete_step2'
      get  '/:organization/:repository',                                            to: 'merge#step3',          as: 'step3'
      get  '/:organization/:repository/:source_branch/:target_branch',              to: 'merge#step4',          as: 'step4'
      get  '/:organization/:repository/:source_branch/:target_branch/:config_file', to: 'merge#show',           as: 'final'
    end

    scope 'view/:organization/:repository', format: false do
      get    '/',        to: 'merge#show_repository'
      get    '/:pull_id', to: 'merge#show', constraints: { pull_id: /\d+/ }, as: 'view_pr'
    end

    scope 'do', constraints: { pull_id: /\d+/ }, format: false do
      post   '/save/:organization/:repository/',           to: 'merge#save'
      get    '/merge/:organization/:repository/:pull_id',  to: 'merge#final_merge'
      get    '/delete/:organization/:repository/:pull_id', to: 'merge#delete_source_branches'
      get    '/close/:organization/:repository/:pull_id',  to: 'merge#close_pr'
      get    '/reopen/:organization/:repository/:pull_id', to: 'merge#reopen_pr'
      get    '/search_subrepos',                           to: 'merge#search_subrepos'
      get    '/get_repositories/:organization',            to: 'merge#get_repositories'
    end

    # The concept for the mega merge forbids other tools from communcating with it directly.
    # Use github if possible
    # get 'api/v1/:organization/:repository/pull/:pull_id', to: 'api/v1/pull#get_pull'
  end

  post '/webhook', to: 'webhook#event'
end
