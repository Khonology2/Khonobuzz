const { defineConfig } = require("cypress");
const createBundler = require("@bahmutov/cypress-esbuild-preprocessor");
const addCucumberPreprocessorPlugin =
  require("@badeball/cypress-cucumber-preprocessor").addCucumberPreprocessorPlugin;
const createEsbuildPlugin =
  require("@badeball/cypress-cucumber-preprocessor/esbuild").createEsbuildPlugin;

module.exports = defineConfig({
  // Required for CYPRESS_STAFF_TEST_EMAIL in bundled Cucumber steps (Cypress 15 blocks Cypress.env otherwise).
  allowCypressEnv: true,
  projectId: "m8xe2e",
  e2e: {
    includeShadowDom: true,
    baseUrl:
      process.env.CYPRESS_BASE_URL ||
      process.env.BASE_URL ||
      "http://127.0.0.1:8080",
    specPattern: "**/*.feature",
    video: true,
    screenshotOnRunFailure: true,
    defaultCommandTimeout: 20000,
    pageLoadTimeout: 90000,
    async setupNodeEvents(on, config) {
      const bundler = createBundler({
        plugins: [createEsbuildPlugin(config)],
      });

      on("file:preprocessor", bundler);
      await addCucumberPreprocessorPlugin(on, config);

      return config;
    },
  },
});
