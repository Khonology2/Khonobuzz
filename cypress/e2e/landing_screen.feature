Feature: Landing Screen
  As a new user after initial welcome
  I want to see the KhonoBuzz branding and main call-to-action
  And navigate to authentication options
 
  Background:
    Given I am on the landing screen
 
  Scenario: Landing screen displays KhonoBuzz branding
    Then I should see the Khonology logo and branding
    And I should see the KhonoBuzz title
    And the landing screen should be fully loaded
 
  Scenario: Landing screen shows animated GET STARTED button
    Then I should see the GET STARTED button
    And the button should have animated effects
    And the button should be clickable
 
  Scenario: Backend warmup occurs on button click
    When I click on the "Get Started" button
    Then the backend warm-up should be triggered
    And I should be redirected to the authentication screen
    And the authentication screen should load successfully