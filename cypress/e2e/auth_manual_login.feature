Feature: Auth Screen Manual Login
  As a user
  I want to be able to click the manual login button
  So that I can navigate to the manual login screen

  Scenario: User can click manual login button and navigate to manual login screen
    Given I open the app on the auth screen
    And I wait for Flutter to be ready
    Then I should see the auth choice screen
    When I click the manual login button
    Then I should be taken to the manual login screen
    And I should see the manual login form
