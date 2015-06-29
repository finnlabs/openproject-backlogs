#-- copyright
# OpenProject Backlogs Plugin
#
# Copyright (C)2013-2014 the OpenProject Foundation (OPF)
# Copyright (C)2011 Stephan Eckardt, Tim Felgentreff, Marnen Laibow-Koser, Sandro Munda
# Copyright (C)2010-2011 friflaj
# Copyright (C)2010 Maxime Guilbot, Andrew Vit, Joakim Kolsjö, ibussieres, Daniel Passos, Jason Vasquez, jpic, Emiliano Heyns
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

class Impediment < Task
  extend OpenProject::Backlogs::Mixins::PreventIssueSti

  after_save :update_blocks_list

  validate :validate_blocks_list

  safe_attributes "blocks_ids",
                  :if => lambda {|impediment, user|
                            (impediment.new_record? && user.allowed_to?(:create_impediments, impediment.project)) ||
                            user.allowed_to?(:update_impediments, impediment.project)
                          }

  def self.find(*args)
    if args[1] && args[1][:conditions]
      if args[1][:conditions].is_a?(Hash)
        args[1][:conditions][:parent_id] = nil
        args[1][:conditions][:type_id] = self.type
      elsif args[1][:conditions].is_a?(Array)
        args[1][:conditions][0] += " AND parent_id is NULL AND type_id = #{self.type}"
      end
    else
      args << {:conditions => {:parent_id => nil, :type_id => self.type}}
    end

    super
  end

  def blocks_ids=(ids)
    @blocks_ids_list = [ids] if ids.is_a?(Integer)
    @blocks_ids_list = ids.split(/\D+/).map{|id| id.to_i} if ids.is_a?(String)
    @blocks_ids_list = ids.map {|id| id.to_i} if ids.is_a?(Array)
  end

  def blocks_ids
    @blocks_ids_list ||= relations_from.select{ |rel| rel.relation_type == Relation::TYPE_BLOCKS }.collect(&:to_id)
  end

  private

  def update_blocks_list
    relations_from = [] if relations_from.nil?
    remove_from_blocks_list
    add_to_blocks_list
  end

  def remove_from_blocks_list
    self.relations_from.delete(self.relations_from.select{|rel| rel.relation_type == Relation::TYPE_BLOCKS && !blocks_ids.include?(rel.to_id) })
  end

  def add_to_blocks_list
    currently_blocking = relations_from.select{|rel| rel.relation_type == Relation::TYPE_BLOCKS}.collect(&:to_id)

    (self.blocks_ids - currently_blocking).each{ |id|
      rel = Relation.new(:relation_type => Relation::TYPE_BLOCKS, :from => self)
      rel.to_id = id
      self.relations_from << rel
    }
  end

  def validate_blocks_list
    if blocks_ids.size == 0
      errors.add :blocks_ids, :must_block_at_least_one_work_package
    else
      work_packages = WorkPackage.find_all_by_id(blocks_ids)
      errors.add :blocks_ids, :can_only_contain_work_packages_of_current_sprint if work_packages.size == 0 || work_packages.any?{|i| i.fixed_version != self.fixed_version }
    end
  end
end
