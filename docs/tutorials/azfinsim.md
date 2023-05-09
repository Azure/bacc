# Tutorial: AzFinSim on Linux pool with Containers

This tutorial is a step-by-step guide on how to run AzFinSim on a Linux pool with containers.
This is also intended as the main demo for AzFinSim application and is a good place
to start if you are new to AzFinSim or Azure Batch.

This tutorial has two variants: using Docker Hub and using Azure Container Registry (ACR).
The Docker Hub variant is simpler and is recommended for first time users. Steps below describe the Docker Hub variant.
For those steps that are different for ACR variant, we have provided a note.

## Key Design Elements

* Uses Azure Batch service deployed with pool allocation mode set to **Batch Service**.
* AzFinSim application is packaged as a container image. The container image is pulled from a
  Docker Hub repository.

## Step 1: Prerequisites and environment setup

Follow the [environment setup instructions](./environment-setup.md) to set up your environment. Since
this tutorial uses **Batch Service** pool allocation mode, you can skip the **User Subscription** specific
requirements and  steps described in that document.

## Step 2: Select deployment configuration

For this tutorial, we will use configuration files from [examples/azfinsim-linux] folder.
To use these files, copy them to the config folder.

```bash
# change directory to azbatch-starter (or where you cloned/downloaded the repository)
cd azbatch-starter

# copy config files
cp examples/azfinsim-linux/* config/
```

## Step 3: Deploy the batch account and other resources

Create deployment using Azure CLI.

```bash
#!/bin/bash

# create deployment
AZ_LOCATION=eastus2
AZ_DEPLOYMENT_NAME=azfinsim0
AZ_RESOURCE_GROUP=azfinsim0

az deployment sub create                  \
  --name $AZ_DEPLOYMENT_NAME              \
  --location $AZ_LOCATION                 \
  --template-file infrastructure.bicep    \
  --parameters                            \
      resourceGroupName=$AZ_RESOURCE_GROUP
```

On success, a new resource group will be created with the name specified. This resource group will contain all the resources
deployed by this deployment.

If you want to also test with ACR instead or in addition to Docker Hub, then use the following command to create the
deployment instead i.e. simply add the `enableApplicationContainers=true` parameter.

```bash
#!/bin/bash

az deployment sub create                    \
  --name $AZ_DEPLOYMENT_NAME                \
  --location $AZ_LOCATION                   \
  --template-file infrastructure.bicep      \
  --parameters                              \
      resourceGroupName=$AZ_RESOURCE_GROUP  \
      enableApplicationContainers=true
```

## Step 4: Install CLI

Next, we install the CLI tool provided by this repository. This tool is used to submit jobs and tasks to the batch account.
We recommend using a python virtual environment to install the CLI tool to avoid polluting the global python environment.

