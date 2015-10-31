#-- copyright
# OpenProject Backlogs Plugin
#
# Copyright (C)2013-2014 the OpenProject Foundation (OPF)
# Copyright (C)2011 Stephan Eckardt, Tim Felgentreff, Marnen Laibow-Koser, Sandro Munda
# Copyright (C)2010-2011 friflaj
# Copyright (C)2010 Maxime Guilbot, Andrew Vit, Joakim Kolsjö, ibussieres,
#                   Daniel Passos, Jason Vasquez, jpic, Emiliano Heyns
# Copyright (C)2009-2010 Mark Maglana
# Copyright (C)2009 Joe Heck, Nate Lowrie
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License version 3.
#
# OpenProject Backlogs is a derivative work based on ChiliProject Backlogs.
# The copyright follows:
# Copyright (C) 2010-2011 - Emiliano Heyns, Mark Maglana, friflaj
# Copyright (C) 2011 - Jens Ulferts, Gregor Schmidt - Finn GmbH - Berlin, Germany
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See doc/COPYRIGHT.rdoc for more details.
#++

require_dependency 'work_package'

module OpenProject::Backlogs::Patches::WorkPackagePatch
  def self.included(base)
    base.class_eval do
      include InstanceMethods
      extend ClassMethods

      alias_method_chain :recalculate_attributes_for, :remaining_hours
      before_validation :backlogs_before_validation, if: lambda { |i| i.backlogs_enabled? }

      before_save :inherit_version_from_closest_story_or_impediment, if: lambda { |i| i.is_task? }
      after_save :inherit_version_to_descendants, if: lambda { |i|
        i.fixed_version_id_changed? && i.backlogs_enabled? && i.closest_story_or_impediment == i
      }
      after_move :inherit_version_to_descendants, if: lambda { |i| i.is_task? }

      register_on_journal_formatter(:fraction, 'remaining_hours')
      register_on_journal_formatter(:decimal, 'story_points')
      register_on_journal_formatter(:decimal, 'position')

      validates_numericality_of :story_points, only_integer:             true,
                                               allow_nil:                true,
                                               greater_than_or_equal_to: 0,
                                               less_than:                10_000,
                                               if: lambda { |i| i.backlogs_enabled? }

      validates_numericality_of :remaining_hours, only_integer: false,
                                                  allow_nil: true,
                                                  greater_than_or_equal_to: 0,
                                                  if: lambda { |i|
                                                    i.project && i.project.module_enabled?('backlogs')
                                                  }

      validates_each :parent_id do |record, attr, value|
        validate_parent_work_package_relation(record, attr, value)
      end

      include OpenProject::Backlogs::List
    end
  end

  module ClassMethods
    def backlogs_types
      # Unfortunately, this is not cachable so the following line would be wrong
      # @backlogs_types ||= Story.types << Task.type
      # Caching like in the line above would prevent the types selected
      # for backlogs to be changed without restarting all app server.
      (Story.types << Task.type).compact
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

    def validate_parent_work_package_relation(work_package, parent_attr, value)
      parent = WorkPackage.find_by(id: value)
      if parent && parent_work_package_relationship_spanning_projects?(parent, work_package)
        work_package.errors.add(parent_attr,
                                :parent_child_relationship_across_projects,
                                work_package_name: work_package.subject,
                                parent_name: parent.subject)
      end
    end

    def parent_work_package_relationship_spanning_projects?(parent, child)
      child.is_task? && parent.in_backlogs_type? && parent.project_id != child.project_id
    end
  end

  module InstanceMethods
    def done?
      project.done_statuses.to_a.include?(status)
    end

    def to_story
      Story.find(id) if is_story?
    end

    def is_story?
      backlogs_enabled? && Story.types.include?(type_id)
    end

    def to_task
      Task.find(id) if is_task?
    end

    def is_task?
      backlogs_enabled? && (parent_id && type_id == Task.type && Task.type.present?)
    end

    def is_impediment?
      backlogs_enabled? && (parent_id.nil? && type_id == Task.type && Task.type.present?)
    end

    def types
      case
      when is_story?
        Story.types
      when is_task?
        Task.types
      else
        []
      end
    end

    def story
      if self.is_story?
        return Story.find(id)
      elsif self.is_task?
        # Make sure to get the closest ancestor that is a Story, i.e. the one with the highest lft
        # otherwise, the highest parent that is a Story is returned
        story_work_package = ancestors.find_by_type_id(Story.types, order: 'lft DESC')
        return Story.find(story_work_package.id) if story_work_package
      end
      nil
    end

    def blocks
      # return work_packages that I block that aren't closed
      return [] if closed?
      relations_from.map { |ir| ir.relation_type == 'blocks' && !ir.to.closed? ? ir.to : nil }.compact
    end

    def blockers
      # return work_packages that block me
      return [] if closed?
      relations_to.map { |ir| ir.relation_type == 'blocks' && !ir.from.closed? ? ir.from : nil }.compact
    end

    def recalculate_attributes_for_with_remaining_hours(work_package_id)
      if work_package_id.is_a? WorkPackage
        p = work_package_id
      else
        p = WorkPackage.find_by(id: work_package_id)
      end

      if p.present?
        if backlogs_enabled? &&
           p.left != (p.right + 1) # this node has children

          p.remaining_hours = p.leaves.sum(:remaining_hours).to_f
          p.remaining_hours = nil if p.remaining_hours == 0.0
        end

        recalculate_attributes_for_without_remaining_hours(p)
      end
    end

    def inherit_version_from(source)
      self.fixed_version_id = source.fixed_version_id if source && project_id == source.project_id
    end

    def backlogs_enabled?
      !!project.try(:module_enabled?, 'backlogs')
    end

    def in_backlogs_type?
      backlogs_enabled? && WorkPackage.backlogs_types.include?(type.try(:id))
    end

    # ancestors array similar to Module#ancestors
    # i.e. returns immediate ancestors first
    def ancestor_chain
      ancestors = []
      unless parent_id.nil?

        # Unfortunately the nested set is only build on save hence, the #parent
        # method is not always correct. Therefore we go to the parent the hard
        # way and use nested set from there
        real_parent = WorkPackage.find_by(id: parent_id)

        # Sort immediate ancestors first
        ancestors = [real_parent] + real_parent.ancestors.includes(project: :enabled_modules).order(:rgt)
      end
      ancestors
    end

    def closest_story_or_impediment
      return nil unless in_backlogs_type?
      return self if self.is_story? || self.is_impediment?
      closest = nil
      ancestor_chain.each do |i|
        # break if we found an element in our chain that is not relevant in backlogs
        break unless i.in_backlogs_type?
        if i.is_story? || i.is_impediment?
          closest = i
          break
        end
      end
      closest
    end

    private

    def backlogs_before_validation
      if type_id == Task.type
        self.estimated_hours = remaining_hours if estimated_hours.blank? && !remaining_hours.blank?
        self.remaining_hours = estimated_hours if remaining_hours.blank? && !estimated_hours.blank?
      end
    end

    def inherit_version_from_closest_story_or_impediment
      root = closest_story_or_impediment
      inherit_version_from(root) if root != self
    end

    def inherit_version_to_descendants
      if !WorkPackage.child_update_semaphore_taken?
        begin
          WorkPackage.take_child_update_semaphore

          descendant_tasks, stop_descendants = descendants.includes(project: :enabled_modules).partition(&:is_task?)
          descendant_tasks.reject! do |t| stop_descendants.any? { |s| s.left < t.left && s.right > t.right } end

          descendant_tasks.each do |task|
            task.inherit_version_from(self)
            task.save if task.changed?
          end
        ensure
          WorkPackage.place_child_update_semaphore
        end
      end
    end
  end
end

WorkPackage.send(:include, OpenProject::Backlogs::Patches::WorkPackagePatch)
