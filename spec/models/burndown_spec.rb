require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Burndown do
  def set_attribute_journalized(story, attribute, value, day)
    story.reload
    story.instance_variable_set(:@current_journal, nil)
    story.init_journal(user)
    story.send(attribute, value)
    story.current_journal.created_on = day
    story.save!

    # with aaj created_on is called created_at and current_journal changed - so
    # we're fixing things differently here
    if story.current_journal.respond_to? :created_at
      story.reload.current_journal.update_attribute(:created_at, day)
    end
  end

  let(:user) { @user ||= FactoryGirl.create(:user) }
  let(:role) { @role ||= FactoryGirl.create(:role) }
  let(:tracker_feature) { @tracker_feature ||= FactoryGirl.create(:tracker_feature) }
  let(:tracker_task) { @tracker_task ||= FactoryGirl.create(:tracker_task) }
  let(:issue_priority) { @issue_priority ||= FactoryGirl.create(:priority, :is_default => true) }
  let(:version) { @version ||= FactoryGirl.create(:version, :project => project) }
  let(:sprint) { @sprint ||= Sprint.find(version.id) }

  let(:project) do
    unless @project
      @project = FactoryGirl.build(:project)
      @project.members = [FactoryGirl.build(:member, :principal => user,
                                                 :project => @project,
                                                 :roles => [role])]
      @project.versions << version
    end
    @project
  end

  let(:issue_open) { @status1 ||= FactoryGirl.create(:issue_status, :name => "status 1", :is_default => true) }
  let(:issue_closed) { @status2 ||= FactoryGirl.create(:issue_status, :name => "status 2", :is_closed => true) }
  let(:issue_resolved) { @status3 ||= FactoryGirl.create(:issue_status, :name => "status 3", :is_closed => false) }

  before(:each) do
    Rails.cache.clear

    Setting.plugin_backlogs = {"points_burn_direction" => "down",
                               "wiki_template"         => "",
                               "card_spec"             => "Sattleford VM-5040",
                               "story_trackers"        => [tracker_feature.id.to_s],
                               "task_tracker"          => tracker_task.id.to_s }


    project.save!
  end

  describe "Sprint Burndown" do
    describe "WITH the today date fixed to April 4th, 2011 and having a 10 (working days) sprint" do
      before(:each) do
        Time.stub!(:now).and_return(Time.utc(2011,"apr",4,20,15,1))
        Date.stub!(:today).and_return(Date.civil(2011,04,04))
      end

      describe "WITH having a 10 (working days) sprint and beeing 5 (working) days into it" do
        before(:each) do
          version.start_date = Date.today - 7.days
          version.effective_date = Date.today + 6.days
          version.save!
        end

        describe "WITH 1 story assigned to the sprint" do
          before(:each) do
            @story = FactoryGirl.build(:story, :subject => "Story 1",
                                           :project => project,
                                           :fixed_version => version,
                                           :tracker => tracker_feature,
                                           :status => issue_open,
                                           :priority => issue_priority,
                                           :created_on => Date.today - (20).days,
                                           :updated_on => Date.today - (20).days)
          end

          describe "WITH the story having a time_remaining defined on creation" do
            before(:each) do
              @story.remaining_hours = 9
              @story.save!
            end

            describe "WITH updating time_remaining three days ago" do
              before(:each) do
                set_attribute_journalized @story, :remaining_hours=, 5, Time.now - 3.day

                @burndown = Burndown.new(sprint, project)
              end

              it { @burndown.remaining_hours.should eql [9.0, 9.0, 9.0, 9.0, 5.0, 5.0] }
              it { @burndown.remaining_hours.unit.should eql :hours }
              it { @burndown.days.should eql(sprint.days()) }
              it { @burndown.max[:hours].should eql 9.0 }
              it { @burndown.max[:points].should eql 0.0 }
              it { @burndown.remaining_hours_ideal.should eql [9.0, 8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0, 0.0] }
            end

            describe "WITH the story beeing moved out of the sprint within the sprint duration and also moved back in" do
              before(:each) do
                other_version = FactoryGirl.create(:version, :name => "other_version", :project => project)
                project.instance_eval { reload; @shared_versions = nil } # Invalidate cached attributes
                @story.instance_eval { reload; @assignable_versions = nil }
                set_attribute_journalized @story, :fixed_version_id=, other_version.id, Time.now - 6.day
                set_attribute_journalized @story, :fixed_version_id=, version.id, Time.now - 3.day

                @burndown = Burndown.new(sprint, project)
              end

              it { @burndown.remaining_hours.should eql [9.0, 0.0, 0.0, 0.0, 9.0, 9.0] }
              it { @burndown.remaining_hours.unit.should eql :hours }
              it { @burndown.days.should eql(sprint.days()) }
              it { @burndown.max[:hours].should eql 9.0 }
              it { @burndown.max[:points].should eql 0.0 }
              it { @burndown.remaining_hours_ideal.should eql [9.0, 8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0, 0.0] }
            end

            describe "WITH the story beeing moved out of the project within the sprint duration and also moved back in" do
              before(:each) do
                other_project = FactoryGirl.create(:project, :name => "other_project")
                set_attribute_journalized @story, :project_id=, other_project.id, Time.now - 6.day
                set_attribute_journalized @story, :project_id=, project.id, Time.now - 3.day

                @burndown = Burndown.new(sprint, project)
              end

              it { @burndown.remaining_hours.should eql [9.0, 0.0, 0.0, 0.0, 9.0, 9.0] }
              it { @burndown.remaining_hours.unit.should eql :hours }
              it { @burndown.days.should eql(sprint.days()) }
              it { @burndown.max[:hours].should eql 9.0 }
              it { @burndown.max[:points].should eql 0.0 }
              it { @burndown.remaining_hours_ideal.should eql [9.0, 8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0, 0.0] }
            end

            describe "WITH the story beeing moved to another tracker within the sprint duration and also moved back in" do
              before(:each) do
                other_tracker = FactoryGirl.create(:tracker_bug)
                project.trackers << other_tracker

                set_attribute_journalized @story, :tracker_id=, other_tracker.id, Time.now - 6.day
                set_attribute_journalized @story, :tracker_id=, tracker_feature.id, Time.now - 3.day

                @burndown = Burndown.new(sprint, project)
              end

              it { @burndown.remaining_hours.should eql [9.0, 0.0, 0.0, 0.0, 9.0, 9.0] }
              it { @burndown.remaining_hours.unit.should eql :hours }
              it { @burndown.days.should eql(sprint.days()) }
              it { @burndown.max[:hours].should eql 9.0 }
              it { @burndown.max[:points].should eql 0.0 }
              it { @burndown.remaining_hours_ideal.should eql [9.0, 8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0, 0.0] }
            end
          end

          describe "WITH the story having a subticket that defines remaining hours" do
            before(:each) do
              @story.save!
              @task = FactoryGirl.build(:task, :subject => "Task 1",
                                           :project => project,
                                           :fixed_version => version,
                                           :tracker => tracker_task,
                                           :status => issue_open,
                                           :remaining_hours => 18,
                                           :parent_issue_id => @story.id,
                                           :priority => issue_priority,
                                           :created_on => Date.today - 20.days,
                                           :updated_on => Date.today - 20.days)
            end

            describe "WITH the subticket beeing created within the sprint" do
              before(:each) do
                @task.created_on = Time.now - 4.days
                @task.save!

                @burndown = Burndown.new(sprint, project)
              end

              it { @burndown.remaining_hours.should eql [0.0, 0.0, 0.0, 18.0, 18.0, 18.0] }
              it { @burndown.remaining_hours.unit.should eql :hours }
            end

            describe "WITH the subticket changing it's remaining hours within the sprint" do
              before(:each) do
                @task.save!

                set_attribute_journalized @task, :remaining_hours=, 10, Time.now - 3.day

                @burndown = Burndown.new(sprint, project)
              end

              it { @burndown.remaining_hours.should eql [18.0, 18.0, 18.0, 18.0, 10.0, 10.0] }
              it { @burndown.remaining_hours.unit.should eql :hours }
            end
          end

          describe "WITH the story having story_point defined on creation" do
            before(:each) do
              @story.story_points = 9
              @story.save!
            end

            describe "WITH the story beeing closed and opened again within the sprint duration" do
              before(:each) do
                set_attribute_journalized @story, :status_id=, issue_closed.id, Time.now - 6.day
                set_attribute_journalized @story, :status_id=, issue_open.id, Time.now - 3.day

                @burndown = Burndown.new(sprint, project)
              end

              it { @burndown.story_points.should eql [9.0, 0.0, 0.0, 0.0, 9.0, 9.0] }
              it { @burndown.story_points.unit.should eql :points }
              it { @burndown.days.should eql(sprint.days()) }
              it { @burndown.max[:hours].should eql 0.0 }
              it { @burndown.max[:points].should eql 9.0 }
              it { @burndown.story_points_ideal.should eql [9.0, 8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0, 0.0] }
            end

            describe "WITH the story marked as resolved and consequently 'done'" do
              before(:each) do
                set_attribute_journalized @story, :status_id=, issue_resolved.id, Time.now - 6.day
                set_attribute_journalized @story, :status_id=, issue_open.id, Time.now - 3.day
                project.issue_statuses << issue_resolved
                @burndown = Burndown.new(sprint, project)
              end

              it { @story.done?.should eql false }
              it { @burndown.story_points.should eql [9.0, 0.0, 0.0, 0.0, 9.0, 9.0] }
            end
          end
        end

        describe "WITH 10 stories assigned to the sprint" do
          before(:each) do
            @stories = []

            (0..9).each do |i|
              @stories[i] = FactoryGirl.create(:story, :subject => "Story #{i}",
                                                   :project => project,
                                                   :fixed_version => version,
                                                   :tracker => tracker_feature,
                                                   :status => issue_open,
                                                   :priority => issue_priority,
                                                   :created_on => Date.today - (20 - i).days,
                                                   :updated_on => Date.today - (20 - i).days)
            end
          end

          describe "WITH each story having a time remaining defined at start" do
            before(:each) do
              @remaining_hours_sum = 0

              @stories.each_with_index do |s, i|
                set_attribute_journalized s, :remaining_hours=, 10, version.start_date - 3.days
              end
            end

            describe "WITH 5 stories having been reduced to 0 hours remaining, one story per day" do
              before(:each) do
                @finished_hours
                (0..4).each do |i|
                  set_attribute_journalized @stories[i], :remaining_hours=, 0, version.start_date + i.days + 1.hour
                end
              end

              describe "THEN" do
                before(:each) do
                  @burndown = Burndown.new(sprint, project)
                end

                it { @burndown.remaining_hours.should eql [90.0, 80.0, 70.0, 60.0, 50.0, 50.0] }
                it { @burndown.remaining_hours.unit.should eql :hours }
                it { @burndown.days.should eql(sprint.days()) }
                it { @burndown.max[:hours].should eql 90.0 }
                it { @burndown.max[:points].should eql 0.0 }
                it { @burndown.remaining_hours_ideal.should eql [90.0, 80.0, 70.0, 60.0, 50.0, 40.0, 30.0, 20.0, 10.0, 0.0] }
              end
            end
          end

          describe "WITH each story having story points defined at start" do
            before(:each) do
              @remaining_hours_sum = 0

              @stories.each_with_index do |s, i|
                set_attribute_journalized s, :story_points=, 10, version.start_date - 3.days
              end
            end

            describe "WITH 5 stories having been reduced to 0 story points, one story per day" do
              before(:each) do
                @finished_hours
                (0..4).each do |i|
                  set_attribute_journalized @stories[i], :story_points=, nil, version.start_date + i.days + 1.hour
                end
              end

              describe "THEN" do
                before(:each) do
                  @burndown = Burndown.new(sprint, project)
                end

                it { @burndown.story_points.should eql [90.0, 80.0, 70.0, 60.0, 50.0, 50.0] }
                it { @burndown.story_points.unit.should eql :points }
                it { @burndown.days.should eql(sprint.days()) }
                it { @burndown.max[:hours].should eql 0.0 }
                it { @burndown.max[:points].should eql 90.0 }
                it { @burndown.story_points_ideal.should eql [90.0, 80.0, 70.0, 60.0, 50.0, 40.0, 30.0, 20.0, 10.0, 0.0] }
              end
            end
          end

        end
      end
    end
  end
end
