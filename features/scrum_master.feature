Feature: Scrum Master
  As a scrum master
  I want to manage sprints and their stories
  So that they get done according the product owner´s requirements

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
        | view_issues             |
        | edit_issues             |
        | manage_subtasks         |
    And the backlogs module is initialized
    And the following trackers are configured to track stories:
        | Story |
    And the tracker "Task" is configured to track tasks
    And the project uses the following trackers:
        | Story |
        | Epic  |
        | Task  |
        | Bug   |
    And there are the following issue status:
        | name        | is_closed  | is_default  |
        | New         | false      | true        |
        | In Progress | false      | false       |
        | Resolved    | false      | false       |
        | Closed      | true       | false       |
        | Rejected    | true       | false       |
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
        | Sprint 002 | 2010-02-01        | 2010-02-28      |
        | Sprint 003 | 2010-03-01        | 2010-03-31      |
        | Sprint 004 | 2.weeks.ago       | 1.week.from_now |
        | Sprint 005 | 3.weeks.ago       | 2.weeks.from_now|
    And the project has the following product owner backlogs:
        | Product Backlog |
        | Wishlist        |
    And the project has the following stories in the following backlogs:
        | subject | backlog |
        | Story 1 | Product Backlog |
        | Story 2 | Product Backlog |
        | Story 3 | Product Backlog |
        | Story 4 | Product Backlog |
    And the project has the following stories in the following sprints:
        | subject | sprint     |
        | Story A | Sprint 001 |
        | Story B | Sprint 001 |
        | Story C | Sprint 002 |
    And the project has the following tasks:
        | subject      | sprint     | parent     |
        | Task 1       | Sprint 001 | Story A    |
    And the project has the following impediments:
        | subject      | sprint     | blocks     |
        | Impediment 1 | Sprint 001 | Story A    |
    And the project has the following issues:
        | subject      | sprint     | tracker    |
        | Epic 1       | Sprint 005 | Epic       |
    And the project has the following stories in the following sprints:
        | subject      | sprint     | parent     |
        | Story D      | Sprint 005 | Epic 1     |
        | Story E      | Sprint 005 | Epic 1     |
    And the project has the following tasks:
        | subject      | sprint     | parent     |
        | Task 10      | Sprint 005 | Story D    |
        | Task 11      | Sprint 005 | Story D    |
        | Subtask 1    | Sprint 005 | Task 10    |
        | Subtask 2    | Sprint 005 | Task 10    |
        | Subtask 3    | Sprint 005 | Task 11    |
    And the project has the following issues:
        | subject      | sprint     | parent     | tracker    |
        | Subfeature   | Sprint 005 | Task 10    | Bug        |
        | Subsubtask   | Sprint 005 | Subfeature | Task       |
    And I am already logged in as "markus"

  @javascript
  Scenario: View stories that have a parent ticket
   Given I am on the master backlog
    When I open the "Sprint 005" menu
    Then I should see 2 stories in "Sprint 005"
     And I should not see "Epic 1"
     And I should not see "Task 10"
     And I should not see "Subtask 1"
     And I should not see "Subfeature"

  @javascript
  Scenario: Create an impediment
    Given I am on the taskboard for "Sprint 001"
    When I click on the element with class "add_new" within "#impediments"
    And I fill in "Bad Company" for "subject"
    And I fill in the ids of the tasks "Task 1" for "blocks_ids"
    And I select "Markus Master" from "assigned_to_id"
    And I press "OK"
    Then I should see "Bad Company" within "#impediments"
    And the impediment "Bad Company" should signal successful saving

  @javascript
  Scenario: Create an impediment blocking an issue of another sprint
    Given I am on the taskboard for "Sprint 001"
    When I click on the element with class "add_new" within "#impediments"
    And I fill in "Bad Company" for "subject"
    And I fill in the ids of the stories "Story C" for "blocks_ids"
    And I select "Markus Master" from "assigned_to_id"
    And I press "OK"
    Then I should see "Bad Company" within "#impediments"
    And the impediment "Bad Company" should signal unsuccessful saving
    And the error alert should show "Blocks can only contain the IDs of current sprint's tickets"

  @javascript
  Scenario: Create an impediment blocking a non existent issue
    Given I am on the taskboard for "Sprint 001"
    When I click on the element with class "add_new" within "#impediments"
    And I fill in "Bad Company" for "subject"
    And I fill in "0" for "blocks_ids"
    And I select "Markus Master" from "assigned_to_id"
    And I press "OK"
    Then I should see "Bad Company" within "#impediments"
    And the impediment "Bad Company" should signal unsuccessful saving
    And the error alert should show "Blocks can only contain the IDs of current sprint's tickets"

  @javascript
  Scenario: Create an impediment without specifying what it blocks
    Given I am on the taskboard for "Sprint 001"
    When I click on the element with class "add_new" within "#impediments"
    And I fill in "Bad Company" for "subject"
    And I fill in "" for "blocks_ids"
    And I select "Markus Master" from "assigned_to_id"
    And I press "OK"
    Then I should see "Bad Company" within "#impediments"
    And the impediment "Bad Company" should signal unsuccessful saving
    And the error alert should show "Blocks must contain the ID of at least one ticket"

  @javascript
  Scenario: Update an impediment
    Given I am on the taskboard for "Sprint 001"
    When I click on the impediment called "Impediment 1"
    And I fill in "Bad Company" for "subject"
    And I fill in the ids of the tasks "Task 1" for "blocks_ids"
    And I press "OK"
    Then I should see "Bad Company" within "#impediments"
    And the impediment "Bad Company" should signal successful saving

  @javascript
  Scenario: Update an impediment to block an issue of another sprint
    Given I am on the taskboard for "Sprint 001"
    When I click on the impediment called "Impediment 1"
    And I fill in "Bad Company" for "subject"
    And I fill in the ids of the stories "Story C" for "blocks_ids"
    And I press "OK"
    Then I should see "Bad Company" within "#impediments"
    And the impediment "Bad Company" should signal unsuccessful saving
    And the error alert should show "Blocks can only contain the IDs of current sprint's tickets"

  @javascript
  Scenario: Update an impediment to block a non existent issue
    Given I am on the taskboard for "Sprint 001"
    When I click on the impediment called "Impediment 1"
    And I fill in "Bad Company" for "subject"
    And I fill in "0" for "blocks_ids"
    And I press "OK"
    Then I should see "Bad Company" within "#impediments"
    And the impediment "Bad Company" should signal unsuccessful saving
    And the error alert should show "Blocks can only contain the IDs of current sprint's tickets"

  @javascript
  Scenario: Update an impediment to not block anything
    Given I am on the taskboard for "Sprint 001"
    When I click on the impediment called "Impediment 1"
    And I fill in "Bad Company" for "subject"
    And I fill in "" for "blocks_ids"
    And I press "OK"
    Then I should see "Bad Company" within "#impediments"
    And the impediment "Bad Company" should signal unsuccessful saving
    And the error alert should show "Blocks must contain the ID of at least one ticket"

  Scenario: Update sprint details
    Given I am on the master backlog
      And I want to edit the sprint named Sprint 001
      And I want to set the name of the sprint to sprint xxx
      And I want to set the start_date of the sprint to 2010-03-01
      And I want to set the effective_date of the sprint to 2010-03-20
     When I update the sprint
     Then the request should complete successfully
      And the sprint should be updated accordingly

  Scenario: Update sprint with no name
    Given I am on the master backlog
      And I want to edit the sprint named Sprint 001
      And I want to set the name of the sprint to an empty string
     When I update the sprint
     Then the server should return an update error

  Scenario: Move a story from product backlog to sprint backlog
    Given I am on the master backlog
     When I move the story named Story 1 up to the 1st position of the sprint named Sprint 001
     Then the request should complete successfully
     When I move the story named Story 4 up to the 2nd position of the sprint named Sprint 001
      And I move the story named Story 2 up to the 1st position of the sprint named Sprint 002
      And I move the story named Story 4 up to the 1st position of the sprint named Sprint 001
     Then Story 4 should be in the 1st position of the sprint named Sprint 001
      And Story 1 should be in the 2nd position of the sprint named Sprint 001
      And Story 2 should be in the 1st position of the sprint named Sprint 002

  Scenario: Move a story down in a sprint
    Given I am on the master backlog
     When I move the story named Story A below Story B
     Then the request should complete successfully
      And Story A should be in the 2nd position of the sprint named Sprint 001
      And Story B should be the higher item of Story A

  Scenario: Download printable cards for the task board
    Given I have selected card label stock Avery 8435B
      And I move the story named Story 4 up to the 1st position of the sprint named Sprint 001
      And I am on the issues index page
      And I follow "Sprint 001"
     Then the request should complete successfully
     When I follow "Export cards"
     Then the request should complete successfully

  Scenario: view the sprint notes
    Given I have set the content for wiki page Sprint Template to Sprint Template
      And I have made Sprint Template the template page for sprint notes
      And I am on the taskboard for "Sprint 001"
     When I view the sprint notes
     Then the request should complete successfully
    Then the wiki page Sprint 001 should contain Sprint Template

  Scenario: edit the sprint notes
    Given I have set the content for wiki page Sprint Template to Sprint Template
      And I have made Sprint Template the template page for sprint notes
      And I am on the taskboard for "Sprint 001"
     When I edit the sprint notes
     Then the request should complete successfully
     Then the wiki page Sprint 001 should contain Sprint Template

  Scenario: View tasks that have subtasks
  Given I am on the taskboard for "Sprint 005"
   Then I should see "Task 10" within "#tasks"
    And I should see "Task 11" within "#tasks"
    And I should not see "Subtask 1"
    And I should not see "Subtask 2"
    And I should not see "Subtask 3"
    And I should not see "Epic 1"
    And I should not see "Subfeature"
    And I should not see "Subsubtask"

  Scenario: Move stories around in the backlog that have a parent ticket
   Given I am on the master backlog
    When I move the story named Story D below Story E
    Then the request should complete successfully
     And Story D should be in the 2nd position of the sprint named Sprint 005
     And Story E should be the higher item of Story D

  Scenario: View epic, stories, tasks, subtasks in the issue list
   Given I am on the issues index page
    Then I should see "Epic 1" within "#content"
     And I should see "Story D" within "#content"
     And I should see "Story E" within "#content"
     And I should see "Task 10" within "#content"
     And I should see "Task 11" within "#content"
     And I should see "Subtask 1" within "#content"
     And I should see "Subtask 2" within "#content"
     And I should see "Subtask 3" within "#content"
     And I should see "Subfeature" within "#content"
     And I should see "Subsubtask" within "#content"

  Scenario: Move a task with subtasks around in the taskboard
   Given I am on the taskboard for "Sprint 005"
    When I move the task named Task 10 below Task 11
    Then the request should complete successfully
     And Task 11 should be the higher task of Task 10
     And the story named Story D should have 1 task named Task 10
     And the story named Story D should have 1 task named Task 11
