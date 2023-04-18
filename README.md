# azbatch-starter

[![validate](https://github.com/utkarshayachit/azbatch-starter/actions/workflows/validate.yaml/badge.svg)](https://github.com/utkarshayachit/azbatch-starter/actions/workflows/validate.yaml)
[![az-deploy-matrix](https://github.com/utkarshayachit/azbatch-starter/actions/workflows/az-deploy-matrix.yaml/badge.svg)](https://github.com/utkarshayachit/azbatch-starter/actions/workflows/az-deploy-matrix.yaml)
![GitHub](https://img.shields.io/github/license/utkarshayachit/azbatch-starter)

> __Warning__
> This repository is under development, as is this document. Expect everything to change until the first version is ready.

## Overview

This project deploys all resources necessary to use Azure Batch in a configuration that follows best-practices to minimize
exposing access to the compute resources. It is designed with financial applications in mind, where compute environments
are often restricted or locked down. That being said, the configuration of resources deployed is applicable a broad set of
applications and domains beyond FinTech.

The goal of this project is to provide a starting point for deploying Azure Batch in a manner that follows best practices
and security guidelines. The project is designed to be easily customizable to fit the needs of the user or applications
they want to run on Azure Batch. The project is designed to be used as a starting point for a more complex deployment
that may require additional resources or customization.

## Design

The repository contains Bicep code that can be used to deploy resources to Azure. The deployment can be customized in two ways:
First, you can pass parameters to the main deployment script ([`infrastructure.bicep`](./infrastructure.bicep)) when triggering the
deployment using Azure CLI. These parameters are intentionally minimal and provide coarse customization e.g. specifying
prefix for all resource groups. Second, you can edit JSON configuration files under [`./config`](./config/) that let you
customize the deployed resources even more e.g. define how many pools to add to the batch account and their types, SKUs,
virtual machine images to use etc.

### Parameters

Let's start by looking at the available parameters and their usage.

* __batchServiceObjectId__ (REQUIRED): batch service object id; this cab be obtained by executing the following command in
  Azure Cloud Shell with Bash (or similar terminal):
   `az ad sp list --display-name "Microsoft Azure Batch" --filter "displayName eq 'Microsoft Azure Batch'" | jq -r '.[].id'`.
* __environment__: a short string used to identify the deployment environment; for example, one can use this parameter to
  distinguish between production and development deployments; initialized to 'dev', by default.
* __prefix__: a short string as a prefix for resources groups and other subscription level resources created
* __location__: a string identifying the location for all the resources; initialized to the deployment location, by default.
* __enableApplicationPackages__: when set to `true` additional resources will be deployed to support
  [Batch application packages](https://learn.microsoft.com/en-us/azure/batch/batch-application-packages); initialized to
  `false`, by default.
* __enableApplicationContainers__: when set to `true` additional resources will be deployed to support running jobs
  that use [containerized applications](https://learn.microsoft.com/en-us/azure/batch/batch-docker-container-workloads);
  initialized to `false`, by default.
* __tags__: an object to add as tags to all resources created; initialized to `{}` by default.
* __suffixSalt__: a random string used to generate a resource group suffix; primarily intended for automated testing
  to separate resources deployed by different workflows.

### Configuration files

The configuration files offer a more fine-grained control over the deployment. At first, they can appear daunting, however,
the things that one may needs to modify, in practice, should be quite limited.
The config files are JSON files stored under [`./config`](./config/) directory. To customize a deployment,
you can modify these configuration files.

Let's look at each of these files and what's their purpose. The order in which they are described here is perhaps a good
order to follow when modifying them for a new deployment.

* [__spoke.jsonc__](./config/spoke.jsonc):  This file specifies the configuration for the virtual network. It's good to
  start here since this defines the communication network over which all deployed resources can be accessed and
  will communicate with each other. There are two main things to think about here. First, the subsets and their address
  prefixes and second, the network security rules for the subnets. `private-endpoints` subnet is required and is the subnet
  that is used to deploy all private endpoints for various resources in the deployment. In addition, you can define arbitrarily
  many subnets. These subnets can be associated with specific pools later on. Once you have named the subnets, you need specify
  network security rules for each of them. These rules define what traffic is allowed to and from the subnet. The default
  configuration defines two pools, one intended for Linux node pools and another for Windows and then sets up rules appropriate
  for the two types of pools. The default rules explicitly restrict communication between subnets to only allow the required
  channels.

* [__storage.jsonc__](./config/storage.jsonc): The next thing to define are the storage accounts that we need the
  compute nodes to have access to. Pools can be setup to auto-mount the storage accounts defined here so that jobs can
  access them to read data or write results. Storage accounts are not required, of course. Your jobs could, for example,
  connect to a database or redis cache to read/write data. In which case this file can simply be an empty JSON object i.e. `{}`.
  You can define multiple blob/containers or file shares in this file. When defining pools, we reference
  the names assigned to storage accounts and containers/shares here.

* [__batch.jsonc__](./config/batch.jsonc): This is perhaps the most important configuration file that describes
  the configuration of the Batch account itself. This is where you choose the pool allocation mode to use for the
  Batch account and then setup the pools. You can define arbitrarily many pools. For each pool, you specify the virtual
  machine SKUs and images ([`images.json`](./config/images.jsonc)) to use for the nodes in pool,
  the subnet to use ([`spoke.jsonc`](./config/spoke.jsonc))
  and storage accounts to mount ([`storage.jsonc`](./config/storage.jsonc)).
  If your jobs need MPI for distributed processing, then you can also enable internode communication for individual pools.

* [__hub.jsonc__](./config/hub.jsonc): This file is intended to provide information about resources typically deployed
  in a hub in what is referred to as a hub-and-spoke network configuration. These are often shared resources like
  VPN Gateway, Firewall, Azure Log Analytics Workspace etc. This configuration file is used to pass information about
  these resources. This is also used to pass information about virtual networks to peer with the spoke virtual network.

* [__images.jsonc__](./config/images.jsonc): This file defines virtual images that may be used in pools referenced
  when defining pools in `batch.jsonc`.

JSON schemas that can be used to validate these configuration files are provided under [`./schemas`](./schemas/). Note since
the configuration files include comments and most JSON validation tools (e.g. `jsonschema`) do not support validating JSON
with comments, you will have to strip the comments before running the validation tool. For example,

```bash
# remove comments
> sed 's/\/\/\/.*$//' ./config/batch.jsonc > /tmp/batch.json

# validate
> jsonschema -i /tmp/batch.json ./schemas/batch.schema.json
```

## Prerequisites

Before you can try any of the demos, you first need to deploy the infrastructure on Azure.
This section takes you through the steps involved in making a deployment.

1. __Ensure valid subscription__: Ensure that you a chargeable Azure subscription that you
   can use and you have __Owner__ access to the subscription.

2. __Accept legal terms__: The demos use container images that require you to accept
   legal terms. This only needs to be done once for the subscription. To accept these legal terms,
   you need to execute the following Azure CLI command once. You can do this using the
   [Azure Cloud Shell](https://ms.portal.azure.com/#cloudshell/) in the [Azure portal](https://ms.portal.azure.com)
   or your local computer. To run these commands on your local computer, you must have Azure CLI installed.

   ```sh
   # For Azure Cloud Shell, pick Bash (and not powershell)
   # If not using Azure Cloud Shell, use `az login` to login if needed.

   # accept image terms
   az vm image terms accept --urn microsoft-azure-batch:ubuntu-server-container:20-04-lts:latest
   ```

3. __Get Batch Service Id__: Based on your tenant, which may be different, hence it's
   best to confirm. In [Azure Cloud Shell](https://ms.portal.azure.com/#cloudshell/),
   run the following:

   ```sh
    az ad sp list --display-name "Microsoft Azure Batch" --filter "displayName eq 'Microsoft Azure Batch'" | jq -r '.[].id'

    # output some alpha numeric string e.g.
    f520d84c-3fd3-4cc8-88d4-2ed25b00d27a
   ```

   Save the value shown then you will need to enter that value,
   instead of the default, for `batchServiceObjectId` (shown as __Batch Service Object Id__,
   if deploying using the portal) when deploying the infrastructure.

   If the above returns an empty string, you may have to register "Microsoft.Batch" as a registered
   resource provider for your subscription. You can do that using the portal, browse to your `Subscription >
   Resource Providers` and then search for `Microsoft.Batch`. Or use the following command and then try
   the `az ad sp list ...` command again

   ```sh
   az provider register -n Microsoft.Batch --subscription <your subscription name> --wait
   ```

4. __Ensure Batch service has authorization to access your subscription__. Using the portal,
   access your Subscription and select the __Access Control (IAM)__ page. Under there, we need to assign
  __Contributor__ or __Owner__ role to the Batch API. You can find this account by searching for
  __Microsoft Azure Batch__ (application ID should be __ddbf3205-c6bd-46ae-8127-60eb93363864__). For additional
  details, see [this](https://learn.microsoft.com/en-us/azure/batch/batch-account-create-portal#allow-azure-batch-to-access-the-subscription-one-time-operation).

5. __Validate Batch account quotas__: Ensure that the region you will deploy under has
   not reached its batch service quota limit. Your subscription may have limits on
   how many batch accounts can be created in a region. If you hit this limit, you
   may have to delete old batch account, or deploy to a different region, or have the
   limit increased by contacting your administrator.

6. __Validate compute quotas__: Ensure that the region you will deploy under has not
   sufficient quota left for the SKUs picked for batch compute nodes. The AzFinSim
   and LULESH-Catalyst demos use `Standard_D2S_V3` while the trame demo uses
   `Standard_DS5_V2` by default. You can change these by modifying the configuration
   file [`batch.jsonc`](config/batch.jsonc).

## Deployment

Following shows the command to make a deployment. Modify the configuration files to your liking first and then
use the following command. You can specify parameters for the deployment (described earlier) to customize the deployment.
This requires Azure CLI with Bicep support. As before, you can simply use the Azure Cloud Shell if you're not sure about the
packages installed on your workstation.

```bash
# assuming bash (on Linux or using WSL2 on Windows)
# change commands appropriately on PowerShell or other Windows terminal 
> AZ_BATCH_SERVICE_OBJECT_ID=$(az ad sp list --display-name "Microsoft Azure Batch" --filter "displayName eq 'Microsoft Azure Batch'" | jq -r '.[].id')
> AZ_LOCATION="westus2"
> AZ_PREFIX="uda20230321a"  # e.g "<initials><date><suffix>"
> AZ_DEPLOYMENT_NAME="azbatch-starter-$AZ_LOCATION"
> az deployment sub create --location $AZ_LOCATION  \
      --name $AZ_DEPLOYMENT_NAME                    \
      --template-file infrastructure.bicep          \
      --parameters                                  \
        prefix=$AZ_PREFIX                           \
        batchServiceObjectId=$AZ_BATCH_SERVICE_OBJECT_ID # <... add any other parameters are key=value here....>
```

## Testing / Validating the Deployment

On successful deployment, use the following command to get information from the deployment

```bash
# Get the batch account endpoint
> AZ_BATCH_ACCOUNT_ENDPOINT=$(az deployment sub show --name $AZ_DEPLOYMENT_NAME -o tsv --query properties.outputs.batchAccountEndpoint.value)

# Get the batch account resource group name
> AZ_BATCH_ACCOUNT_RESOURCE_GROUP=$( az deployment sub show --name $AZ_DEPLOYMENT_NAME -o tsv --query properties.outputs.batchAccountResourceGroup.value)

# Get the batch account resource name
> AZ_BATCH_ACCOUNT_NAME=$(az deployment sub show --name $AZ_DEPLOYMENT_NAME -o tsv --query properties.outputs.batchAccountName.value)
```

To make it easier to execute batch commands using CLI, let's login to the batch account first.

```bash
# Login to batch account
az batch account login --name $AZ_BATCH_ACCOUNT_NAME --resource-group $AZ_BATCH_ACCOUNT_RESOURCE_GROUP
```

Let's confirm that pools were created as expected. The default configuration creates two pools named `windows` and `linux`. Let's confirm that.

```bash
# list pools and show their names
az batch pool list | jq -r ".[].id"

# expected output:
linux
windows
```

## Understanding the default configuration

The default configuration is setup to deploy an environment that can be used to run various workloads described under Demos / Applications section below. To better understand how to customize the deployment, let's look at the default configuration
in more detail.

* [`spoke.jsonc`](config/spoke.jsonc) contains the configuration for the spoke VNet. We define a vnet with address space
  `10.121.0.0/16` and three subnets. The `private-endpoints` subnet is required and used to deploy private endpoints for all
  resources that support it in our deployment. Private endpoints are used to access resources from within the VNet without
  exposing them to the public internet. In this deployment, we decided to define two additional subnets, `pool-linux` and
  `pool-windows` to be used for the batch pools that use Linux and Windows nodes respectively. When customizing the deployment,
  you can changes these or add additional subnets as needed.

  Once we have defined the subnets, we need to define the NSG rules for each subnet. The default configuration defines
  rules to lock down all communication except the ones explicitly needed to support core functionality. You can customize
  these rules as needed.

* [`storage.jsonc`](./config/storage.jsonc) defines the storage accounts we want to mount on all pools. These are totally
  optional. Your applications, for example, may be using a network database instead e.g. a redis cache, or Cosmos DB. In
  that case, you can skip this configuration and leave it empty. For other cases where you want to read data from shared storage
  or produce results on a shared storage, you can define the storage accounts here. The default configuration defines
  two storage accounts, one for blob storage and one for file storage. Blob storage can only be mounted on Linux nodes
  while file storage can be mounted on both Linux and Windows nodes.

* [`batch.jsonc`](./config/batch.jsonc) defines the batch account and pools. We start by defining the batch account configuration.
  `poolAllocationMode` is set to `UserSubscription` to ensure that the pools are created in the same subscription as the
  batch account. This is preferred for deployment where you don't want to share compute resources with other users. `publicNetworkAccess` determines from which networks users can access the resource like batch account, container registry
  for management. `auto` indicates that the resources will be made accessible from public network unless peering with a hub
  VNet is configured (in hub.jsonc).

  Next, we define the pools. The default configuration defines two pools, one for Linux nodes and one for Windows nodes.
  The pools are configured to use the subnets defined in the spoke configuration. The pools are also configured to mount
  the storage accounts defined in the storage configuration. The pools are also configured to use the default image
  for the respective OS. You can customize these as needed in [`images.jsonc`](./config/images.jsonc).

* [`hub.jsonc`](./config/hub.jsonc) is intended to pass information about resources deployed externally to this deployment.
  For example, if you have an existing hub VNet that you want to peer with the spoke VNet deployed by this deployment, you
  can specify the hub VNet information here. The default configuration is empty with placeholder for locations where you can
  specify the details about diagnostics resources, vnet peerings, user-defined-routes for firewalls, etc.

* [`images.jsonc`](./config/images.jsonc) defines the default OS images to use for the pools. The default configuration
  defines the default images for the a version of Windows Server and Ubuntu Server. You can customize these as needed.

## Example Configurations

In addition to the default configuration, we also provide a few example configurations that demonstrate how to customize
the deployment to meet specific needs. These are documented [here](./examples/README.md). To use any of these
example configurations, you
can copy the configuration files to the `config` directory and modify them as needed.

## CLI

One the deployment is complete, one can use the Azure Portal or Azure CLI to interact with the resources
to do various tasks like resizing batch pools, submitting jobs etc.

You can also use CLI tool developed specifically for this project to make it easier to work with the deployment
and included demos. The tool also demonstrate how one can develop such tools to make it easy for non-expert users to
interact with your specific deployments to perform common tasks with ease.

Installation instructions and usage is documented [here](./cli/README.md).

## Demos / Applications

Once the deployment is complete, you can try various demos and applications. These demonstrate how the batch account together with
various resources deployed in our deployment can be used to run various workloads. The following demos are available:

* [AzFinSim](./demos/azfinsim/README.md): This is a financial simulation application that uses Azure Batch to run option risk analysis
  workloads.
* [LULESH](./demos/lulesh-catalyst/README.md): This is a scientific simulation mini-app that uses Azure Batch to run MPI-based
  workloads. (placeholder: not yet availble)

## Developer Guidelines

1. When naming resources, use `${suffix}` passed into each module deployed by the `infrastructure.bicep`. The suffix is generated
   using `-${uniqueString(deployment().name, location, prefix, suffixSalt)}`. We use a suffix instead of prefix to name resources
   so that when viewing resources in the resource group, it's easier to read and identify resources in the resource names column.
2. For globally unique resource names, use `resourceGroup().id` and `suffix` to generate a `GUID`. Never use deployment name.
3. For nested deployments, use a deployment name suffix generated using `uniqueString(resourceGroup().id, deployment().name, location)`.
   i.e. always include deployment name in it.

## License

Copyright (c) Microsoft Corporation. All rights reserved.

Licensed under the [MIT License](./LICENSE)
