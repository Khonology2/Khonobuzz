describe('Debug Auth Root Test', () => {
  it('should debug the auth screen from root', () => {
    // Visit the root first (like the working test)
    cy.visit('/', {
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

    // Wait for Flutter to be ready
    cy.get('body[flutter-ready="true"]', { timeout: 120000 })
      .should('exist');

    cy.log('✅ Flutter is ready from root!');

    // Check what's on the page
    cy.document().then((doc) => {
      const bodyText = doc.body.innerText || '';
      cy.log('Page content from root:', bodyText.substring(0, 200));
    });

    // Now navigate to auth
    cy.visit('/?e2e=auth', {
      timeout: 180000,
    });

    // Wait for Flutter to be ready again
    cy.get('body[flutter-ready="true"]', { timeout: 120000 })
      .should('exist');

    cy.log('✅ Flutter is ready from auth!');

    // Check what's on the auth page
    cy.document().then((doc) => {
      const bodyText = doc.body.innerText || '';
      cy.log('Page content from auth:', bodyText.substring(0, 200));
    });
  });
});
