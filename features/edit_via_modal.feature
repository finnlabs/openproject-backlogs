Feature: Edit issue via modal box

  Background:
    Given there is 1 project with:
        | name  | ecookbook |
    And I am working in project "ecookbook"
    And the project uses the following modules:
        | backlogs |
    And there is a role "scrum master"
    And the role "scrum master" may have the following rights:
        | view_master_backlog     |
        | view_taskboards         |
        | update_sprints          |
        | update_stories          |
        | create_impediments      |
        | update_impediments      |
        | update_tasks            |
        | view_wiki_pages         |
        | edit_wiki_pages         |
        | view_work_packages      |
        | edit_work_packages      |
        | manage_subtasks         |
    And the backlogs module is initialized
    And the following trackers are configured to track stories:
        | Story |
    And the tracker "Task" is configured to track tasks
    And the project uses the following trackers:
        | Story |
        | Task  |
    And there is a default issuestatus with:
        | name | new |
    And there is a default issuepriority with:
        | name   | Normal |
    And the tracker "Task" has the default workflow for the role "scrum master"
    And there is 1 user with:
        | login | markus |
        | firstname | Markus |
        | Lastname | Master |
    And the user "markus" is a "scrum master"
    And the project has the following sprints:
        | name       | start_date | effective_date  |
        | Sprint 001 | 2010-01-01        | 2010-01-31      |
    And the project has the following stories in the following sprints:
        | subject | sprint     |
        | Story A | Sprint 001 |
    And I am already logged in as "markus"

  @javascript
  Scenario: Edit issue via modal box
    When I go to the master backlog
    And I open the modal window for the story "Story A"
    And I switch the modal window into edit mode
    And fill in "Story A changed" for "issue_subject"
    And I follow "Save"
    And I go to the master backlog

    Then I should see "Story A changed"
