class Impediment < Task
  unloadable

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
        args[1][:conditions][:tracker_id] = self.tracker
      elsif args[1][:conditions].is_a?(Array)
        args[1][:conditions][0] += " AND parent_id is NULL AND tracker_id = #{self.tracker}"
      end
    else
      args << {:conditions => {:parent_id => nil, :tracker_id => self.tracker}}
    end

    super
  end

  def blocks_ids=(ids)
    @blocks_ids_list = [ids] if ids.is_a?(Integer)
    @blocks_ids_list = ids.split(/\D+/).map{|id| id.to_i} if ids.is_a?(String)
    @blocks_ids_list = ids.map {|id| id.to_i} if ids.is_a?(Array)
  end

  def blocks_ids
    @blocks_ids_list ||= relations_from.select{ |rel| rel.relation_type == IssueRelation::TYPE_BLOCKS }.collect(&:issue_to_id)
  end

  private

  def update_blocks_list
    relations_from = [] if relations_from.nil?
    remove_from_blocks_list
    add_to_blocks_list
  end

  def remove_from_blocks_list
    self.relations_from.delete(self.relations_from.select{|rel| rel.relation_type == IssueRelation::TYPE_BLOCKS && !blocks_ids.include?(rel.issue_to_id) })
  end

  def add_to_blocks_list
    currently_blocking = relations_from.select{|rel| rel.relation_type == IssueRelation::TYPE_BLOCKS}.collect(&:issue_to_id)

    (self.blocks_ids - currently_blocking).each{ |id|
      rel = IssueRelation.new(:relation_type => IssueRelation::TYPE_BLOCKS, :issue_from => self)
      rel.issue_to_id = id #attr_protected
      self.relations_from << rel
    }
  end

  def validate_blocks_list
    if blocks_ids.size == 0
      errors.add :blocks_ids, :must_block_at_least_one_issue
    else
      issues = Issue.find_all_by_id(blocks_ids)
      errors.add :blocks_ids, :can_only_contain_issues_of_current_sprint if issues.size == 0 || issues.any?{|i| i.fixed_version != self.fixed_version }
    end
  end
end
