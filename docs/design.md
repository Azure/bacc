# Design

The repository contains Bicep code that can be used to deploy resources to Azure. The deployment can be customized in two ways:
First, you can pass parameters to the main deployment script ([infrastructure.bicep]) when triggering the
deployment using Azure CLI. These parameters are intentionally minimal and provide coarse customization e.g. specifying
the resource group name. Second, you can edit JSON configuration files under [config/] that let you
customize the deployed resources even more e.g. define how many pools to add to the batch account and their types, SKUs,
virtual machine images to use etc.

## Parameters

Let's start by looking at the available parameters and their usage. Parameters are passed to the
`az deployment sub create ...` command when creating a deployment either explicitly or by using a json file.

| Parameter | Default | Description |
| --- | --- | --- |
|__resourceGroupName__| `[REQUIRED]` | name to use for the resource group to create to hold all resources in this deployment.|
| __batchServiceObjectId__| `(empty)` |  batch service object id; this cab be obtained by executing the following command in Azure Cloud Shell with Bash (or similar terminal): `az ad sp list --display-name "Microsoft Azure Batch" --filter "displayName eq 'Microsoft Azure Batch'" \| jq -r '.[].id'`; this is __REQUIRED__ when the [batch config][batch.jsonc] specifies `poolAllocationMode` as `UserSubscription`; can be omitted otherwise.
|__enableApplicationPackages__| `false`| when set to `true` additional resources will be deployed to support [Batch application packages](https://learn.microsoft.com/en-us/azure/batch/batch-application-packages). |
|__enableApplicationContainers__| `false` | when set to `true` additional resources will be deployed to support running jobs that use [containerized applications](https://learn.microsoft.com/en-us/azure/batch/batch-docker-container-workloads). |
|_location_| `deployment location` | a string identifying the location for all the resources. |
|_tags_| `{}` | an object to add as tags to all resources created; initialized to `{}` by default. |
|_suffixSalt_| `(empty)` | a random string used to generate a resource group suffix; internal; primarily intended for automated testing to separate resources deployed by different workflows. NOT FOR GENERAL PUBLIC USE.|

## Configuration files

The configuration files offer a more fine-grained control over the deployment. At first, they can appear daunting, however,
the things that one may needs to modify, in practice, should be quite limited.
The config files are JSON files stored under [config/] directory. To customize a deployment,
you can modify these configuration files.

Let's look at each of these files and what's their purpose. The order in which they are described here is perhaps a good
order to follow when modifying them for a new deployment.

* [__spoke.jsonc__][spoke.jsonc]:  This file specifies the configuration for the virtual network. It's good to
  start here since this defines the communication network over which all deployed resources can be accessed and
  will communicate with each other. There are two main things to think about here. First, the subsets and their address
  prefixes and second, the network security rules for the subnets. `private-endpoints` subnet is required and is the subnet
  that is used to deploy all private endpoints for various resources in the deployment. In addition, you can define arbitrarily
  many subnets. These subnets can be associated with specific pools later on. Once you have named the subnets, you need specify
  network security rules for each of them. These rules define what traffic is allowed to and from the subnet. The default
  configuration defines two pools, one intended for Linux node pools and another for Windows and then sets up rules appropriate
  for the two types of pools. The default rules explicitly restrict communication between subnets to only allow the required
  channels.

* [__storage.jsonc__][storage.jsonc]: The next thing to define are the storage accounts that we need the
  compute nodes to have access to. Pools can be setup to auto-mount the storage accounts defined here so that jobs can
  access them to read data or write results. Storage accounts are not required, of course. Your jobs could, for example,
  connect to a database or redis cache to read/write data. In which case this file can simply be an empty JSON object i.e. `{}`.
  You can define multiple blob/containers or file shares in this file. When defining pools, we reference
  the names assigned to storage accounts and containers/shares here.

* [__batch.jsonc__][batch.jsonc]: This is perhaps the most important configuration file that describes
  the configuration of the Batch account itself. This is where you choose the pool allocation mode to use for the
  Batch account and then setup the pools. You can define arbitrarily many pools. For each pool, you specify the virtual
  machine SKUs and images ([`images.json`][images.jsonc]) to use for the nodes in pool,
  the subnet to use ([`spoke.jsonc`][spoke.jsonc])
  and storage accounts to mount ([`storage.jsonc`][storage.jsonc]).
  If your jobs need MPI for distributed processing, then you can also enable internode communication for individual pools.

* [__hub.jsonc__][hub.jsonc]: This file is intended to provide information about resources typically deployed
  in a hub in what is referred to as a hub-and-spoke network configuration. These are often shared resources like
  VPN Gateway, Firewall, Azure Log Analytics Workspace etc. This configuration file is used to pass information about
  these resources. This is also used to pass information about virtual networks to peer with the spoke virtual network.

* [__images.jsonc__][images.jsonc]: This file defines virtual images that may be used in pools referenced
  when defining pools in [`batch.jsonc`][batch.jsonc].

JSON schemas that can be used to validate these configuration files are provided under [schemas/].
Note since the configuration files include comments and most JSON validation tools (e.g. `jsonschema`)
do not support validating JSON with comments, you will have to strip the comments before running the validation tool.
For example,

```bash
# remove comments
> sed 's/\/\/\/.*$//' ./config/batch.jsonc > /tmp/batch.json

# validate
> jsonschema -i /tmp/batch.json ./schemas/batch.schema.json
```

## Deployment

Following shows the command to make a deployment. Modify the configuration files to your liking first and then
use the following command. You can specify parameters for the deployment (described earlier) to customize the deployment.
This requires Azure CLI with Bicep support. As before, you can simply use the Azure Cloud Shell if you're not sure about the
packages installed on your workstation.

```bash
#!/bin/bash
# assuming bash (on Linux or using WSL2 on Windows)
# change commands appropriately on PowerShell or other Windows terminal 

AZ_BATCH_SERVICE_OBJECT_ID=$(az ad sp list --display-name "Microsoft Azure Batch" --filter "displayName eq 'Microsoft Azure Batch'" --query "[].id" -o tsv)

# values for the following variables are provided as examples
AZ_LOCATION="westus2"
AZ_RESOURCE_GROUP="uda20230321a"  # e.g "<initials><date><suffix>"
AZ_DEPLOYMENT_NAME="azbatch-starter-$AZ_LOCATION"

az deployment sub create --location $AZ_LOCATION  \
      --name $AZ_DEPLOYMENT_NAME                    \
      --template-file infrastructure.bicep          \
      --parameters                                  \
        resourceGroupName=$AZ_RESOURCE_GROUP        \
        batchServiceObjectId=$AZ_BATCH_SERVICE_OBJECT_ID  # ...
          # <... add any other parameters are key=value here....>
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

* [spoke.jsonc] contains the configuration for the spoke VNet. We define a vnet with address space
  `10.121.0.0/16` and three subnets. The `private-endpoints` subnet is required and used to deploy private endpoints for all
  resources that support it in our deployment. Private endpoints are used to access resources from within the VNet without
  exposing them to the public internet. In this deployment, we decided to define two additional subnets, `pool-linux` and
  `pool-windows` to be used for the batch pools that use Linux and Windows nodes respectively. When customizing the deployment,
  you can changes these or add additional subnets as needed.

  Once we have defined the subnets, we need to define the NSG rules for each subnet. The default configuration defines
  rules to lock down all communication except the ones explicitly needed to support core functionality. You can customize
  these rules as needed.

* [storage.jsonc] defines the storage accounts we want to mount on all pools. These are totally
  optional. Your applications, for example, may be using a network database instead e.g. a redis cache, or Cosmos DB. In
  that case, you can skip this configuration and leave it empty. For other cases where you want to read data from shared storage
  or produce results on a shared storage, you can define the storage accounts here. The default configuration defines
  two storage accounts, one for blob storage and one for file storage. Blob storage can only be mounted on Linux nodes
  while file storage can be mounted on both Linux and Windows nodes.

* [batch.jsonc] defines the batch account and pools. We start by defining the batch account configuration.
  `poolAllocationMode` is set to `UserSubscription` to ensure that the pools are created in the same subscription as the
  batch account. This is preferred for deployment where you don't want to share compute resources with other users. `publicNetworkAccess` determines from which networks users can access the resource like batch account, container registry
  for management. `auto` indicates that the resources will be made accessible from public network unless peering with a hub
  VNet is configured (in hub.jsonc).

  Next, we define the pools. The default configuration defines two pools, one for Linux nodes and one for Windows nodes.
  The pools are configured to use the subnets defined in the spoke configuration. The pools are also configured to mount
  the storage accounts defined in the storage configuration. The pools are also configured to use the default image
  for the respective OS. You can customize these as needed in [images.jsonc].

* [hub.jsonc] is intended to pass information about resources deployed externally to this deployment.
  For example, if you have an existing hub VNet that you want to peer with the spoke VNet deployed by this deployment, you
  can specify the hub VNet information here. The default configuration is empty with placeholder for locations where you can
  specify the details about diagnostics resources, vnet peerings, user-defined-routes for firewalls, etc.

* [images.jsonc] defines the default OS images to use for the pools. The default configuration
  defines the default images for the a version of Windows Server and Ubuntu Server. You can customize these as needed.

<!-- ## Developer Guidelines

We follow the following naming conventions for resources deployed by this project:

* When creating a deployment, user specifies three things: `prefix`, and optionally, `environment` and `suffixSalt`.
  `prefix` is an alphanumeric string of length between 5 and 13. `environment` is an optional string of length between 3 and 10
  initialized to `dev` if not specified. `suffixSalt` is an optional string of arbitrary length.
  `suffixSalt` is primarily intended for regression testing, allow us differentiate different deployments.

* All resources created are deployed in a resource group named `${prefix}-${environment}`. If `suffixSalt` is specified, the
  resource group name is `${prefix}-${uniqueString(suffixSalt)}-${environment}`. Thus `suffixSalt` is used to generate a unique suffix for the resource group name.

* When naming non-globally unique resources, we don't use prefix or suffix. The resource-group
  name already acts as a namespace and hence there's no risk of conflict with existing resources and hence we opt
  for simplicity and readability.

* When naming resources that need to be globally unique, a GUID is generated that incorporate prefix, environment, and suffixSalt.

* When naming nested deployments, the top level creates a unique deployment name suffix as
  `uniqueString(deployment().name, location, prefix, environment, suffixSalt)`. All nested deployments can then simply use
  a deployment name suffix generated using `uniqueString(deployment().name)`. -->

[config/]: https://github.com/utkarshayachit/azbatch-starter/tree/main/config
[schemas/]: https://github.com/utkarshayachit/azbatch-starter/tree/main/schemas
[infrastructure.bicep]: https://github.com/utkarshayachit/azbatch-starter/blob/main/infrastructure.bicep 
[spoke.jsonc]: https://github.com/utkarshayachit/azbatch-starter/tree/main/config/spoke.jsonc
[batch.jsonc]: https://github.com/utkarshayachit/azbatch-starter/tree/main/config/batch.jsonc
[storage.jsonc]: https://github.com/utkarshayachit/azbatch-starter/tree/main/config/storage.jsonc
[images.jsonc]: https://github.com/utkarshayachit/azbatch-starter/tree/main/config/images.jsonc
[hub.jsonc]: https://github.com/utkarshayachit/azbatch-starter/tree/main/config/hub.jsonc
