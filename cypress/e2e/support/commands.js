// Custom Cypress commands for Flutter Web testing

// Custom command to wait for Flutter to be ready
Cypress.Commands.add('waitForFlutterReady', (timeout = 120000) => {
  cy.get('body[flutter-ready="true"]', { timeout }).should('exist');
});

// Custom command to check if Flutter accessibility text contains expected content
Cypress.Commands.add('shouldContainFlutterText', (expectedText, timeout = 30000) => {
  cy.document({ timeout }).should((doc) => {
    const bodyText = doc.body.innerText || '';
    expect(bodyText.includes(expectedText)).to.eq(true);
  });
});

// Custom command to click Flutter button by text
Cypress.Commands.add('clickFlutterButton', (buttonText, timeout = 30000) => {
  cy.contains(buttonText, { matchCase: false, timeout })
    .should('exist')
    .click({ force: true });
});
