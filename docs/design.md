# Design

The repository contains Bicep code that can be used to deploy resources to Azure. [infrastructure.bicep]
is intended to be the main module. Custom deployments should use this module to deploy resources
in addition to any other modules that may be needed.

Let's look at the parameters accepted by this module in more detail.

## Core Parameters

There are two types of parameters. Core parameters are a few basic parameters that control the deployment while the
configuration parameters are parameters that accept objects (think JSON) that allow you to customize the resources deployed
more extensively.

| Core Parameters | Default | Description |
| --- | --- | --- |
|__resourceGroupName__| `[REQUIRED]` | name to use for the resource group to create to hold all resources in this deployment.|
| __batchServiceObjectId__| `(empty)` |  batch service object id; this cab be obtained by executing the following command in Azure Cloud Shell with Bash (or similar terminal): `az ad sp list --display-name "Microsoft Azure Batch" --filter "displayName eq 'Microsoft Azure Batch'" \| jq -r '.[].id'`; this is __REQUIRED__ when the batch account is setup to use `UserSubscription` pool allocation mode, can be omitted otherwise.|
|__enableApplicationPackages__| `false`| when set to `true` additional resources will be deployed to support [Batch application packages](https://learn.microsoft.com/en-us/azure/batch/batch-application-packages). |
|__enableApplicationContainers__| `false` | when set to `true` additional resources will be deployed to support running jobs that use [containerized applications](https://learn.microsoft.com/en-us/azure/batch/batch-docker-container-workloads). |
|_location_| `deployment location` | a string identifying the location for all the resources. |
|_tags_| `{}` | an object to add as tags to all resources created; initialized to `{}` by default. |

## Configuration Parameters

These offer a more fine-grained control over the deployment. These are two configuration parameters, `hubConfig` is an
optional parameter that provides information about the hub resources to peer with (necessary in case of secured-batch configurations). `config` is a required parameter that provides information about the resources to deploy. When creating a custom
deployment, most likely you will set these up using a JSON configuration file (as do most of the examples in this repository).
The repository includes JSON schemas that you can use to validate such JSON configuration files under [schemas/].

You can validate your configuration files using tools like `check-jsconschema`. For example:

```bash
> check-jsonschema --schemafile ./schemas/config.schema.json [...]/config.json
```

Let's look at the structure of these configuration parameters in more detail.

### hubConfig

This configuration object is intended to provide information about a hub deployment to peer with. The [secured-batch] example
uses the [azbatch-starter-connectivity](https://github.com/mocelj/azbatch-starter-connectivity) repository to deploy a hub
and the pass the configuration information to this module. The expected strucure is as follows:

```jsonc
{
  "diagnostics": {
    /// optional information about diagnostics resources
    "logAnalyticsWorkspace": {
      "id": "[resource id of the log analytics workspace]",
    },

    "appInsights": {
      "appId": "[app id of the application insights resource]",
      "instrumentationKey": "[instrumentation key of the application insights resource]"
    }
  },

  "network": {
    /// optional information about network resources
    "routes": [
      /// list of objects in 'RoutePropertiesFormat' format. When specified,
      /// all traffic origination from the spoke VNet will be routed through
      /// the specified next hop. This is useful when using a firewall in the
      /// hub VNet to control all traffic to/from the spoke VNet.
      /// e.g.
      /// {
      ///   "name": "[name of the route]",
      ///   "properties": {
      ///     "addressPrefix": "[address prefix for the route]",
      ///     "nextHopType": "[next hop type for the route]",
      ///     "nextHopIpAddress": "[next hop ip address for the route]",
      ///     "hasBgpOverride": "[has bgp override for the route]"
      ///   }
      /// }
    ],

    "peerings": [
      /// list of vnets to peer with. Each object in the list is expected to
      /// be in the following format:
      /// {
      ///   "name": "[name of the vnet]",
      ///   "group": "[resource group of the vnet]",
      ///   "useGateway": "[true/false to indicate if gateway should be used, defaults to false]"
      /// }
    ],

    "dnsZones": [
      /// dns zones, if non-empty, is used to pass the information about the resource group
      /// under which all necessary dns zones are created, e.g.
      /// {
      ///   "name": "[name of the dns zone]",
      ///   "group": "[resource group of the dns zone]"
      /// }
    ]
  }
}
```

## config

This configuration object is the one that specifies how the resources are to be deployed. The structure of this object is
as follows:

```jsonc
{
  "network": {
    /// defines the spoke network configuration including topology and NSG rules
  },

  "storage": {
    /// defines the storage accounts to make available for mounting on pools
  },

  "batch": {
    /// defines the batch account and pools
  },
}
```

When specifying this configuration, it's easiest to set up the config in order specified above i.e. think of your network first,
then storage account and finally the batch account setup. Let's look at each of these in more detail.

`network` specifies the network configuration as follows:

```jsonc
/// network configuration
{
  "addressPrefix": "[address prefix / CIDR for the spoke VNet]",
  "private-endpoints": {
    /// subnet definition object (described below) for the private-endpoints subnet.
    /// this is required and used to deploy all private endpoints for
    /// resources in this deployment.
  },
  "...": {
    /// subnet definition objects for other named subnets in the spoke VNet
    /// you can specify arbitrarily many.
  }
}

/// subnet definition object has the following structure:
{
  "addressPrefix": "[address prefix / CIDR for the subnet]",
  "nsgRules": [
    /// ordered array of NSG rule names to apply to the subnet.
    /// refer to nsgRules.jsonc for names for the supported rules.
  ],
  "delegations": [
    /// if a subnet is to be delegated to a service(s), you can list that here.
    /// e.g. "Microsoft.Web/serverFarms"
  ]
}
```

Start by defining the address prefix for the spoke VNet. Then define the subnets. The `private-endpoints` subnet is required
and is used to deploy all private endpoints for various resources in the deployment. In addition, you can define arbitrarily
many subnets. These subnets can be associated with specific pools later on. Once you have named the subnets, you need specify
network security rules for each of them. These rules define what traffic is allowed to and from the subnet. Its a good idea
to restrict communication between subnets to only allow the required channels. The examples included in this repository
follow this practice.

`storage` specifies the storage accounts to make available for mounting on pools as follows:

```jsonc
/// storage configuration
{
  "[storage account identifier]": {
    /// storage account definition object.
    /// storage accounts are identified by a string identifier which is also used to generate a unique
    /// name for the storage account. Since storage account names must be unique across Azure, it's
    /// the id used here is only used as a hint when generating the actual storage account name. The identifier
    /// is used when referring to the storage account in the pool configuration.
    "enableNFSv3": "[true/false to indicate if NFSv3 should be enabled on the storage account]",
    "containers": [
      /// list of blob storage containers under this account, if any
    ],
    "shares": [
      /// list of file shares under this account, if any
    ],
    "credentials": {
      /// when specified, an existing storage account is used instead of new one being created.
      /// this is useful when you want to use an existing storage account.
      /// Only one of accountKey or sasKey must be specified.
      "accountName": "[name of the storage account]",
      "accountKey": "[key for the storage account]",
      "sasKey": "[sas token for the storage account]"
    }
  },
}
```

`batch` specifies the batch account and pools as follows:

```jsonc
/// batch configuration
{
  /// Specify the pool allocation mode. Accepted values are "UserSubscription" or "BatchService".
  "poolAllocationMode": "UserSubscription",

  /// Specify whether you want to users access certain resources like the Batch account for job / pool management,
  /// the Azure Container Registry for container image management, from
  /// a public network. Accepted values are true, false, or "auto". If "auto" is specified, the
  /// the resources will be accessible from the public network only if there is not gateway peering
  /// specified in the hub configuration (see `hub.jsonc`)
  "publicNetworkAccess": "auto",

  /// "pools" is a list of pools to create in the batch account. You can define arbitrary number of pools here, limited
  /// by batch account limits and quotas. Each pool is a set of nodes that are homogeneous in terms of the operating
  /// system, virtual machine size, and other attributes. The nodes in a pool are created in a subnet under the
  /// spoke vnet defined in `spoke.jsonc`.
  "pools": [
      {
          /// Name for the pool. This is used to identify the pool in the batch account. It must be unique
          /// across all pools on this batch account.
          "name": "[pool name]",

          /// Virtual machine configuration. "image" refers to an image definition in the `images.jsonc`.
          "virtualMachine": {
              "size": "[SKU for the virtual machine]]",
              "taskSlotsPerNode": "[number of task slots per node]",
              /// see images.jsonc for a list of images
              "image": "microsoft-azure-batch/ubuntu-server-container/20-04-lts/latest"
          },

          /// Specify whether internode communication is needed for the tasks. Applications that use MPI, for example,
          /// require that internode communication is enabled.
          "interNodeCommunication": false,

          /// Choose the subnet. The name must match one of the subnets defined in the `spoke`
          /// configuration .
          "subnet": "[pool name]",

          /// Choose which storage containers/file-shares are to be mounted on this pool
          /// "key" is the relative path for the mount and value is the "<storage-account-tag>/<container|fileshare>".
          /// The "storage-account-identifier" is used to look up the storage account defined in `storage` configuration.
          /// For windows nodes, the mount path should be a single letter since it is used as a drive letter.
          "mounts": {
              "data": "blob0/data",
              "logs": "afs0/logs"
          }
      }
  ]
}
```

[config/]: https://github.com/utkarshayachit/azbatch-starter/tree/main/config
[schemas/]: https://github.com/utkarshayachit/azbatch-starter/tree/main/schemas
[infrastructure.bicep]: https://github.com/utkarshayachit/azbatch-starter/blob/main/modules/infrastructure.bicep 
[spoke.jsonc]: https://github.com/utkarshayachit/azbatch-starter/tree/main/config/spoke.jsonc
[batch.jsonc]: https://github.com/utkarshayachit/azbatch-starter/tree/main/config/batch.jsonc
[storage.jsonc]: https://github.com/utkarshayachit/azbatch-starter/tree/main/config/storage.jsonc
[images.jsonc]: https://github.com/utkarshayachit/azbatch-starter/tree/main/config/images.jsonc
[hub.jsonc]: https://github.com/utkarshayachit/azbatch-starter/tree/main/config/hub.jsonc
