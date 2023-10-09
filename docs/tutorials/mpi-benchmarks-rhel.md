# Tutorial: MPI Benchmarks on RHEL

This tutorial is a step-by-step guide on how to run MPI benchmarks on Azure Batch on RHEL 8 compute nodes.
This is a good place to start for any one looking into using MPI applications on Azure Batch.

This tutorial uses configuration files from [examples/mpi-benchmarks-rhel] folder.
The `deployment.bicep` is the entry point for this deployment and `config.jonc` is the configuration file that contains all the
resource configuration parameters for this deployment.

## Key Design Elements

* Uses Azure Batch service deployed with pool allocation mode set to **User Subscription**. 
* Default config is setup to use HBv3 SKUs which are intended for use for MPI applications. Besides other advantages, these SKUs
  provide InfiniBand networking for low-latency, high-bandwidth communication between compute nodes.
  You can change this by modifying the `config.json` file.
* Uses RHEL 8.4 as the OS for compute nodes. This demo intentionally uses a vanilla RHEL 8.4 image without any additional
  software installed. This is to demonstrate how to install and use Infiniband drivers and MPI implementations
  on compute nodes. This demo relies on the compute node startup script to install the required software.

## Step 1: Prerequisites and environment setup

Follow the [environment setup instructions](./environment-setup.md) to set up your environment. Since
this tutorial uses **User Subscription** pool allocation mode, you will need to follow the steps described in that document.

## Step 2: Deploy resources to Azure

For this step, you have two options. You can use Azure CLI to deploy the resources using the bicep template provided. Or you can
simply click the following link to deploy using Azure Portal.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Futkarshayachit%2Fazbatch-starter%2Fmain%2Ftemplates%2Fmpi-benchmarks_deploy.json)

Use the following steps to deploy using Azure CLI.

```bash
#!/bin/bash

# create deployment
AZ_LOCATION=eastus
AZ_DEPLOYMENT_NAME=mpi-benchmarks0
AZ_RESOURCE_GROUP=mpi-benchmarks0
BATCH_SERVICE_OBJECT_ID= ....  # should be set to the id obtained in prerequisites step

# change directory to azbatch-starter (or where you cloned/downloaded the repository)
cd azbatch-starter

az deployment sub create                                      \
  --name $AZ_DEPLOYMENT_NAME                                  \
  --location $AZ_LOCATION                                     \
  --template-file examples/mpi-benchmarks/deployment.bicep    \
  --parameters                                                \
      resourceGroupName=$AZ_RESOURCE_GROUP                    \
      batchServiceObjectId=$BATCH_SERVICE_OBJECT_ID
```

On success, a new resource group will be created with the name specified. This resource group will contain all the resources
deployed by this deployment.

## Step 3: Install CLI

Next, we install the CLI tool provided by this repository. This tool is used to submit jobs and tasks to the batch account.
We recommend using a python virtual environment to install the CLI tool to avoid polluting the global python environment.

