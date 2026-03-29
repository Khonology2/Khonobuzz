import { Given, When, Then } from "@badeball/cypress-cucumber-preprocessor";
import { getFlutterAccessibleText } from "../support/flutter_a11y.js";

const staffEmail = () => {
  const v = Cypress.env("STAFF_TEST_EMAIL");
  if (!v || String(v).trim() === "") {
    throw new Error(
      "Missing STAFF_TEST_EMAIL. Set GitHub secret STAFF_E2E_EMAIL or export CYPRESS_STAFF_TEST_EMAIL for local runs.",
    );
  }
  return String(v).trim();
};

/** True if Flutter surface (DOM + shadow + aria-label) includes substring or regex. */
const surfaceHas = (doc, needle) => {
  const t = getFlutterAccessibleText(doc);
  if (typeof needle === "string") {
    return t.includes(needle);
  }
  return needle.test(t);
};

Given("I open the app on the auth screen for E2E", () => {
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
  cy.get("body", { timeout: 30000 }).should("be.visible");

  // Wait a bit longer for Flutter to initialize accessibility tree
  cy.wait(2000);

  cy.document({ timeout: 120000 }).should((doc) => {
    const onAuth = surfaceHas(doc, "Select Login Preference");
    const onLanding = surfaceHas(doc, /\bGET STARTED\b/i);
    const preview = getFlutterAccessibleText(doc).slice(0, 400);
    
    // Debug: Log what we're seeing
    cy.log("Accessibility preview:", preview);
    cy.log("Looking for 'Select Login Preference':", onAuth);
    cy.log("Looking for 'GET STARTED':", onLanding);
    
    expect(
      onAuth || onLanding,
      `Flutter should expose auth or landing (CanvasKit uses aria-label in shadow). Surface sample:\n${preview}`,
    ).to.eq(true);
  });

  cy.document().then((doc) => {
    if (surfaceHas(doc, "Select Login Preference")) {
      return;
    }
    cy.contains("GET STARTED", { matchCase: false, timeout: 30000 })
      .should("exist")
      .click({ force: true });
  });
});

Then("I should see the auth choice screen", () => {
  cy.document({ timeout: 60000 }).should((doc) => {
    expect(surfaceHas(doc, "Select Login Preference")).to.eq(true);
  });
  cy.contains("MANUAL LOGIN", { matchCase: false, timeout: 30000 }).should(
    "exist",
  );
  cy.contains("ONBOARD WITH US", { matchCase: false, timeout: 30000 }).should(
    "exist",
  );
});

When("I choose manual login from the auth screen", () => {
  cy.contains("MANUAL LOGIN", { matchCase: false, timeout: 30000 })
    .should("exist")
    .click({ force: true });
});

Then("I should see the manual login form", () => {
  cy.document({ timeout: 30000 }).should((doc) => {
    const t = getFlutterAccessibleText(doc);
    expect(t.includes("Manual Login") && t.includes("Email Address")).to.eq(
      true,
    );
  });
  cy.contains("LOG IN", { matchCase: false, timeout: 20000 }).should("exist");
});

When("I enter the staff test email and confirm login", () => {
  const email = staffEmail();
  cy.get("input", { timeout: 30000 })
    .filter(":visible")
    .first()
    .should("exist")
    .clear({ force: true })
    .type(email, { delay: 0, force: true });

  cy.contains("LOG IN", { matchCase: false })
    .should("exist")
    .click({ force: true });
});

Then("I should reach the main app after login completes", () => {
  cy.document({ timeout: 120000 }).should((doc) => {
    const t = getFlutterAccessibleText(doc);
    const hasMain =
      /Launch|No module access assigned|Enjoy your session/i.test(t) ||
      (/Personal/i.test(t) && /Development/i.test(t)) ||
      /Skills heatmap|Automated Recruitment|Deliverables|Proposal|SOW Builder/i.test(
        t,
      );
    expect(
      hasMain,
      "expected post-login UI (prefetch, module cards, or no-access message)",
    ).to.eq(true);
  });
});

When("I expand the side menu for navigation labels", () => {
  cy.document({ timeout: 60000 }).then((doc) => {
    const t = getFlutterAccessibleText(doc);
    if (t.includes("Welcome to KhonoBuzz")) {
      return;
    }
    cy.get("img").filter(":visible").first().click({ force: true });
  });
  cy.contains("Modules", { timeout: 30000 }).should("exist");
  cy.contains("Profile", { timeout: 30000 }).should("exist");
});

Then("I should see module hub content", () => {
  cy.contains("Modules", { timeout: 15000 }).click({ force: true });
  cy.document({ timeout: 30000 }).should((doc) => {
    const t = getFlutterAccessibleText(doc);
    expect(
      /Launch|No module access assigned|Personal|Development|Skills heatmap|Automated|Deliverables|Proposal|SOW/i.test(
        t,
      ),
      "expected module cards or no-access copy on Modules screen",
    ).to.eq(true);
  });
});

When("I open profile from the side menu", () => {
  cy.contains("Profile", { timeout: 30000 }).should("exist").click({ force: true });
});

Then("I should see the staff profile screen", () => {
  cy.document({ timeout: 30000 }).should((doc) => {
    expect(surfaceHas(doc, "Staff Profile")).to.eq(true);
  });
});
