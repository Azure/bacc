# Tutorial: AzFinSim on Linux pool with Containers

This tutorial is a step-by-step guide on how to run AzFinSim on a Linux pool with containers.
This is also intended as the main demo for AzFinSim application and is a good place
to start if you are new to AzFinSim or Azure Batch.

This tutorial has two variants: using Docker Hub and using Azure Container Registry (ACR).
The Docker Hub variant is simpler and is recommended for first time users. Steps below describe the Docker Hub variant.
For those steps that are different for ACR variant, we have provided a note.

For this tutorial, we will use configuration files from [examples/azfinsim-linux] folder.
The `deployment.bicep` is the entry point for this deployment and `config.jonc` is the configuration file that contains all the
resource configuration parameters for this deployment.

## Key Design Elements

* Uses Azure Batch service deployed with pool allocation mode set to **Batch Service**.
* AzFinSim application is packaged as a container image. The container image is pulled from either from
  Docker Hub repository or Azure Container Registry (ACR) depending on the deployment configuration.

## Architecture

The following diagram shows the architecture of the deployment.

![AzFinSim on Linux pool with containers](./azfinsim-linux.png)

## Step 1: Prerequisites and environment setup

Follow the [environment setup instructions](./environment-setup.md) to set up your environment. Since
this tutorial uses **Batch Service** pool allocation mode, you can skip the **User Subscription** specific
requirements and steps described in that document.

## Step 2: Deploy resources to Azure

For this step, you have two options. You can use Azure CLI to deploy the resources using the bicep template provided. Or you can
simply click the following link to deploy using Azure Portal.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fbacc%2Fmain%2Ftemplates%2Fazfinsim-linux_deploy.json)

Use the following steps to deploy using Azure CLI.

```bash
#!/bin/bash

# create deployment
AZ_LOCATION=eastus2
AZ_DEPLOYMENT_NAME=azfinsim0
AZ_RESOURCE_GROUP=azfinsim0

# change directory to bacc (or where you cloned/downloaded the repository)
cd bacc

az deployment sub create                                      \
  --name $AZ_DEPLOYMENT_NAME                                  \
  --location $AZ_LOCATION                                     \
  --template-file examples/azfinsim-linux/deployment.bicep    \
  --parameters                                                \
      resourceGroupName=$AZ_RESOURCE_GROUP
```

On success, a new resource group will be created with the name specified. This resource group will contain all the resources
deployed by this deployment.

If you want to also test with ACR instead or in addition to Docker Hub, then use the following command to create the
deployment instead i.e. simply add the `enableApplicationContainers=true` parameter.

```bash
#!/bin/bash

az deployment sub create                                      \
  --name $AZ_DEPLOYMENT_NAME                                  \
  --location $AZ_LOCATION                                     \
  --template-file examples/azfinsim-linux/deployment.bicep    \
  --parameters                                                \
      resourceGroupName=$AZ_RESOURCE_GROUP                    \
      enableApplicationContainers=true
```

## Step 3: Install CLI

Next, we install the CLI tool provided by this repository. This tool is used to submit jobs and tasks to the batch account.
We recommend using a python virtual environment to install the CLI tool to avoid polluting the global python environment.

Follow the steps described [here](../cli.md#installation) to install the CLI tool.

## Step 4: Verify deployment

We can the CLI tool deployed in previous step to verify the deployment.

```bash
#!/bin/bash

# fetch subscription id from the portal or using the following command
# if you have already logged in to Azure CLI using `az login` command
AZ_SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# set resource group name to the one used in Step 2
AZ_RESOURCE_GROUP=azfinsim0 # or whatever you used in Step 2

# use the `bacc show` command
bacc show -s $AZ_SUBSCRIPTION_ID -g $AZ_RESOURCE_GROUP
# on success, you'll get the following output
{
  "acr_name": null,
  "batch_endpoint": "https://......batch.azure.com"
}

# if you deployed with `enableApplicationContainers=true` parameter, then the `acr_name`
# will be a valid URL instead of `null`.

# To list all available pools, use the `bacc pool list` command
bacc pool list -s $AZ_SUBSCRIPTION_ID -g $AZ_RESOURCE_GROUP \
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

## Step 5: Submit AzFinSim job using Docker Hub

We can now submit the AzFinSim job to the pool.

```bash
#!/bin/bash

AZ_POOL_ID=$(bacc pool list -s $AZ_SUBSCRIPTION_ID -g $AZ_RESOURCE_GROUP --query "[0].id" -o tsv)
# --- or you can just manually set AZ_POOL_ID to "linux", of course!

# submit the job to generate 1000 trades, and process them using 100 concurrent tasks;
# here, we use the container image "utkarshayachit/azfinsim:main" from Docker Hub
bacc azfinsim -s $AZ_SUBSCRIPTION_ID -g $AZ_RESOURCE_GROUP  \
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
bacc pool resize -s $AZ_SUBSCRIPTION_ID -g $AZ_RESOURCE_GROUP -p $AZ_POOL_ID --target-dedicated-nodes 1
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

## Step 6: Submit AzFinSim job using ACR

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
ACR_NAME=$(bacc show -s $AZ_SUBSCRIPTION_ID -g $AZ_RESOURCE_GROUP --query "acr_name")

# NOTE: ACR_NAME is valid only when deployed with `enableApplicationContainers=true` parameter

# NOTE: if you're running this on a Jumpbox VM e.g. for the Secured-Batch tutorial,
# then you'll need to login to CLI using the VM's identity. You can do that as follows:
# > az login --identity

# import prebuilt image from Docker Hub to ACR
az acr import \
   --name $ACR_NAME \
   --source docker.io/utkarshayachit/azfinsim:main \
   --image azfinsim/azfinsim:latest

# You can also use `az acr build .. ` instead to build a container image from source code
# and push it to the ACR. For more details, refer to Azure CLI documentation.

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

AZ_POOL_ID=$(bacc pool list -s $AZ_SUBSCRIPTION_ID -g $AZ_RESOURCE_GROUP --query "[0].id" -o tsv)
# --- or you can just manually set AZ_POOL_ID to "linux", of course!

# submit the job to generate 1000 trades, and process them using 100 concurrent tasks;
# here, we use the container image "utkarshayachit/azfinsim:main" from Docker Hub
bacc azfinsim -s $AZ_SUBSCRIPTION_ID -g $AZ_RESOURCE_GROUP  \
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

[examples/azfinsim-linux]: https://github.com/Azure/bacc/tree/main/examples/azfinsim-linux
