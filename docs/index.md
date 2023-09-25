# azbatch-starter

> __Warning__
> This repository is under active development. Expect everything to change until the first version is tagged/released.

[Azure Batch](https://learn.microsoft.com/en-us/azure/batch/batch-technical-overview)
is a service for running compute intensive workloads on Azure. It provides a managed service for running
jobs on a pool of compute nodes. The service is designed to be highly scalable and can be used to run jobs that
require hundreds or thousands of compute nodes. The service is also designed to be highly customizable and can be
used to run a wide variety of workloads. Getting started with Azure Batch is easy. The service can be used to run jobs
in a matter of minutes. Getting a proof-of-concept (POC) that demonstrates the value of the service is relatively easy.
However, taking that POC to a production deployment can be challenging especially if the deployment needs to follow
best practices and security guidelines.

That is where this repository comes in. It is designed to make it easier to develop and deploy Azure Batch infrastructure
in a manner that follows best practices and security guidelines. This is part of our accelerator solution for Azure Batch
intended to accelerate development of POCs as well as production deployments alike.

<!-- 
The complexity of the deployment increases further if the deployment needs to

as one moves from a POC to a production deployment, by incorporating best practices and security guidelines,
the complexity of the deployment invariably increases.

This repository is a part of our accelerator solution to make it easier for customers to deploy __Azure Batch__ workloads
in a manner that follows best practices and security guidelines. When used in conjunction with a hub deployment such as
[azbatch-starter-connectivity](https://github.com/mocelj/azbatch-starter-connectivity), it can be used to deploy
a locked down Azure Batch environment, designed for industrial use cases such as those in Financial Services (FSI).
For use-cases where the complexity of a fully locked-down, hub-spoke deployment is not required, this repository
can be used by itself. -->

## Philosophy

This code-base is intended to be used to create custom deployments on Azure. When thinking of migrating
any computation workload to Azure, one of the first steps is to design the Azure resources used and the
network topology i.e. the deployment. When designing a deployment with Azure resources and network topology
for a specific application or workload, understanding the specific requirements of the application/workload is
critical. Rather than trying to create a one-size-fits-all solution, this accelerator is designed
to be a starting point for creating custom deployments tailored for specific applications. In simple cases,
the default example configurations provided by this repository may be sufficient. In those cases, customizations
are easily supported by editing the JSON configuration files. In more complex cases, the examples provided by this
repository can be used as a starting point for creating custom Bicep IaC templates.

The [`examples`] directory includes different example deployments for different applications. These are discussed
in the tutorials below. 

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
| [Linux with Containers](./tutorials/azfinsim-linux.md) | Simple setup using application containers on Linux compute nodes. The demo includes using public container registries, like [Docker Hub](https://hub.docker.com) or deploying and using a private [Azure Container Registry (ACR)](https://azure.microsoft.com/en-us/products/container-registry). |
| [Windows](./tutorials/azfinsim-windows.md) | Same as above except using start tasks for application deployment instead of using container images. Also, this uses pool with nodes running Windows as the OS.|

To dive into the details of how the AzFinSim application is setup to run in these tutorials, please refer to the
[understanding AzFinSim](./understanding-azfinsim.md) document. The document also discusses how to monitor the application
progress using various tools provided by Azure.

### Secured Batch: Reference deployment for FSI use-cases

[Secured Batch](./tutorials/azfinsim-in-secured-batch.md) is a reference architecture for running FSI workloads on Azure Batch.
This is a complete hub-n-spoke deployment that includes a secured Azure Batch environment with firewall, log analytics, etc.
This tutorial demonstrates how a FSI application, like AzFinSim, can be deployed and used in a secured Azure Batch environment.


| Tutorial | Description |
| -------- | ----------- |
| [Secured Batch](./tutorials/azfinsim-in-secured-batch.md) | Setup using application containers on Linux compute nodes within a secured Azure Batch environment that includes a complete hub and spoke deployment with firewall, log analytics, etc. |

### vizer: 3D visualization of scientific data

[vizer](https://github.com/utkarshayachit/vizer) is a ParaView/Python-based web application for visualizing scientific datasets.
This demo application is designed to demonstrate how to deploy an interactive web application on Azure Batch. The following table lists
the tutorials that take you through the process of deploying and testing vizer on Azure Batch in various configurations.

| Tutorial | Description |
| -------- | ----------- |
| [vizer](./tutorials/vizer.md) | Simple setup using application containers on Linux compute nodes. The demo deploys [vizer-hub](https://github.com/utkarshayachit/vizer-hub) which can be used to browse and visualize datasets from a preexisting storage account.

### MPI Benchmarks: MPI benchmarks (Intel and OSU micro-benchmarks)

MPI (Message Passing Interface) is a standard for writing parallel applications that run on distributed memory systems.
Azure Batch enables a cloud-native MPI deployment that can be used to run MPI applications on Azure. The following table
lists the tutorials that take you through the process of deploying and testing MPI benchmarks on Azure Batch in various
configurations.

| Tutorial | Description |
| -------- | ----------- |
| [MPI Benchmarks on RHEL](./tutorials/mpi-benchmarks-rhel.md) | Simple setup using application containers on Linux compute nodes with RHEL 8. |



## Design and Implementation

To understand the design of this repository, please refer to the [design document](./design.md). The implementation
uses user-editable configuration files that can be used to customize the deployments. These are also described in the
[design document](./design.md#configuration-files).

## Command-line Interface (CLI)

To make it easier to try out the demo applications, we have developed a custom command-line interface (CLI). The CLI
is described in the [CLI documentation](./cli.md). The [CLI][cli] also demonstrates how you can put together custom tools
to model your own workflows using Python and the [Azure Python SDK](https://learn.microsoft.com/en-us/azure/developer/python/?view=azure-python).

## Automated Testing (CI)

We use GitHub Actions to run automated tests on every pull request and/or change to the repository. For details on the
workflows and tests, please refer to the [testing document](./testing.md).

## License

Copyright (c) Microsoft Corporation. All rights reserved.

Licensed under the [MIT License](./LICENSE)

[cli]: https://github.com/utkarshayachit/azbatch-starter/tree/main/cli
[config]: https://github.com/utkarshayachit/azbatch-starter/tree/main/config
[`examples`]: https://github.com/utkarshayachit/azbatch-starter/tree/main/examples
