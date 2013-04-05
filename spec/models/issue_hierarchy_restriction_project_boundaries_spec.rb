require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

def project_boundaries_spanning_issue_hierarchy_allowed?
  issue = Issue.new
  issue.project_id = 1
  parent_issue = Issue.new
  parent_issue.project_id = 2
  issue.instance_eval do
    @parent_issue = parent_issue
  end
  issue.valid?
  # using not so good check on validity
  issue.errors[:parent_issue_id] != "doesn't belong to the same project"
end

describe Issue, 'parent-child relationships between backlogs stories and backlogs tasks are prohibited if they span project boundaries' do
  let(:tracker_feature) { FactoryGirl.build(:tracker_feature) }
  let(:tracker_task) { FactoryGirl.build(:tracker_task) }
  let(:tracker_bug) { FactoryGirl.build(:tracker_bug) }
  let(:version1) { project.versions.first }
  let(:version2) { project.versions.last }
  let(:role) { FactoryGirl.build(:role) }
  let(:user) { FactoryGirl.build(:user) }
  let(:issue_priority) { FactoryGirl.build(:priority) }
  let(:issue_status) { FactoryGirl.build(:issue_status, :name => "status 1", :is_default => true) }

  let(:parent_project) do
    p = FactoryGirl.build(:project, :name => "parent_project",
                                :members => [FactoryGirl.build(:member,
                                                           :principal => user,
                                                           :roles => [role])],
                                :trackers => [tracker_feature, tracker_task, tracker_bug])

    p.versions << FactoryGirl.build(:version, :name => "Version1", :project => p)
    p.versions << FactoryGirl.build(:version, :name => "Version2", :project => p)

    p
  end

  let(:child_project) do
    p = FactoryGirl.build(:project, :name => "child_project",
                                :members => [FactoryGirl.build(:member,
                                                           :principal => user,
                                                           :roles => [role])],
                                :trackers => [tracker_feature, tracker_task, tracker_bug])

    p.versions << FactoryGirl.build(:version, :name => "Version1", :project => p)
    p.versions << FactoryGirl.build(:version, :name => "Version2", :project => p)

    p
  end

  let(:story) { FactoryGirl.build(:issue,
                              :subject => "Story",
                              :tracker => tracker_feature,
                              :status => issue_status,
                              :author => user,
                              :priority => issue_priority) }

  let(:story2) { FactoryGirl.build(:issue,
                               :subject => "Story2",
                               :tracker => tracker_feature,
                               :status => issue_status,
                               :author => user,
                               :priority => issue_priority) }

  let(:task) { FactoryGirl.build(:issue,
                             :subject => "Task",
                             :tracker => tracker_task,
                             :status => issue_status,
                             :author => user,
                             :priority => issue_priority) }

   let(:task2) { FactoryGirl.build(:issue,
                               :subject => "Task2",
                               :tracker => tracker_task,
                               :status => issue_status,
                               :author => user,
                               :priority => issue_priority) }

   let(:bug) { FactoryGirl.build(:issue,
                             :subject => "Bug",
                             :tracker => tracker_bug,
                             :status => issue_status,
                             :author => user,
                             :priority => issue_priority) }

   let(:bug2) { FactoryGirl.build(:issue,
                              :subject => "Bug2",
                              :tracker => tracker_bug,
                              :status => issue_status,
                              :author => user,
                              :priority => issue_priority) }

  before(:all) do
    @are_settings_cached = Setting.use_caching?
    Setting.use_caching = false
    Setting.cross_project_issue_relations = "1"
  end

  after(:all) do
    Setting.use_caching = @are_settings_cached
  end

  before(:each) do
    parent_project.save!
    child_project.save!

    Setting.plugin_backlogs = {"points_burn_direction" => "down",
                               "wiki_template"         => "",
                               "card_spec"             => "Sattleford VM-5040",
                               "story_trackers"        => [tracker_feature.id],
                               "task_tracker"          => tracker_task.id.to_s}

    # otherwise the tracker id's from the previous test are still active
    Issue.instance_variable_set(:@backlogs_trackers, nil)
  end

  if project_boundaries_spanning_issue_hierarchy_allowed?

  describe "WHEN creating the child" do

    shared_examples_for "restricted hierarchy on creation" do
      before(:each) do
        parent.project = parent_project
        parent.save

        child.parent_issue_id = parent.id
      end

      describe "WITH the child in a different project" do
        before(:each) do
          child.project = child_project
        end

        it { child.should_not be_valid }
      end

      describe "WITH the child in the same project" do
        before(:each) do
          child.project = parent_project
        end

        it { child.should be_valid }
      end
    end

    shared_examples_for "unrestricted hierarchy on creation" do
      before(:each) do
        parent.project = parent_project
        parent.save

        child.parent_issue_id = parent.id
      end

      describe "WITH the child in a different project" do
        before(:each) do
          child.project = child_project
        end

        it { child.should be_valid }
      end

      describe "WITH the child in the same project" do
        before(:each) do
          child.project = parent_project
        end

        it { child.should be_valid }
      end
    end

    describe "WITH backlogs enabled in both projects" do
      describe "WITH a story as parent" do
        let(:parent) { story }

        describe "WITH a task as child" do
          let(:child) { task2 }

          it_should_behave_like "restricted hierarchy on creation"
        end

        describe "WITH a non backlogs issue as child" do
          let(:child) { bug2 }

          it_should_behave_like "unrestricted hierarchy on creation"
        end

        describe "WITH a story as child" do
          let(:child) { story2 }

          it_should_behave_like "unrestricted hierarchy on creation"
        end
      end

      describe "WITH a task as parent (with or without parent does not matter)" do
        let(:parent) { task }

        describe "WITH a task as child" do
          let(:child) { task2 }

          it_should_behave_like "restricted hierarchy on creation"
        end

        describe "WITH a non backlogs issue as child" do
          let(:child) { bug2 }

          it_should_behave_like "unrestricted hierarchy on creation"
        end

        describe "WITH a story as child" do
          let(:child) { story2 }

          it_should_behave_like "unrestricted hierarchy on creation"
        end
      end

      describe "WITH a non backlogs issue as parent" do
        let(:parent) { bug }

        describe "WITH a task as child" do
          let(:child) { task2 }

          it_should_behave_like "unrestricted hierarchy on creation"
        end

        describe "WITH a non backlogs issue as child" do
          let(:child) { bug2 }

          it_should_behave_like "unrestricted hierarchy on creation"
        end

        describe "WITH a story as child" do
          let(:child) { story2 }

          it_should_behave_like "unrestricted hierarchy on creation"
        end
      end
    end
  end

  describe "WITH an existing child" do #this could happen when the project enables backlogs afterwards
    shared_examples_for "restricted hierarchy by enabling backlogs" do
      before(:each) do
        parent.project = parent_project
        parent.save

        child.parent_issue_id = parent.id
      end

      describe "WITH the child in a different project" do
        before(:each) do
          child_project.enabled_module_names = child_project.enabled_module_names.find_all{|n| n != "backlogs" }
          child_project.save!
          child.project = child_project
          child_project.reload
          child.save!
          child_project.enabled_module_names = child_project.enabled_module_names + ["backlogs"]
          child_project.save!
        end

        it { child.reload.should_not be_valid }
        it { parent.reload.should_not be_valid }
      end

      describe "WITH the child in the same project" do
        before(:each) do
          parent_project.enabled_module_names = parent_project.enabled_module_names.find_all{|n| n != "backlogs" }
          parent_project.save!
          parent_project.reload
          child.project = parent_project
          child.save!
          parent_project.enabled_module_names = parent_project.enabled_module_names + ["backlogs"]
          parent_project.save!
        end

        it { child.reload.should be_valid }
        it { parent.reload.should be_valid }
      end
    end

    shared_examples_for "unrestricted hierarchy even when enabling backlogs" do
      before(:each) do
        parent.project = parent_project
        parent.save

        child.parent_issue_id = parent.id
      end

      describe "WITH the child in a different project" do
        before(:each) do
          child_project.enabled_module_names = child_project.enabled_module_names.find_all{|n| n != "backlogs" }
          child_project.save!
          child.project = child_project
          child.save!
          child_project.enabled_module_names = child_project.enabled_module_names + ["backlogs"]
          child_project.save!
        end

        it { child.reload.should be_valid }
        it { parent.reload.should be_valid }
      end

      describe "WITH the child in the same project" do
        before(:each) do
          parent_project.enabled_module_names = parent_project.enabled_module_names.find_all{|n| n != "backlogs" }
          parent_project.save!
          child.project = parent_project
          child.save!
          parent_project.enabled_module_names = parent_project.enabled_module_names + ["backlogs"]
          parent_project.save!
        end

        it { child.reload.should be_valid }
        it { parent.reload.should be_valid }
      end
    end

    describe "WITH a story as parent" do
      let(:parent) { story }

      describe "WITH a task as child" do
        let(:child) { task2 }

        it_should_behave_like "restricted hierarchy by enabling backlogs"
      end

      describe "WITH a non backlogs issue as child" do
        let(:child) { bug2 }

        it_should_behave_like "unrestricted hierarchy even when enabling backlogs"
      end

      describe "WITH a story as child" do
        let(:child) { story2 }

        it_should_behave_like "unrestricted hierarchy even when enabling backlogs"
      end
    end

    describe "WITH a task as parent" do
      let(:parent) { task }

      describe "WITH a task as child" do
        let(:child) { task2 }

        it_should_behave_like "restricted hierarchy by enabling backlogs"
      end

      describe "WITH a non backlogs issue as child" do
        let(:child) { bug2 }

        it_should_behave_like "unrestricted hierarchy even when enabling backlogs"
      end

      describe "WITH a story as child" do
        let(:child) { story2 }

        it_should_behave_like "unrestricted hierarchy even when enabling backlogs"
      end
    end

    describe "WITH a non-backlogs-issue as parent" do
      let(:parent) { bug }

      describe "WITH a task as child" do
        let(:child) { task2 }

        it_should_behave_like "unrestricted hierarchy even when enabling backlogs"
      end

      describe "WITH a non backlogs issue as child" do
        let(:child) { bug2 }

        it_should_behave_like "unrestricted hierarchy even when enabling backlogs"
      end

      describe "WITH a story as child" do
        let(:child) { story2 }

        it_should_behave_like "unrestricted hierarchy even when enabling backlogs"
      end
    end
  end
end
end
