require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Backlog do
  let(:project) { FactoryGirl.build(:project) }

  before(:each) do
    @feature = FactoryGirl.create(:tracker_feature)
    Setting.plugin_backlogs  = {"points_burn_direction" => "down",
                                "wiki_template"         => "",
                                "card_spec"             => "Sattleford VM-5040",
                                "story_trackers"        => [@feature.id.to_s],
                                "task_tracker"          => "0"}
    @status = FactoryGirl.create(:issue_status)
  end

  describe "Class Methods" do
    describe :owner_backlogs do
      describe "WITH one open version defined in the project" do
        before(:each) do
          @project = project
          @issues = [FactoryGirl.create(:issue, :subject => "issue1", :project => @project, :tracker => @feature, :status => @status)]
          @version = FactoryGirl.create(:version, :project => project, :fixed_issues => @issues)
          @version_settings = @version.version_settings.create(:display => VersionSetting::DISPLAY_RIGHT, :project => project)
        end

        it { Backlog.owner_backlogs(@project)[0].should be_owner_backlog }
      end
    end
  end

end
