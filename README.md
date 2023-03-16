# azbatch-starter

[![validate](https://github.com/utkarshayachit/azbatch-starter/actions/workflows/validate.yaml/badge.svg)](https://github.com/utkarshayachit/azbatch-starter/actions/workflows/validate.yaml)
[![az-deploy-matrix](https://github.com/utkarshayachit/azbatch-starter/actions/workflows/az-deploy-matrix.yaml/badge.svg)](https://github.com/utkarshayachit/azbatch-starter/actions/workflows/az-deploy-matrix.yaml)
![GitHub](https://img.shields.io/github/license/utkarshayachit/azbatch-starter)

## Preamble

This repository is under development, as is this document. Expect everything to change
until the first version is ready.

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

## NSG Rules

1. NFS 3.0:
  - uses port 111 and 2048
  - enable outgoing traffic on port 111 and 2048 for pool vnets and incoming on
    private endpoints vnet
2. Azure Files
  - docs says 443 in/out from Storage. With private endpoints, we need to use VirtualNetwork
    tag instead
