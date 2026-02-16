// cypress/step_definitions/landing_screen.js
import { Given, When, Then, Before } from "@badeball/cypress-cucumber-preprocessor";

// Background step
Given("I am on the landing screen", () => {
  cy.visit("http://localhost:3000", { timeout: 15000 });
  cy.get("body", { timeout: 10000 }).should("be.visible");
});

// Branding and UI Checks
Then("I should see the Khonology logo and branding", () => {
  // Using data-testid is recommended for better test stability
  cy.get('[data-testid="khonology-logo"]').should('be.visible');
  // Or if using aria-label
  // cy.get('[aria-label="khonology-logo"]').should('be.visible');
});

Then("I should see the KhonoBuzz title", () => {
  cy.contains('h1', 'KhonoBuzz').should('be.visible');
  // Or if the title is in a specific element
  // cy.get('[data-testid="app-title"]').should('contain', 'KhonoBuzz');
});

Then("the landing screen should be fully loaded", () => {
  // Check for a loading state to be removed
  cy.get('[data-testid="loading-indicator"]').should('not.exist');
  // Or check for a specific element that indicates the page is loaded
  // cy.get('[data-testid="main-content"]').should('be.visible');
});

// Button interactions
Then("I should see the GET STARTED button", () => {
  cy.contains('button', 'GET STARTED', { timeout: 10000 }).should('be.visible');
  // Or using data-testid
  // cy.get('[data-testid="get-started-button"]').should('be.visible');
});

Then("the button should have animated effects", () => {
  // Check for animation classes or styles
  cy.contains('button', 'GET STARTED')
    .should('have.css', 'transition')
    .and('not.have.css', 'animation', 'none');
  // Or check for specific animation classes
  // .should('have.class', 'animate-pulse');
});

Then("the button should be clickable", () => {
  cy.contains('button', 'GET STARTED')
    .should('be.enabled')
    .and('not.have.attr', 'disabled')
    .and('be.visible');
});

When('I click on the {string} button', (buttonText) => {
  cy.contains('button', buttonText, { timeout: 10000 }).click();
  // Or using data-testid
  // cy.get(`[data-testid="${buttonText.toLowerCase().replace(' ', '-')}-button"]`).click();
});

// Navigation and backend checks
Then("the backend warm-up should be triggered", () => {
  // Check for loading state or API call
  cy.intercept('POST', '/api/warmup').as('warmupCall');
  // Or check for a loading indicator
  // cy.get('[data-testid="loading-indicator"]').should('be.visible');
  // cy.get('[data-testid="loading-indicator"]').should('not.exist');
});

Then("I should be redirected to the authentication screen", () => {
  cy.url({ timeout: 10000 }).should('include', '/auth');
  // Or check for a specific element on the auth screen
  // cy.get('[data-testid="auth-screen"]').should('be.visible');
});

Then("the authentication screen should load successfully", () => {
  // Check for auth screen elements
  cy.get('[aria-label="auth-options"]', { timeout: 10000 }).should('be.visible');
  // Check for login and signup options
  cy.contains('button', 'Login').should('be.visible');
  cy.contains('button', 'Sign Up').should('be.visible');
});