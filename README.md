# azbatch-starter

[![ci-cli](https://github.com/utkarshayachit/azbatch-starter/actions/workflows/ci-cli.yaml/badge.svg?branch=main&event=push)](https://github.com/utkarshayachit/azbatch-starter/actions/workflows/ci-cli.yaml)
[![ci-validate-configs](https://github.com/utkarshayachit/azbatch-starter/actions/workflows/ci-validate.yaml/badge.svg?branch=main&event=push)](https://github.com/utkarshayachit/azbatch-starter/actions/workflows/ci-validate.yaml)
[![ci-deploy-n-test](https://github.com/utkarshayachit/azbatch-starter/actions/workflows/ci-deploy-n-test.yaml/badge.svg?branch=main)](https://github.com/utkarshayachit/azbatch-starter/actions/workflows/ci-deploy-n-test.yaml)
![GitHub](https://img.shields.io/github/license/utkarshayachit/azbatch-starter)

> __Warning__
> This repository is under active development. Expect everything to change until the first version is tagged/released.

[Azure Batch](https://learn.microsoft.com/en-us/azure/batch/batch-technical-overview)
is a service for running compute intensive workloads on Azure. It provides a managed service for running
jobs on a pool of compute nodes. The service is designed to be highly scalable and can be used to run jobs that
require hundreds or thousands of compute nodes. The service is also designed to be highly customizable and can be
used to run a wide variety of workloads. Getting started with Azure Batch is easy. The service can be used to run jobs
in a matter of minutes. Getting a proof-of-concept (POC) that demonstrates the value of the service is also easy.
However, as one moves from a POC to a production deployment, by incorporating best practices and security guidelines,
the complexity of the deployment invariably increases.

This repository is a part of our accelerator solution to make it easier for customers to deploy **Azure Batch** workloads
in a manner that follows best practices and security guidelines. When used in conjunction with a hub deployment such as
[azbatch-starter-connectivity](https://github.com/mocelj/azbatch-starter-connectivity), it can be used to deploy
a locked down Azure Batch environment, designed for industrial use cases such as those in Financial Services (FSI).
For use-cases where the complexity of a fully locked-down, hub-spoke deployment is not required, this repository
can be used by itself.

## Documentation

Latest documentation is hosted on [Github Pages](https://utkarshayachit.github.io/azbatch-starter/).

## License

Copyright (c) Microsoft Corporation. All rights reserved.

Licensed under the [MIT License](./LICENSE)
