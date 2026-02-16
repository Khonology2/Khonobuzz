const { defineConfig } = require("cypress");

module.exports = defineConfig({
  allowCypressEnv: false,
  projectId: "m8xe2e",
  e2e: {
    setupNodeEvents(on, config) {
      // implement node event listeners here
    },
  },
});
