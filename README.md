# bacc: Batch Accelerator

[![ci-cli](https://github.com/utkarshayachit/azbatch-starter/actions/workflows/ci-cli.yaml/badge.svg?branch=main&event=push)](https://github.com/utkarshayachit/azbatch-starter/actions/workflows/ci-cli.yaml)
[![ci-validate-configs](https://github.com/utkarshayachit/azbatch-starter/actions/workflows/ci-validate.yaml/badge.svg?branch=main&event=push)](https://github.com/utkarshayachit/azbatch-starter/actions/workflows/ci-validate.yaml)
[![ci-deploy-n-test](https://github.com/utkarshayachit/azbatch-starter/actions/workflows/ci-deploy-n-test.yaml/badge.svg?branch=main)](https://github.com/utkarshayachit/azbatch-starter/actions/workflows/ci-deploy-n-test.yaml)
![GitHub](https://img.shields.io/github/license/utkarshayachit/azbatch-starter)

[Azure Batch](https://learn.microsoft.com/en-us/azure/batch/batch-technical-overview)
is a service for running compute intensive workloads on Azure. It is a managed service for running
jobs on a pool of compute nodes. The service is designed to be highly scalable and can be used to run jobs that
require hundreds or thousands of compute nodes. The service is also designed to be highly customizable and can be
used to run a wide variety of workloads. Getting started with Azure Batch is easy. The service can be used to run jobs
in a matter of minutes. Getting a proof-of-concept (POC) that demonstrates the value of the service is relatively easy.
However, taking that POC to a production deployment can be challenging especially if the deployment needs to follow
best practices and security guidelines.
Despite best intentions, it's not uncommon that initial designs for POCs often end up being used for production deployments.
Given that, it is best to start with a system architecture that takes this into consideration.
These are exactly the scenarios that  **bacc** is designed to address. It is designed to make it easier to develop and
deploy Azure Batch based computing infrastructure in a manner that follows best practices and security guidelines.
This is part of our accelerator solution for Azure Batch intended to accelerate development of POCs as well as
production deployments alike.

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
