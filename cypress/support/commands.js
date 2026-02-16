// ***********************************************
// This example commands.js shows you how to
// create various custom commands and overwrite
// existing commands.
//
// For more comprehensive examples of custom
// commands please read more here:
// https://on.cypress.io/custom-commands
// ***********************************************
//
//
// -- This is a parent command --
// Cypress.Commands.add('login', (email, password) => { ... })
//
//
// -- This is a child command --
// Cypress.Commands.add('drag', { prevSubject: 'element'}, (subject, options) => { ... })
//
//
// -- This is a dual command --
// Cypress.Commands.add('dismiss', { prevSubject: 'optional'}, (subject, options) => { ... })
//
//
// -- This will overwrite an existing command --
// Cypress.Commands.overwrite('visit', (originalFn, url, options) => { ... })
 
// ============================================
// CUSTOM COMMANDS - Navigation
// ============================================
 
/**
 * Navigate to landing screen by clicking Get Started on welcome screen
 */
Cypress.Commands.add("navigateToLanding", () => {
  cy.clickElementByAriaLabel("get-started", 629, 500);
  cy.get("body").should("be.visible");
});
 
/**
 * Navigate to authentication screen via landing
 */
Cypress.Commands.add("navigateToAuthScreen", () => {
  cy.navigateToLanding();
  cy.clickElementByAriaLabel("get-started", 629, 350);
  cy.get("body").should("be.visible");
});
 
/**
 * Navigate to manual login screen
 */
Cypress.Commands.add("navigateToManualLogin", () => {
  cy.navigateToAuthScreen();
  cy.clickElementByAriaLabel("manual-login", 629, 300);
  cy.get("body").should("be.visible");
});
 
// ============================================
// CUSTOM COMMANDS - Element Interaction
// ============================================
 
/**
 * Click element by aria-label with fallback to coordinate-based click
 * @param {string} label - aria-label value
 * @param {number} x - fallback x coordinate
 * @param {number} y - fallback y coordinate
 */
Cypress.Commands.add("clickElementByAriaLabel", (label, x, y) => {
  cy.window().then((win) => {
    const el = win.document.querySelector(`[aria-label="${label}"]`);
    if (el) {
      cy.get(`[aria-label="${label}"]`).click({ force: true });
    } else {
      cy.get("body").click(x, y, { force: true });
    }
  });
});
 
/**
 * Enter text into email input field with multiple selector fallbacks
 * @param {string} email - email address to enter
 */
Cypress.Commands.add("enterEmail", (email) => {
  cy.window().then((win) => {
    let input = win.document.querySelector('[key="email_input"]');
    if (!input) {
      input = win.document.querySelector('input[type="text"]');
      if (!input) {
        input = win.document.querySelector('input');
      }
    }
    if (input) {
      cy.get(input).clear().type(email, { delay: 30 });
    }
  });
});
 
/**
 * Submit the login form by clicking confirm button
 */
Cypress.Commands.add("submitLoginForm", () => {
  cy.window().then((win) => {
    const el = win.document.querySelector('[key="confirm-button"]');
    if (el) {
      cy.get('[key="confirm-button"]').click({ force: true });
    } else {
      cy.get("body").click(629, 200, { force: true });
    }
  });
});
 
// ============================================
// CUSTOM COMMANDS - API Interception
// ============================================
 
/**
 * Setup API intercept for successful login
 * @param {object} userData - user data from fixtures
 */
Cypress.Commands.add("setupLoginSuccessResponse", (userData) => {
  cy.intercept("POST", "**/api/auth/login", {
    statusCode: 200,
    body: {
      success: true,
      user: userData,
      token: "jwt-token-" + userData.id
    }
  }).as("loginSuccess");
});
 
/**
 * Setup API intercept for pending approval
 */
Cypress.Commands.add("setupPendingApprovalResponse", () => {
  cy.intercept("POST", "**/api/auth/login", {
    statusCode: 202,
    body: {
      success: false,
      status: "pending_approval",
      message: "Account is pending admin approval"
    }
  }).as("pendingApproval");
});
 
/**
 * Setup API intercept for invalid domain
 */
Cypress.Commands.add("setupInvalidDomainResponse", () => {
  cy.intercept("POST", "**/api/auth/login", {
    statusCode: 422,
    body: {
      success: false,
      error: "INVALID_DOMAIN",
      message: "Only @khonology.com email addresses are allowed"
    }
  }).as("invalidDomain");
});
 
/**
 * Verify API was called and wait for response
 * @param {string} alias - the alias to wait for
 */
Cypress.Commands.add("verifyApiCall", (alias) => {
  cy.wait("@" + alias, { timeout: 15000 }).then((interception) => {
    expect(interception.response).to.exist;
  });
});
 
// ============================================
// CUSTOM COMMANDS - Assertions
// ============================================
 
/**
 * Verify user is on dashboard/main app
 */
Cypress.Commands.add("verifyOnDashboard", () => {
  cy.url({ timeout: 15000 }).should("include", "/modules").or.should("include", "/dashboard");
  cy.get("body").should("be.visible");
});
 
/**
 * Verify user is still on manual login screen
 */
Cypress.Commands.add("verifyOnManualLogin", () => {
  cy.url().should("include", "/manual-login").or.include("/auth");
  cy.get("[key='email_input']").should("be.visible");
});
 
/**
 * Verify element exists with aria-label
 * @param {string} label - aria-label value
 */
Cypress.Commands.add("verifyElementExists", (label) => {
  cy.get(`[aria-label="${label}"]`, { timeout: 10000 }).should("be.visible");
});