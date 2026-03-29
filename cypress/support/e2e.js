// ***********************************************************
// This example support/e2e.js is processed and
// loaded automatically before your test files.
//
// This is a great place to put global configuration and
// behavior that modifies Cypress.
//
// You can change the location of this file or turn off
// automatically serving support files with the
// 'supportFile' configuration option.
//
// You can read more here:
// https://on.cypress.io/configuration
// ***********************************************************

// Import commands.js using ES2015 syntax:
import './commands'

// @badeball/cypress-cucumber-preprocessor v24+ no longer ships the "steps" subpath;
// step definitions are bundled via createEsbuildPlugin in cypress.config.js.

// Flutter Web builds Locale from navigator; Electron (Cypress) can report values that
// make Dart throw "Incorrect locale information provided" before the app can fix it.
Cypress.on('window:before:load', (win) => {
  try {
    Object.defineProperty(win.navigator, 'language', {
      value: 'en-US',
      configurable: true,
    })
    Object.defineProperty(win.navigator, 'languages', {
      value: ['en-US', 'en'],
      configurable: true,
    })
  } catch {
    /* ignore */
  }
})