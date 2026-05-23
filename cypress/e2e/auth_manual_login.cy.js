describe('Auth Screen Manual Login', () => {
  beforeEach(() => {
    // Clear storage before each test
    cy.clearLocalStorage();
    cy.clearCookies();
  });

  it('should allow user to click manual login button and navigate to manual login screen', () => {
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

    // Wait for Flutter to be ready
    cy.get('body[flutter-ready="true"]', { timeout: 120000 })
      .should('exist');

    // Log that we found the Flutter-ready signal
    cy.log('✅ Flutter is ready!');

    // Verify we're on the auth screen
    cy.document({ timeout: 60000 }).should((doc) => {
      const bodyText = doc.body.innerText || '';
      expect(bodyText.includes('Select Login Preference')).to.eq(true);
    });

    // Check for manual login button
    cy.contains('MANUAL LOGIN', { matchCase: false, timeout: 30000 })
      .should('exist');

    // Check for onboarding button
    cy.contains('ONBOARD WITH US', { matchCase: false, timeout: 30000 })
      .should('exist');

    // Click the manual login button
    cy.contains('MANUAL LOGIN', { matchCase: false, timeout: 30000 })
      .should('exist')
      .click({ force: true });

    // Verify we're taken to the manual login screen
    cy.document({ timeout: 60000 }).should((doc) => {
      const bodyText = doc.body.innerText || '';
      expect(bodyText.includes('Manual Login')).to.eq(true);
      expect(bodyText.includes('Email Address')).to.eq(true);
    });

    // Check for the manual login form elements
    cy.contains('Manual Login', { matchCase: false, timeout: 30000 })
      .should('exist');
    
    cy.contains('Email Address', { matchCase: false, timeout: 30000 })
      .should('exist');
    
    cy.contains('LOG IN', { matchCase: false, timeout: 30000 })
      .should('exist');

    // Check for input field
    cy.get('input', { timeout: 30000 })
      .should('exist');
  });

  it('should show auth screen elements when loaded', () => {
    // Visit the auth screen
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

    // Wait for Flutter to be ready
    cy.get('body[flutter-ready="true"]', { timeout: 120000 })
      .should('exist');

    // Log that we found the Flutter-ready signal
    cy.log('✅ Flutter is ready!');

    // Verify auth screen elements
    cy.contains('Select Login Preference', { timeout: 30000 })
      .should('exist');
    
    cy.contains('MANUAL LOGIN', { matchCase: false, timeout: 30000 })
      .should('exist');
    
    cy.contains('ONBOARD WITH US', { matchCase: false, timeout: 30000 })
      .should('exist');
  });
});
