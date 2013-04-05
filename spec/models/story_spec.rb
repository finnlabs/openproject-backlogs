require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Story do
  let(:user) { @user ||= FactoryGirl.create(:user) }
  let(:role) { @role ||= FactoryGirl.create(:role) }
  let(:issue_status1) { @status1 ||= FactoryGirl.create(:issue_status, :name => "status 1", :is_default => true) }
  let(:tracker_feature) { @tracker_feature ||= FactoryGirl.create(:tracker_feature) }
  let(:version) { @version ||= FactoryGirl.create(:version, :project => project) }
  let(:version2) { FactoryGirl.create(:version, :project => project) }
  let(:sprint) { @sprint ||= FactoryGirl.create(:sprint, :project => project) }
  let(:issue_priority) { @issue_priority ||= FactoryGirl.create(:priority) }
  let(:task_tracker) { FactoryGirl.create(:tracker_task) }
  let(:task) { FactoryGirl.create(:story, :fixed_version => version,
                                      :project => project,
                                      :status => issue_status1,
                                      :tracker => task_tracker,
                                      :priority => issue_priority) }
  let(:story1) { FactoryGirl.create(:story, :fixed_version => version,
                                        :project => project,
                                        :status => issue_status1,
                                        :tracker => tracker_feature,
                                        :priority => issue_priority) }

  let(:story2) { FactoryGirl.create(:story, :fixed_version => version,
                                        :project => project,
                                        :status => issue_status1,
                                        :tracker => tracker_feature,
                                        :priority => issue_priority) }

  let(:project) do
    unless @project
      @project = FactoryGirl.build(:project)
      @project.members = [FactoryGirl.build(:member, :principal => user,
                                                 :project => @project,
                                                 :roles => [role])]
    end
    @project
  end

  before(:each) do
    Setting.use_caching = false

    Setting.plugin_backlogs = {"points_burn_direction" => "down",
                               "wiki_template"         => "",
                               "card_spec"             => "Sattleford VM-5040",
                               "story_trackers"        => [tracker_feature.id.to_s],
                               "task_tracker"          => task_tracker.id.to_s }
  end

  describe "Class methods" do
    describe :backlogs do

      describe "WITH one sprint
                WITH the sprint having 1 story" do
        before(:each) do
          story1
        end

        it { Story.backlogs(project, [version.id])[version.id].should =~ [story1] }
      end

      describe "WITH two sprints
                WITH two stories
                WITH one story per sprint
                WITH querying for the two sprints" do

        before do
          version2
          story1
          story2.fixed_version_id = version2.id
          story2.save!
        end

        it { Story.backlogs(project, [version.id, version2.id])[version.id].should =~ [story1] }
        it { Story.backlogs(project, [version.id, version2.id])[version2.id].should =~ [story2] }
      end

      describe "WITH two sprints
                WITH two stories
                WITH one story per sprint
                WITH querying one sprints" do

        before do
          version2
          story1

          story2.fixed_version_id = version2.id
          story2.save!
        end

        it { Story.backlogs(project, [version.id])[version.id].should =~ [story1] }
        it { Story.backlogs(project, [version.id])[version2.id].should be_empty }
      end

      describe "WITH two sprints
                WITH two stories
                WITH one story per sprint
                WITH querying for the two sprints
                WITH one sprint beeing in another project" do

        before do
          story1

          other_project = FactoryGirl.create(:project)
          version2.project_id = other_project.id
          story2.fixed_version_id = version2.id
          story2.project = other_project
          story2.save!
        end

        it { Story.backlogs(project, [version.id, version2.id])[version.id].should =~ [story1] }
        it { Story.backlogs(project, [version.id, version2.id])[version2.id].should be_empty }
      end

      describe "WITH one sprint
                WITH the sprint having one story in this project and one story in another project" do
        before(:each) do
          version.sharing = "system"
          version.save!

          another_project = FactoryGirl.create(:project)

          story1
          story2.project = another_project
          story2.save!
        end

        it { Story.backlogs(project, [version.id])[version.id].should =~ [story1] }
      end

      describe "WITH one sprint
                WITH the sprint having two storys
                WITH one beeing the child of the other" do

        before(:each) do
          story1.parent_issue_id = story2.id

          story1.save
        end

        it { Story.backlogs(project, [version.id])[version.id].should =~ [story1, story2] }
      end

      describe "WITH one sprint
                WITH the sprint having one story
                WITH the story having a child task" do

        before(:each) do
          task.parent_issue_id = story1.id

          task.save
        end

        it { Story.backlogs(project, [version.id])[version.id].should =~ [story1] }
      end

      describe "WITH one sprint
                WITH the sprint having one story and one task
                WITH the two having no connection" do

        before(:each) do
          task
          story1
        end

        it { Story.backlogs(project, [version.id])[version.id].should =~ [story1] }
      end
    end
  end

  describe "journals created after adding a subtask to a story" do
    before(:each) do
      @current = FactoryGirl.create(:user, :login => "user1", :mail => "user1@users.com")
      User.stub!(:current).and_return(@current)

      @story = FactoryGirl.create(:story, :fixed_version => version,
                                       :project => project,
                                       :status => issue_status1,
                                       :tracker => tracker_feature,
                                       :priority => issue_priority)

      @issue ||= FactoryGirl.create(:issue, :project => project, :status => issue_status1, :tracker => tracker_feature, :author => @current)
    end

    it "should create a journal when adding a subtask which has remaining hours set" do
      @issue.remaining_hours = 15.0
      @issue.parent_issue_id = @story.id
      @issue.save!

      @story.journals.last["changes"]["remaining_hours"].should == [nil, 15]
    end

    it "should not create an empty journal when adding a subtask without remaining hours set" do
      @issue.parent_issue_id  = @story.id
      @issue.save!

      @story.journals.last["changes"]["remaining_hours"].should be_nil
    end
  end
end
