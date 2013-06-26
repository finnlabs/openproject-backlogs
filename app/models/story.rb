class Story < Issue
  unloadable

  extend OpenProject::Backlogs::Mixins::PreventIssueSti

  def self.backlogs(project_id, sprint_ids, options = {})

    options.reverse_merge!({ :order => Story::ORDER,
                             :conditions => Story.condition(project_id, sprint_ids) })

    candidates = Story.all(options)

    stories_by_version = Hash.new do |hash, sprint_id|
      hash[sprint_id] = []
    end

    candidates.each do |story|
      last_rank = stories_by_version[story.fixed_version_id].size > 0 ?
                     stories_by_version[story.fixed_version_id].last.rank :
                     0

      story.rank = last_rank + 1
      stories_by_version[story.fixed_version_id] << story
    end

    stories_by_version
  end

  def self.sprint_backlog(project, sprint, options={})
    Story.backlogs(project.id, [sprint.id], options)[sprint.id]
  end

  def self.create_and_position(params, safer_attributes)
    Story.new.tap do |s|
      s.author  = safer_attributes[:author]  if safer_attributes[:author]
      s.project = safer_attributes[:project] if safer_attributes[:project]
      s.safe_attributes = params

      if s.save
        s.move_after(params['prev_id'])
      end
    end
  end

  def self.at_rank(project_id, sprint_id, rank)
    return Story.find(:first,
                      :order => Story::ORDER,
                      :conditions => Story.condition(project_id, sprint_id),
                      :joins => :status,
                      :limit => 1,
                      :offset => rank - 1)
  end

  def self.trackers
    trackers = Setting.plugin_openproject_backlogs["story_trackers"]
    return [] if trackers.blank?

    trackers.map { |tracker| Integer(tracker) }
  end

  def tasks
    Task.tasks_for(self.id)
  end

  def tasks_and_subtasks
    return [] unless Task.tracker
    self.descendants.find_all_by_tracker_id(Task.tracker)
  end

  def direct_tasks_and_subtasks
    return [] unless Task.tracker
    self.children.find_all_by_tracker_id(Task.tracker).collect { |t| [t] + t.descendants }.flatten
  end

  def set_points(p)
    self.init_journal(User.current)

    if p.blank? || p == '-'
      self.update_attribute(:story_points, nil)
      return
    end

    if p.downcase == 's'
      self.update_attribute(:story_points, 0)
      return
    end

    p = Integer(p)
    if p >= 0
      self.update_attribute(:story_points, p)
      return
    end
  end

  # TODO: Refactor and add tests
  #
  # groups = tasks.partion(&:closed?)
  # {:open => tasks.last.size, :closed => tasks.first.size}
  #
  def task_status
    closed = 0
    open = 0

    self.tasks.each do |task|
      if task.closed?
        closed += 1
      else
        open += 1
      end
    end

    {:open => open, :closed => closed}
  end

  def update_and_position!(params)
    self.safe_attributes = params
    self.status_id = nil if params[:status_id] == ''

    save.tap do |result|
      if result and params[:prev]
        reload
        move_after(params[:prev])
      end
    end
  end

  def rank=(r)
    @rank = r
  end

  def rank
    if self.position.blank?
      extras = ["and ((#{Issue.table_name}.position is NULL and #{Issue.table_name}.id <= ?) or not #{Issue.table_name}.position is NULL)", self.id]
    else
      extras = ["and not #{Issue.table_name}.position is NULL and #{Issue.table_name}.position <= ?", self.position]
    end

    @rank ||= Issue.count(:conditions => Story.condition(self.project.id, self.fixed_version_id, extras), :joins => :status)

    return @rank
  end

  private

  def self.condition(project_id, sprint_ids, extras = [])
    c = ["project_id = ? AND tracker_id in (?) AND fixed_version_id in (?)",
         project_id, Story.trackers, sprint_ids]

    if extras.size > 0
      c[0] += ' ' + extras.shift
      c += extras
    end

    c
  end

  # This forces NULLS-LAST ordering
  ORDER = "CASE WHEN #{Issue.table_name}.position IS NULL THEN 1 ELSE 0 END ASC, CASE WHEN #{Issue.table_name}.position IS NULL THEN #{Issue.table_name}.id ELSE #{Issue.table_name}.position END ASC"
end
