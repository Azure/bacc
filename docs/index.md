# azbatch-starter

[![validate](https://github.com/utkarshayachit/azbatch-starter/actions/workflows/validate.yaml/badge.svg)](https://github.com/utkarshayachit/azbatch-starter/actions/workflows/validate.yaml)
[![az-deploy-matrix](https://github.com/utkarshayachit/azbatch-starter/actions/workflows/az-deploy-matrix.yaml/badge.svg)](https://github.com/utkarshayachit/azbatch-starter/actions/workflows/az-deploy-matrix.yaml)
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

## Getting Started / Tutorials

The easiest way to get started is to follow one of the step-by-step tutorials for demo applications
that are closest to your target use-cases. These tutorials will walk you through the process of deploying the resources
and then play with specific demos inspired by real-world use-cases.

### __AzFinSim__: synthetic financial risk calculations

[AzFinSim](https://github.com/utkarshayachit/azfinsim) is a Python-based financial risk calculation application. While
this demo application is designed with FSI use-cases in mind, it is generic enough to be used as a starting point for
any embarrassingly parallel / high-throughput workload. Essentially, if you have an application that reads a bunch of
input files, performs some computation on each input file, and writes the results to an output file, then this demo
application you want to look at. Same is true if instead of files, your application is reading/writing to a database or
some other data store. The following table lists the tutorials that take you through the process of deploying
and testing AzFinSim on Azure Batch in various configurations.

| Tutorial | Description |
| -------- | ----------- |
| [With Containers](./tutorials/azfinsim.md) | Simple setup using application containers on Linux compute nodes. The demo includes using public container registries, like [Docker Hub](https://hub.docker.com) or deploying and using a private [Azure Container Registry (ACR)](https://azure.microsoft.com/en-us/products/container-registry). |
| [Without Containers](./tutorials/azfinsim-on-windows.md) | Same as above except using start tasks for application deployment instead of using container images. Also, this uses pool with nodes running Windows as the OS.|
| [Secured Batch](./tutorials/azfinsim-in-secured-batch.md) | Setup using application containers on Linux compute nodes within a secured Azure Batch environment that includes a complete hub and spoke deployment with firewall, log analytics, etc. deployed using [azbatch-starter-connectivity](https://github.com/mocelj/azbatch-starter-connectivity). |

To dive into the details of how the AzFinSim application is setup to run in these tutorials, please refer to the
[understanding AzFinSim](./understanding-azfinsim.md) document. The document also discusses how to monitor the application
progress using various tools provided by Azure.

### __[placeholder]__: some application example with MPI

> __TODO__: add a tutorial for an MPI application

## Design and Implementation

To understand the design of this repository, please refer to the [design document](./design.md). The implementation
uses user-editable configuration files that can be used to customize the deployments. These are also described in the
[design document](./design.md#configuration-files).

## Command-line Interface (CLI)

To make it easier to try out the demo applications, we have developed a custom command-line interface (CLI). The CLI
is described in the [CLI documentation](./cli.md). The [CLI][cli] also demonstrates how you can put together custom tools
to model your own workflows using Python and the [Azure Python SDK](https://learn.microsoft.com/en-us/azure/developer/python/?view=azure-python).

## Example Configurations

In addition to the default configuration, we also provide a few example configurations that demonstrate how to customize
the deployment to meet specific needs. These are documented [here](./examples.md). To use any of these
example configurations, you can copy the configuration files to the [`config`][config] directory and modify them as needed.
Some of the tutorials also use these example configurations.

## License

Copyright (c) Microsoft Corporation. All rights reserved.

Licensed under the [MIT License](./LICENSE)

[cli]: https://github.com/utkarshayachit/azbatch-starter/tree/main/cli
[config]: https://github.com/utkarshayachit/azbatch-starter/tree/main/config
