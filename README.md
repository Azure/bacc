# bacc: Batch Accelerator

[![ci-cli](https://github.com/Azure/bacc/actions/workflows/ci-cli.yaml/badge.svg?event=push)](https://github.com/Azure/bacc/actions/workflows/ci-cli.yaml)
[![ci-validate-configs](https://github.com/Azure/bacc/actions/workflows/ci-validate.yaml/badge.svg?event=push)](https://github.com/Azure/bacc/actions/workflows/ci-validate.yaml)
[![ci-deploy-n-test](https://github.com/Azure/bacc/actions/workflows/ci-deploy-n-test.yaml/badge.svg?event=push)](https://github.com/Azure/bacc/actions/workflows/ci-deploy-n-test.yaml)
![GitHub](https://img.shields.io/github/license/Azure/bacc)

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
[bacc-connectivity](https://github.com/Azure/bacc-connectivity.git), it can be used to deploy
a locked down Azure Batch environment, designed for industrial use cases such as those in Financial Services (FSI).
For use-cases where the complexity of a fully locked-down, hub-spoke deployment is not required, this repository
can be used by itself.

## Documentation

Latest documentation is hosted on [Github Pages](https://azure.github.io/bacc/).

## License

Copyright (c) Microsoft Corporation. All rights reserved.

Licensed under the [MIT License](./LICENSE)

## Contributing

This project welcomes contributions and suggestions. Most contributions require you to
agree to a Contributor License Agreement (CLA) declaring that you have the right to,
and actually do, grant us the rights to use your contribution. For details, visit
https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine whether you need
to provide a CLA and decorate the PR appropriately (e.g., label, comment). Simply follow the
instructions provided by the bot. You will only need to do this once across all repositories using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/)
or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
