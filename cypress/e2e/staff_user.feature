Feature: Staff user — auth screen to modules and profile
  Starts on the auth screen (landing skipped via ?e2e=auth).
  Requires a real staff @khonology.com user in the backend (see GitHub secret STAFF_E2E_EMAIL).

  Scenario: Manual login then explore modules and profile
    Given I open the app on the auth screen for E2E
    Then I should see the auth choice screen
    When I choose manual login from the auth screen
    Then I should see the manual login form
    When I enter the staff test email and confirm login
    Then I should reach the main app after login completes
    When I expand the side menu for navigation labels
    Then I should see module hub content
    When I open profile from the side menu
    Then I should see the staff profile screen
