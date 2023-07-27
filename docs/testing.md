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

* `az-deploy` is intended to deploy and test a specific test suite. It is used internally by other workflows to deploy the
  resources for a test suite.

## Test Suites

Test suites enable us to identify and test different deployment configurations and scenarios.

* `azfinsim-linux` tests AzFinSim application deployed on the `examples/azfinsim-linux` configuration, in other words, the steps described
  in [this tutorial](./tutorials/azfinsim.md). ACR is enabled, and AzFinSim application tests are deployed. The tests include basic validation tests.
  These includes tests to resize pools to ensure nodes can be allocated. In addition, we now have tests that run azfinsim jobs using container
  images from Docker Hub as well as the deployed ACR.

* `azfinsim-windows` tests the `examples/azfinsim-windows` configuration; pretty much the scenario described in
  [this tutorial](./tutorials/azfinsim-on-windows.md). Here, we are testing the Windows version of AzFinSim application which is setup
  on the compute nodes using a start task, rather than the container-based approach used in the Linux-based scenarios so far.

* `secured-batch` tests the scenarios described in [this tutorial](./tutorials/azfinsim-in-secured-batch.md). This test suite
  requires that the hub has been deployed separately and hence not really intended to be tried directly (except by advanced developers of course).
  This test suite executed as part of the `az-deploy-n-test-hub-n-spoke` workflow which deploys the hub and then runs this test suite. This test suite
  further differs from others because the Github Runner doesn't have access to the deployed resource endpoints and hence cannot issue commands to
  submit jobs or query jobs. Instead, the tests verify that access is indeed denied and then runs the tests from the linux jumpbox which is deployed
  as part of the hub deployment. The test suite passes if the jumpbox reports back that the tests including job submission etc. were successful. Thus,
  verifying that the secured-batch configuration is working as expected.

* `vizer` tests the vizer demo described in [this tutorial](./tutorials/vizer.md).
