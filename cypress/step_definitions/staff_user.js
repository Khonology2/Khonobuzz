import { Given, When, Then } from "@badeball/cypress-cucumber-preprocessor";

const staffEmail = () => {
  const v = Cypress.env("STAFF_TEST_EMAIL");
  if (!v || String(v).trim() === "") {
    throw new Error(
      "Missing STAFF_TEST_EMAIL. Set GitHub secret STAFF_E2E_EMAIL or export CYPRESS_STAFF_TEST_EMAIL for local runs.",
    );
  }
  return String(v).trim();
};

Given("I open the app on the auth screen for E2E", () => {
  cy.visit("/?e2e=auth", { timeout: 90000 });
  cy.get("body", { timeout: 30000 }).should("be.visible");
});

Then("I should see the auth choice screen", () => {
  cy.contains("Select Login Preference", { timeout: 30000 }).should(
    "be.visible",
  );
  cy.contains("MANUAL LOGIN", { matchCase: false }).should("be.visible");
  cy.contains("ONBOARD WITH US", { matchCase: false }).should("be.visible");
});

When("I choose manual login from the auth screen", () => {
  cy.contains("MANUAL LOGIN", { matchCase: false, timeout: 20000 })
    .should("be.visible")
    .click({ force: true });
});

Then("I should see the manual login form", () => {
  cy.contains("Manual Login", { timeout: 20000 }).should("be.visible");
  cy.contains("Email Address", { timeout: 20000 }).should("be.visible");
  cy.contains("LOG IN", { matchCase: false }).should("be.visible");
});

When("I enter the staff test email and confirm login", () => {
  const email = staffEmail();
  cy.get("input", { timeout: 20000 })
    .filter(":visible")
    .first()
    .should("be.visible")
    .clear()
    .type(email, { delay: 0 });

  cy.contains("LOG IN", { matchCase: false })
    .should("be.visible")
    .click({ force: true });
});

Then("I should reach the main app after login completes", () => {
  // Wait through PrefetchOverlayDialog copy, then module hub (or no-access message).
  cy.get("body", { timeout: 120000 }).should(($body) => {
    const text = $body.text();
    const hasMain =
      /Launch|No module access assigned|Enjoy your session/i.test(text) ||
      (/Personal/i.test(text) && /Development/i.test(text)) ||
      /Skills heatmap|Automated Recruitment|Deliverables|Proposal|SOW Builder/i.test(
        text,
      );
    expect(
      hasMain,
      "expected post-login UI (prefetch, module cards, or no-access message)",
    ).to.eq(true);
  });
});

When("I expand the side menu for navigation labels", () => {
  cy.get("body", { timeout: 60000 }).then(($body) => {
    if ($body.text().includes("Welcome to KhonoBuzz")) {
      return;
    }
    cy.get("img").filter(":visible").first().click({ force: true });
  });
  cy.contains("Modules", { timeout: 20000 }).should("be.visible");
  cy.contains("Profile", { timeout: 20000 }).should("be.visible");
});

Then("I should see module hub content", () => {
  cy.contains("Modules", { timeout: 10000 }).click({ force: true });
  cy.get("body", { timeout: 30000 }).should(($body) => {
    const text = $body.text();
    expect(
      /Launch|No module access assigned|Personal|Development|Skills heatmap|Automated|Deliverables|Proposal|SOW/i.test(
        text,
      ),
      "expected module cards or no-access copy on Modules screen",
    ).to.eq(true);
  });
});

When("I open profile from the side menu", () => {
  cy.contains("Profile", { timeout: 20000 })
    .should("be.visible")
    .click({ force: true });
});

Then("I should see the staff profile screen", () => {
  cy.contains("Staff Profile", { timeout: 30000 }).should("be.visible");
});
