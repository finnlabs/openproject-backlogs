OpenProject::Application.routes.draw do

  # Use rb/ as a URL 'namespace.' We're using a slightly different URL pattern
  # From Redmine so namespacing avoids any further problems down the line
  #scope "/rb" do
  scope "", as: "backlogs" do

    resources :issue_boxes,          :controller => :issue_boxes,         :only => [:show, :edit, :update]

    scope "projects/:project_id", as: 'project' do

      resources   :backlogs,         :controller => :rb_master_backlogs,  :only => :index

      resource    :server_variables, :controller => :rb_server_variables, :only => :show, :format => :js

      resources   :sprints,          :controller => :rb_sprints,          :only => :update do

        resource  :query,            :controller => :rb_queries,          :only => :show

        resource  :taskboard,        :controller => :rb_taskboards,       :only => :show

        resource  :wiki,             :controller => :rb_wikis,            :only => [:show, :edit]

        resource  :burndown_chart,   :controller => :rb_burndown_charts,  :only => :show

        resources :impediments,      :controller => :rb_impediments,      :only => [:create, :update]

        resources :tasks,            :controller => :rb_tasks,            :only => [:create, :update]

        resources :stories,          :controller => :rb_stories,          :only => [:index, :create, :update]

      end
    end
  end

  get  'projects/:project_id/versions/:id/edit' => 'version_settings#edit'
  post  'projects/:id/project_issue_statuses' => 'projects#project_issue_statuses'
  post 'projects/:id/rebuild_positions' => 'projects#rebuild_positions'
end
