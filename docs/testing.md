# Automated Testing

To ensure that the code continues to work as expected through changes
and updates, we employ automated testing using Github Workflows. This page describes the
different workflows, their purpose and how to use them for testing.

## Workflows

Workflows prefixed with `ci-` are workflows that are triggered automatically either when a pull request is opened or
when a commit is pushed to the repository. The workflows prefixed with `az-` are workflows that can be triggered manually
by a user with write access to the repository.

* `ci-cli` tests the CLI tool. It runs some basic sanity checks to ensure that the Python code
  in the CLI tool is valid and that the CLI tool can be installed and run.

* `ci-validate-configs` validates various configuration files in the repository. It checks that
  the configuration files are valid and that they conform to the relevant schemas. The workflow is designed to validate both
  the default set of configuration files as well as any configuration files that under the `examples/` directory.

* `ci-deploy-n-test` is the main workflow that deploys the resources and tests that the applications and demos work as expected
  on the deployed resources. It is designed to run through multiple **test suites**, each testing a deployment using a different
  configuration. The tests include submitting jobs to the deployed resources and checking that the jobs complete successfully.

* `az-deploy-n-test-hub-n-spoke` is intended to test the secured-batch configuration complete with a hub deployment. Since this
  deployment locks down access to endpoints from public networks the test suite is run indirectly from the linux jumpbox which
  deployed as part the hub deployment.
