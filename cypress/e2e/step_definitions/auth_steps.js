import { Given, When, Then } from "@badeball/cypress-cucumber-preprocessor";

Given("I open the app on the auth screen", () => {
  cy.visit("/?e2e=auth", {
    timeout: 90000,
    onBeforeLoad(win) {
      try {
        win.localStorage?.clear?.();
        win.sessionStorage?.clear?.();
      } catch {
        /* ignore */
      }
    },
  });
});

Given("I wait for Flutter to be ready", () => {
  // Wait for Flutter to fully load and be ready
  cy.get('body[flutter-ready="true"]', { timeout: 120000 })
    .should('exist');
});

Then("I should see the auth choice screen", () => {
  // Check for the auth screen title
  cy.document({ timeout: 60000 }).should((doc) => {
    const bodyText = doc.body.innerText || '';
    expect(bodyText.includes('Select Login Preference')).to.eq(true);
  });
  
  // Check for the manual login button
  cy.contains('MANUAL LOGIN', { matchCase: false, timeout: 30000 }).should('exist');
  
  // Check for the onboarding button
  cy.contains('ONBOARD WITH US', { matchCase: false, timeout: 30000 }).should('exist');
});

When("I click the manual login button", () => {
  cy.contains('MANUAL LOGIN', { matchCase: false, timeout: 30000 })
    .should('exist')
    .click({ force: true });
});

Then("I should be taken to the manual login screen", () => {
  // Wait for navigation and check for manual login screen content
  cy.document({ timeout: 60000 }).should((doc) => {
    const bodyText = doc.body.innerText || '';
    expect(bodyText.includes('Manual Login')).to.eq(true);
    expect(bodyText.includes('Email Address')).to.eq(true);
  });
});

Then("I should see the manual login form", () => {
  // Check for the login form elements
  cy.contains('Manual Login', { matchCase: false, timeout: 30000 }).should('exist');
  cy.contains('Email Address', { matchCase: false, timeout: 30000 }).should('exist');
  cy.contains('LOG IN', { matchCase: false, timeout: 30000 }).should('exist');
  
  // Check for input field
  cy.get('input', { timeout: 30000 }).should('exist');
});
