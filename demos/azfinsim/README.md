# AzFinSim: Azure Financial Simulation

AzFinSim is a simple Python application for synthetic risk simulation. It is designed to be used as a demo for
Azure services, but can also be used as a standalone application.
The source code is available on [GitHub](https://github.com/utkarshayachit/azfinsim)

In this demo, we discuss how to deploy and use the azfinsim application demo using the Azure CLI extensions
specifically designed for sbatch deployments. Note, however, the extensions are just convenience and demonstrate how such
simply extensions can be developed to simplify workflows. The extensions are not required to use the application. You do
the same using the Azure Portal, standard Azure CLI commands, Batch Explorer, workflow managers like Apache Airflow, etc.

This demo uses the custom [CLI](../cli/README.md) to simplify interaction with the application.

## Building the Container Image

This demo uses containers. If the deployment was created with `enableApplicationContainers=true`, then you can use the
Azure Container Registry deployed as part of the deployment. Alternatively, any container registry, including docker hub,
is supported so long as the image has public access for pulling. For convenience, we have made the container images for
azfinsim available [here](https://hub.docker.com/repository/docker/utkarshayachit/azfinsim/general).

To use the ACR deployed, you first need to build and push the container image to the ACR. The easiest way to do
this is to use the `az acr build` command. This command will build the container image from the source code
on GitHub and push it to the ACR.

```sh
#! /bin/bash

# fetch acr name from the deployment;
# you can also use Azure Portal to navigate to the resource group and get the 
# Azure Container Registry resource name manually
ACR_NAME=$(sb show -g <resource group> -s <subscription id> --query "acr_name")

# build and push container image on ACR
az acr build                    \
    -r $ACR_NAME                \
    -t azfinsim/azfinsim:latest \
    "https://github.com/utkarshayachit/azfinsim#main"
# will output container build / push status

# on success, you can verify the image was pushed to the ACR
az acr repository list -n $ACR_NAME -o tsv
# expected output:
azfinsim/azfinsim
```

## Using Docker Hub

If you did not deploy with `enableApplicationContainers=true`, then you two options. You can either build the container
image yourself and push it to a container registry of your choice, or you can use the container image we have built and
pushed to Docker Hub. The container image is available at
[`utkarshayachit/azfinsim:[tagname]`](https://hub.docker.com/repository/docker/utkarshayachit/azfinsim/general).
You can use this image directly in the CLI commands below.

## CLI

The `sb azfinsim ...` command provides a simple interface to interact with the azfinsim application.

```sh
> sb azfinsim --help

Command
    sb azfinsim : Execute the azfinsim demo.
        This command executes the azfinsim demo. This will submit a job to Azure Batch
        to process a set of trades. The trades will be generated randomly if no trades file
        is specified. The results will be stored in a CSV file on the Azure Storage account
        mounted on the pool. The path to the CSV file is returned as the output from this
        command.

Arguments
    --num-tasks -k                      : The number of concurrent tasks to use for the job.
                                          Default: 1.

AzFinSim Arguments
    --algorithm -a                      : The algorithm to use for the job.  Allowed values:
                                          deltavega, pvonly.  Default: deltavega.
    --num-trades -n                     : The number of trades to generate if no trades file is
                                          specified.
    --trades-file -t                    : The path to the trades file to use instead of generating
                                          random trades.

Container Arguments
    --container-registry -r             : The name of the container registry to use for the job. If
                                          not specified, ACR deployed as part of the sbatch
                                          deployment is used.
    --image-name -i                     : The name of the container image to use for the job.
                                          Default: azfinsim/azfinsim:latest.

Deployment Arguments
    --resource-group-name -g [Required] : The name of the resource group.
    --subscription-id -s     [Required] : The subscription ID.

Global Arguments
    --debug                             : Increase logging verbosity to show all debug logs.
    --help -h                           : Show this help message and exit.
    --only-show-errors                  : Only show errors, suppressing warnings.
    --output -o                         : Output format.  Allowed values: json, jsonc, none, table,
                                          tsv, yaml, yamlc.  Default: json.
    --query                             : JMESPath query string. See http://jmespath.org/ for more
                                          information and examples.
    --verbose                           : Increase logging verbosity. Use --debug for full debug
                                          logs.
```

Let's look at some example scenarios to understand how to use the CLI.

### Process Random Trades

The following command will generate 1000 random trades and submit a job to Azure Batch to process them. The job will
use 10 concurrent tasks to process the trades. The results will be stored in a CSV file on the Azure Storage account
mounted on the pool. The path to the CSV file is returned as the output from this command.

```sh
# using ACR deployed as part of the sbatch deployment
sb azfinsim -g <resource group> -s <subscription id>    \
    --num-trades 1000                                   \
    --num-tasks 10                                      \
    --algorithm pvonly
# this will output the path to the CSV file containing the results
{
    "job_id": "...",
    "results_file": ".../trades.results.csv"
}
```

The above command assumes that the ACR already has the container image pushed to it. If you did not deploy with
`enableApplicationContainers=true`, then you can use the container image we have built and pushed to Docker Hub as follows:

```sh
# using Docker Hub
sb azfinsim -g <resource group> -s <subscription id>    \
    --num-trades 1000                                   \
    --num-tasks 10                                      \
    --algorithm pvonly                                  \
    --container-registry "docker.io"                    \
    --image-name "utkarshayachit/azfinsim:main"
```

### Process Existing Trades

> __TODO__: add steps for uploading trades to storage account

The following command will submit a job to Azure Batch to process the trades in the CSV file. The job will
use 10 concurrent tasks to process the trades. The results will be stored in a CSV file on the Azure Storage account
mounted on the pool. The path to the CSV file is returned as the output from this command.

```sh
sb azfinsim -g <resource group> -s <subscription id>    \
    --trades-file <path to trades file>                 \
    --num-tasks 10                                      \
    --algorithm pvonly
# this will output the path to the CSV file containing the results
{
    "job_id": "...",
    "results_file": ".../trades.results.csv"
}
```

### Windows Pool / Non-Container Workloads

The steps so far describe how you can use the azfinsim application to process trades if sbatch was deployed using
the default config which includes a linux pool with support for containerized workloads. The demo application
also supports running on a Windows pool assuming the application is installed on the compute nodes.
The [example config1](../../examples/README.md) can be used to deploy sbatch with a Windows pool where azfinsim application
is installed as part of a start task of the pool. The following command can be used to submit a job to the Windows pool

```sh
# command for submitting job for examples/config1 based deployment
sb azfinsim -g <resource group> -s <subscription id>    \
    --num-trades 1000                                   \
    --num-tasks 10                                      \
    --algorithm pvonly                                  \
    --mode package                                      \
    --pool-id windows
```
