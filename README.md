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

## Configuration files

This project uses a collection of configuration files that control the resources being deployed and their configurations.
The config files are JSON files stored under `./config` directory. To customize a deployment, users can modify these configuration
files.

* [**spoke.jsonc**](./config/spoke.jsonc): This file specifies the configuration for the spoke network. All non-network
  resources deployed by this project are connected to each other over a virtual network (vnet). This vnet is designed
  such that it can easily act as a spoke in a hub-and-spoke network configuration which is typical for
  enterprise / secured deployments. This integration in a hub is not required, and it is possible to create a
  functional standalone deployment as well. The spoke, in that case, simply refers to the vnet used in the deployment
  even though it is not a part of a hub-spoke network topology.

  The [`spoke.jsonc`](./config/spoke.jsonc) configuration file enables one to fine tune the vnet.

* [**storage.jsonc**](./config/storage.jsonc): This file specifies the storage accounts to create in this deployment.
  Multiple storage accounts can be defined here. Containers/file shares from these storage accounts can be automatically
  mounted on batch pools using the batch pool configuration file.

* [**batch.jsonc**](./config/batch.jsonc): This file specifies the configuration for the batch account and related
  resources. It is used to create the batch account and the pools and other necessary resources based on the
  parameters passed to the deployment.

* [**hub.jsonc**](./config/hub.jsonc): This file specifies the configuration for the hub network. This file is
  used to provide the information about the hub network.

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
