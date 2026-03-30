describe('Flutter Ready Test', () => {
  it('should show flutter-ready attribute when app loads', () => {
    // Visit the auth screen with E2E parameter
    cy.visit('/?e2e=auth', {
      timeout: 180000,
      onBeforeLoad(win) {
        try {
          win.localStorage?.clear?.();
          win.sessionStorage?.clear?.();
        } catch {
          /* ignore */
        }
      },
    });

    // Wait for Flutter to be ready - this is the key test
    cy.get('body[flutter-ready="true"]', { timeout: 120000 })
      .should('exist');

    // Log that we found the Flutter-ready signal
    cy.log('✅ Flutter is ready!');

    // Check what's actually on the page
    cy.document().then((doc) => {
      const bodyText = doc.body.innerText || '';
      cy.log('Page content:', bodyText.substring(0, 500));
    });

    // Simple check for any text content
    cy.get('body', { timeout: 30000 }).should('exist');
  });
});
