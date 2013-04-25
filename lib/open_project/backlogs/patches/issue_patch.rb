require_dependency 'issue'

module OpenProject::Backlogs::Patches::IssuePatch
  def self.included(base)
    base.class_eval do
      unloadable

      include InstanceMethods
      extend ClassMethods

      alias_method_chain :recalculate_attributes_for, :remaining_hours
      before_validation :backlogs_before_validation, :if => lambda {|i| i.project && i.project.module_enabled?("backlogs")}

      before_save :inherit_version_from_closest_story_or_impediment, :if => lambda {|i| i.is_task? }
      after_save  :inherit_version_to_descendants, :if => lambda {|i| (i.fixed_version_id_changed? && i.backlogs_enabled? && i.closest_story_or_impediment == i) }
      after_move  :inherit_version_to_descendants, :if => lambda {|i| (i.is_task?) }

      register_on_journal_formatter(:fraction, 'remaining_hours')
      register_on_journal_formatter(:decimal, 'story_points')
      register_on_journal_formatter(:decimal, 'position')

      validates_numericality_of :story_points, :only_integer             => true,
                                               :allow_nil                => true,
                                               :greater_than_or_equal_to => 0,
                                               :less_than                => 10_000,
                                               :if => lambda { |i| i.project && i.project.module_enabled?('backlogs') }

      validates_numericality_of :remaining_hours, :only_integer => false,
                                                  :allow_nil => true,
                                                  :greater_than_or_equal_to => 0,
                                                  :if => lambda { |i| i.project && i.project.module_enabled?('backlogs') }


      validates_each :parent_issue_id do |record, attr, value|
        validate_parent_issue_relation(record, attr, value)

        validate_children(record, attr, value) #not using validates_associated because the errors are not displayed nicely then
      end

      include OpenProject::Backlogs::List
    end
  end

  module ClassMethods
    def backlogs_trackers
      @backlogs_trackers ||= Story.trackers << Task.tracker
    end

    def take_child_update_semaphore
      @child_updates = true
    end

    def child_update_semaphore_taken?
      @child_updates
    end

    def place_child_update_semaphore
      @child_updates = false
    end

    private

    def validate_parent_issue_relation(issue, parent_attr, value)
      parent = Issue.find_by_id(value)
      if parent_issue_relationship_spanning_projects?(parent, issue)
        issue.errors.add(parent_attr,
                         :parent_child_relationship_across_projects,
                         :issue_name => issue.subject,
                         :parent_name => parent.subject)
      end
    end

    def parent_issue_relationship_spanning_projects?(parent, child)
      child.is_task? && parent.in_backlogs_tracker? && parent.project_id != child.project_id
    end

    def validate_children(issue, attr, value)
      if issue.in_backlogs_tracker?
        issue.children.each do |child|
          unless child.valid?
            child.errors.each do |key, value|
              issue.errors.add(:children, value)
            end
          end
        end
      end
    end
  end

  module InstanceMethods
    def done?
      self.project.issue_statuses.include?(self.status)
    end

    def to_story
      Story.find(id) if is_story?
    end

    def is_story?
      backlogs_enabled? and Story.trackers.include?(self.tracker_id)
    end

    def to_task
      Task.find(id) if is_task?
    end

    def is_task?
      backlogs_enabled? and (self.parent_issue_id && self.tracker_id == Task.tracker && Task.tracker.present?)
    end

    def is_impediment?
      backlogs_enabled? and (self.parent_issue_id.nil? && self.tracker_id == Task.tracker && Task.tracker.present?)
    end

    def trackers
      case
      when is_story?
        Story.trackers
      when is_task?
        Task.trackers
      else
        []
      end
    end

    def story
      if self.is_story?
        return Story.find(self.id)
      elsif self.is_task?
        # Make sure to get the closest ancestor that is a Story, i.e. the one with the highest lft
        # otherwise, the highest parent that is a Story is returned
        story_issue = self.ancestors.find_by_tracker_id(Story.trackers, :order => 'lft DESC')
        return Story.find(story_issue.id) if story_issue
      end
      nil
    end

    def blocks
      # return issues that I block that aren't closed
      return [] if closed?
      relations_from.collect {|ir| ir.relation_type == 'blocks' && !ir.issue_to.closed? ? ir.issue_to : nil}.compact
    end

    def blockers
      # return issues that block me
      return [] if closed?
      relations_to.collect {|ir| ir.relation_type == 'blocks' && !ir.issue_from.closed? ? ir.issue_from : nil}.compact
    end

    def recalculate_attributes_for_with_remaining_hours(issue_id)
      if issue_id.is_a? Issue
        p = issue_id
      else
        p = Issue.find_by_id(issue_id)
      end

      if p.present?
        if backlogs_enabled? &&
           p.left != (p.right + 1) # this node has children

          p.remaining_hours = p.leaves.sum(:remaining_hours).to_f
          p.remaining_hours = nil if p.remaining_hours  == 0.0
        end

        recalculate_attributes_for_without_remaining_hours(p)
      end
    end

    def inherit_version_from(source)
      self.fixed_version_id = source.fixed_version_id if source && self.project_id == source.project_id
    end

    def backlogs_enabled?
      self.project.try(:module_enabled?, "backlogs")
    end

    def in_backlogs_tracker?
      backlogs_enabled? and Issue.backlogs_trackers.include?(self.tracker.id)
    end

    def closest_story_or_impediment
      return nil unless in_backlogs_tracker?
      return self if self.is_story?

      root = self
      unless self.parent_issue_id.nil?

        real_parent = Issue.find_by_id(self.parent_issue_id)
        # Unfortunately the nested set is only build on save hence, the #parent
        # method is not always correct. Therefore we go to the parent the hard
        # way and use nested set from there
        ancestors = real_parent.ancestors.find_all_by_tracker_id(Issue.backlogs_trackers)
        ancestors ? ancestors << real_parent : [real_parent]

        root = ancestors.sort_by(&:right).find { |i| i.is_story? or i.is_impediment? }
      end

      root
    end

    private

    def backlogs_before_validation
      if self.tracker_id == Task.tracker
        self.estimated_hours = self.remaining_hours if self.estimated_hours.blank? && ! self.remaining_hours.blank?
        self.remaining_hours = self.estimated_hours if self.remaining_hours.blank? && ! self.estimated_hours.blank?
      end
    end

    def inherit_version_from_closest_story_or_impediment
      root = closest_story_or_impediment
      inherit_version_from(root) if root != self
    end

    def inherit_version_to_descendants
      if !Issue.child_update_semaphore_taken?
        begin
          Issue.take_child_update_semaphore

          # We overwrite the version of all leaf issues that are tasks. This
          # way, the fixed_version_id is propagated up by the
          # inherit_version_from_closest_story_or_impediment before_filter and
          # the update_parent_attributes after_filter
          stop_descendants, descendant_tasks = self.descendants.partition{|d| d.tracker_id != Task.tracker }
          descendant_tasks.reject!{ |t| stop_descendants.any? { |s| s.left < t.left && s.right > t.right } }

          descendant_tasks.each do |task|
            task.inherit_version_from(self)
            task.save! if task.changed?
          end
        ensure
          Issue.place_child_update_semaphore
        end
      end
    end
  end
end

Issue.send(:include, OpenProject::Backlogs::Patches::IssuePatch)
