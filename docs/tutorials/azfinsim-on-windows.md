# Tutorial: AzFinsim on Windows

This tutorial shows how to run the AzFinsim application on a Windows pool. This is a good reference for users
attempting to run applications on Windows pools in Azure Batch. This is similar to the
[AzFinsim on Linux pool with Containers](./azfinsim.md) with the difference being we use a Windows pool instead of
a Linux pool and we don't use containers.

## Key Design Considerations

* Uses Azure Batch service deployed with pool allocation mode set to **Batch Service**.
* Powershell script is used as a start task for pool to install Python and then pip install the AzFinSim application.

## Step 1: Prerequisites and environment setup

Follow the [environment setup instructions](./environment-setup.md) to set up your environment. Since
this tutorial uses **Batch Service** pool allocation mode, you can skip the **User Subscription** specific
requirements and  steps described in that document.

## Step 2: Select deployment configuration

For this tutorial, we will use configuration files from [examples/azfinsim-windows] folder.
To use these files, copy them to the config folder.

```bash
# change directory to azbatch-starter (or where you cloned/downloaded the repository)
cd azbatch-starter

# copy config files
cp examples/azfinsim-windows/* config/
```

## Step 3: Deploy the batch account and other resources

Create deployment using Azure CLI.

```bash
#!/bin/bash

# set variables for deployment
AZ_LOCATION=eastus2
AZ_DEPLOYMENT_NAME=azfinsim-win
AZ_PREFIX=azfinsim-win

az deployment sub create                \
  --name $AZ_DEPLOYMENT_NAME            \
  --location $AZ_LOCATION               \
  --template-file infrastructure.bicep  \
  --parameters                          \
      prefix=$AZ_PREFIX
```

On success, a new resource group will be created with the name `[AZ_PREFIX]-rg`. This resource group will contain all the resources
deployed by this deployment.

## Step 4: Install CLI

Next, we install the CLI tool provided by this repository. This tool is used to submit jobs and tasks to the batch account.
We recommend using a python virtual environment to install the CLI tool to avoid polluting the global python environment.

Follow the steps described [here](../cli.md#installation) to install the CLI tool.

## Step 5: Verify deployment

We can the CLI tool deployed in previous step to verify the deployment.

```bash
#!/bin/bash
> AZ_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
> AZ_RESOURCE_GROUP=$AZ_PREFIX-dev

# use the `sb show` command
> sb show -s $AZ_SUBSCRIPTION_ID -g $AZ_RESOURCE_GROUP
# on success, you'll get the following output
{
  "acr_name": null,
  "batch_endpoint": "https://......batch.azure.com"
}

# To list all available pools, use the `sb pool list` command
> sb pool list -s $AZ_SUBSCRIPTION_ID -g $AZ_RESOURCE_GROUP \
    --query "[].{pool_id:id, vm_size:vmSize, state:allocationState}"
# expected output
[
  {
    "pool_id": "windows",
    "state": "steady",
    "vm_size": "standard_ds5_v2"
  }
]
```

## Step 6: Submit AzFinSim job

We can now submit the AzFinSim job to the pool.

```bash
#!/bin/bash

> AZ_POOL_ID=$(sb pool list -s $AZ_SUBSCRIPTION_ID -g $AZ_RESOURCE_GROUP --query "[0].id" -o tsv)
# --- or you can just manually set AZ_POOL_ID to "linux", of course!

# submit the job to generate 1000 trades, and process them using 100 concurrent tasks;
> sb azfinsim -s $AZ_SUBSCRIPTION_ID -g $AZ_RESOURCE_GROUP  \
    -p $AZ_POOL_ID                                          \
    --mode package                                          \
    --num-trades 1000                                       \
    --num-tasks 100                                         \
    --algorithm "pvonly" 
# on successful submission, you'll get the following output
{
  "job_id": "azfinsim-[...]",
  "results_file": "l:/azfinsim-[...]/trades.results.csv"
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

[examples/azfinsim-windows]: https://github.com/utkarshayachit/azbatch-starter/tree/main/examples/azfinsim-windows