Follow the steps described [here](../cli.md#installation) to install the CLI tool.

## Step 4: Verify deployment

Once the deployment is complete, you can verify the deployment by listing the compute nodes in the pool.

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

# To list all available pools, use the `bacc pool list` command
bacc pool list -s $AZ_SUBSCRIPTION_ID -g $AZ_RESOURCE_GROUP \
    --query "[].{pool_id:id, vm_size:vmSize, state:allocationState}"
# expected output
[
  {
    "pool_id": "linux-HBv3",
    "state": "steady",
    "vm_size": "standard_hb120rs_v3"
  }
]
```

## Step 5: Submit jobs

Before we submit jobs, we need to resize the pool to the desired size. This is because the default pool size is set to 0.
For this MPI application demo, we need at least 2 nodes. So we resize the pool to 2 nodes.

```bash
# resize pool
bacc pool resize -s $AZ_SUBSCRIPTION_ID -g $AZ_RESOURCE_GROUP -p $AZ_POOL_ID --target-dedicated-nodes 2
# this will block until the pool is resized and then print the following:
{
  "current_dedicated_nodes": 2,
  "current_low_priority_nodes": 0
}
```

The resize can take anywhere from 5-10 minutes. During this time, the nodes get provisioned and the startup script is executed.
The startup script installs the required software on the nodes. Once the pool is resized, we can submit jobs to the pool.

```bash

# submit job
bacc mpi-bm imb -s $AZ_SUBSCRIPTION_ID -g $AZ_RESOURCE_GROUP \
    --num-nodes 2 --num-ranks 2 \
    -e IMB-MPI1 -a PingPong
# expected output
{
    "job_id": "imb-mpi1-pingpong-[...]",
}
```

You should now be able to browse to the listed job using Azure Portal or Batch explorer. Once the job has completed, you can
inspect (or download) the stdout/stderr files for the tasks to see the output of the benchmark. Following is an example output
from one of the tasks.

```txt
# stdout.txt

#----------------------------------------------------------------
#    Intel(R) MPI Benchmarks 2021.3, MPI-1 part
#----------------------------------------------------------------
# Date                  : Mon Sep 25 12:11:23 2023
# Machine               : x86_64
# System                : Linux
# Release               : 4.18.0-305.88.1.el8_4.x86_64
# Version               : #1 SMP Thu Apr 6 10:22:46 EDT 2023
# MPI Version           : 3.1
# MPI Thread Environment: 


# Calling sequence was: 

# /mnt/intel_benchmarks/hpcx/IMB-MPI1 PingPong 

# Minimum message length in bytes:   0
# Maximum message length in bytes:   4194304
#
# MPI_Datatype                   :   MPI_BYTE 
# MPI_Datatype for reductions    :   MPI_FLOAT 
# MPI_Op                         :   MPI_SUM  
# 
# 

# List of Benchmarks to run:

# PingPong

#---------------------------------------------------
# Benchmarking PingPong 
# #processes = 2 
#---------------------------------------------------
       #bytes #repetitions      t[usec]   Mbytes/sec
            0         1000         2.24         0.00
            1         1000         2.24         0.45
            2         1000         2.21         0.90
            4         1000         2.23         1.79
            8         1000         2.22         3.60
           16         1000         2.24         7.14
           32         1000         2.26        14.18
           64         1000         2.18        29.38
          128         1000         2.29        55.89
          256         1000         2.76        92.60
          512         1000         2.83       180.93
         1024         1000         2.94       348.49
         2048         1000         3.07       666.66
         4096         1000         3.77      1086.75
         8192         1000         4.28      1912.20
        16384         1000         5.82      2816.48
        32768         1000         7.35      4459.98
        65536          640         9.84      6663.39
       131072          320        14.87      8813.43
       262144          160       127.18      2061.29
       524288           80       136.18      3850.07
      1048576           40       265.94      3942.86
      2097152           20       309.60      6773.80
      4194304           10       398.46     10526.36


# All processes entering MPI_Finalize
```

Likewise, you can run OSU benchmarks using the following command.

```bash

# submit job
bacc mpi-bm osu -s $AZ_SUBSCRIPTION_ID -g $AZ_RESOURCE_GROUP \
  -e osu_bcast -n 2 -r 64
{
  "job_id": "osu_bcast-[...]"
}
```

And here's a sample output from this tasks.

```txt
# stdout.txt

# OSU MPI Broadcast Latency Test v7.0
# Size       Avg Latency(us)
1                       3.22
2                       3.23
4                       3.21
8                       3.25
16                      3.27
32                      3.37
64                      3.37
128                     3.69
256                     3.84
512                     4.18
1024                    4.43
2048                    4.86
4096                    6.42
8192                    8.57
16384                  21.99
32768                  13.94
65536                  20.38
131072                 32.46
262144                 64.00
524288                128.05
1048576               253.97
```
