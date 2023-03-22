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

* [__nsgRules.jsonc__](config/nsgRules.jsonc): This file defines the NSG rules referenced in `spoke.json`.

## License

Copyright (c) Microsoft Corporation. All rights reserved.

Licensed under the [MIT License](./LICENSE)

## Prerequisites

* The account creating the deployment needs to have **Owner** role on the subscription. This is essential to assign the
  correct roles to the resources being deployed. **Contributor** role is not adequate since that does not allow us to assign
  roles to the managed identity created by the deployment.

## Quickstart

(not full instructions yet)

Steps to make a deployment:

```bash
# assuming bash (on Linux or using WSL2 on Windows)
# change commands appropriately on PowerShell or other Windows terminal 
> AZ_BATCH_SERVICE_OBJECT_ID=$(az ad sp list --display-name "Microsoft Azure Batch" --filter "displayName eq 'Microsoft Azure Batch'" | jq -r '.[].id')
> AZ_LOCATION="westus2"
> AZ_PREFIX="uda20230321a"  # e.g "<initials><date><suffix>"
> az deployment sub create --location $AZ_LOCATION  \
      --name "azbatch-starter-$AZ_LOCATION"         \
      --template-file infrastructure.bicep          \
      --parameters                                  \
        prefix=$AZ_PREFIX                           \
        batchServiceObjectId=$AZ_BATCH_SERVICE_OBJECT_ID
```

## Developer Guidelines

1. When naming resources, use '${suffix}' passed into each module deployed by the `infrastructure.bicep`. The suffix is generated
   using `-${uniqueString(deployment().name, location, prefix, suffixSalt)}`. We use a suffix instead of prefix to name resources
   so that when viewing resources in the resource group, it's easier to read and identify resources in the resource names column.
2. For globally unique resource names, use `resourceGroup().id` and `suffix` to generate a `GUID`. Never use deployment name.
3. For nested deployments, use a deployment name suffix generated using `uniqueString(resourceGroup().id, deployment().name, location)`.
   i.e. always include deployment name in it.