Follow the steps described [here](../cli.md#installation) to install the CLI tool.

## Step 5: Verify deployment

We can the CLI tool deployed in previous step to verify the deployment.

```bash
#!/bin/bash

# fetch subscription id from the portal or using the following command
# if you have already logged in to Azure CLI using `az login` command
> AZ_SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# use the `sb show` command
> sb show -s $AZ_SUBSCRIPTION_ID -g $AZ_RESOURCE_GROUP
# on success, you'll get the following output
{
  "acr_name": null,
  "batch_endpoint": "https://......batch.azure.com"
}

# if you deployed with `enableApplicationContainers=true` parameter, then the `acr_name`
# will be a valid URL instead of `null`.

# To list all available pools, use the `sb pool list` command
> sb pool list -s $AZ_SUBSCRIPTION_ID -g $AZ_RESOURCE_GROUP \
    --query "[].{pool_id:id, vm_size:vmSize, state:allocationState}"
# expected output
[
  {
    "pool_id": "linux",
    "state": "steady",
    "vm_size": "standard_ds5_v2"
  }
]
```

## Step 6: Submit AzFinSim job using Docker Hub

We can now submit the AzFinSim job to the pool.

```bash
#!/bin/bash

> AZ_POOL_ID=$(sb pool list -s $AZ_SUBSCRIPTION_ID -g $AZ_RESOURCE_GROUP --query "[0].id" -o tsv)
# --- or you can just manually set AZ_POOL_ID to "linux", of course!

# submit the job to generate 1000 trades, and process them using 100 concurrent tasks;
# here, we use the container image "utkarshayachit/azfinsim:main" from Docker Hub
> sb azfinsim -s $AZ_SUBSCRIPTION_ID -g $AZ_RESOURCE_GROUP  \
    -p $AZ_POOL_ID                                          \
    --num-trades 1000                                       \
    --num-tasks 100                                         \
    --algorithm "pvonly"                                    \
    --container-registry "docker.io"                        \
    --image-name "utkarshayachit/azfinsim:main"
# on successful submission, you'll get the following output
{
  "job_id": "azfinsim-[...]",
  "results_file": "/mnt/batch/tasks/fsmounts/data/azfinsim-[...]/trades.results.csv"
}
```

Now, you can browse to the batch account in Azure portal and monitor the job progress. If you look at the job's
details, you'll see about `100+3` tasks in the job. The `+3` tasks are the synthetic trades generation, split and
merge tasks. None of the tasks have started yet. This is because the pool is configured with 0 compute nodes by default. We can
change this as follows.

```bash
# resize pool
> sb pool resize -s $AZ_SUBSCRIPTION_ID -g $AZ_RESOURCE_GROUP -p $AZ_POOL_ID --target-dedicated-nodes 1
# this will block until the pool is resized and then print the following:
{
  "current_dedicated_nodes": 1,
  "current_low_priority_nodes": 0
}
```

Once the pool has resized, you'll see the tasks starting to run. You can also monitor the progress of the job on the Portal or using
Azure Batch Explorer.

To understand how to monitor the AzFinSim demo using various tools available and inspect the results, please refer to the
[understanding AzFinSim](../understanding-azfinsim.md) document.

## Step 7: Submit AzFinSim job using ACR

> **NOTE**: This is only applicable if you deployed with `enableApplicationContainers=true` parameter.
> If enableApplicationContainers=false (default), then Azure Container Registry is not deployed.
> Since this step relies on the ACR, it is not applicable in that case.

If you deployed with `enableApplicationContainers=true` parameter, then you can also submit the AzFinSim job using ACR.
But first, we need to push the container image for the AzFinSim application to the ACR we have created in our deployment.

```bash
#!/bin/bash

# fetch acr name from the deployment;
# you can also use Azure Portal to navigate to the resource group and get the 
# Azure Container Registry resource name manually
ACR_NAME=$(sb show -s $AZ_SUBSCRIPTION_ID -g $AZ_RESOURCE_GROUP --query "acr_name")

# NOTE: ACR_NAME is valid only when deployed with `enableApplicationContainers=true` parameter

# build and push the container image
az acr build                    \
    -r $ACR_NAME                \
    -t azfinsim/azfinsim:latest \
    "https://github.com/utkarshayachit/azfinsim#main"
# will take a few minutes to build and push the image
# output will show the build status

# on success, you can verify that the image is available in the ACR
az acr repository list -n $ACR_NAME -o tsv
# expected output
azfinsim/azfinsim
```

Now, we can submit the AzFinSim job to use the ACR image. The command is largely the same as in Step 6, except that we
don't need to specify the `--container-registry` and `--image-name` parameters since the CLI tool will automatically
use the ACR we created in the deployment.

```bash
#!/bin/bash

> AZ_POOL_ID=$(sb pool list -s $AZ_SUBSCRIPTION_ID -g $AZ_RESOURCE_GROUP --query "[0].id" -o tsv)
# --- or you can just manually set AZ_POOL_ID to "linux", of course!

# submit the job to generate 1000 trades, and process them using 100 concurrent tasks;
# here, we use the container image "utkarshayachit/azfinsim:main" from Docker Hub
> sb azfinsim -s $AZ_SUBSCRIPTION_ID -g $AZ_RESOURCE_GROUP  \
    -p $AZ_POOL_ID                                          \
    --num-trades 1000                                       \
    --num-tasks 100                                         \
    --algorithm "pvonly" 
# on successful submission, you'll get the following output
{
  "job_id": "azfinsim-[...]",
  "results_file": "/mnt/batch/tasks/fsmounts/data/azfinsim-[...]/trades.results.csv"
}
```

[examples/azfinsim-linux]: https://github.com/utkarshayachit/azbatch-starter/tree/main/examples/azfinsim-linux
