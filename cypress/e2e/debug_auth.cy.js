describe('Debug Auth Test', () => {
  it('should debug the auth screen loading', () => {
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

    // Log what we see immediately
    cy.document().then((doc) => {
      cy.log('Document loaded, checking body attributes...');
      const body = doc.body;
      cy.log('Body attributes:', body.getAttributeNames());
      cy.log('Flutter-ready attribute:', body.getAttribute('flutter-ready'));
    });

    // Wait for Flutter to be ready
    cy.get('body[flutter-ready="true"]', { timeout: 120000 })
      .should('exist');

    // Log success
    cy.log('✅ Flutter is ready!');

    // Check what's actually on the page
    cy.document().then((doc) => {
      const bodyText = doc.body.innerText || '';
      cy.log('Page content preview:', bodyText.substring(0, 200));
    });
  });
});
