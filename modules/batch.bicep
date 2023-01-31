/**
  Deploys core resources needed for batch.
*/

@description('prefix to use for resources created')
param rsPrefix string

@description('location of all resources')
param location string

@description('tags to assign to all resources created')
param tags object

@description('Batch Service Object Id (az ad sp show --id "ddbf3205-c6bd-46ae-8127-60eb93363864" --query id)')
param batchServiceObjectId string

@description('enable container suppport')
param enableApplicationContainers bool

@description('enable application pakacges support')
param enableApplicationPackages bool

@description('vnet under which pool subsets are defined')
@metadata({
  group: 'vnet group name'
  name: 'vnet name'
})
param vnet object = {
  group: ''
  name: ''
}

@description('log workspace config')
param logConfig object = {}

@description('app insights config')
param appInsightsConfig object = {}

var config = loadJsonContent('../config/batch.jsonc')
var builtinRoles = loadJsonContent('builtinRoles.json')
var diagConfig = loadJsonContent('../config/diagnostics.json')

//------------------------------------------------------------------------------
// Resources
//------------------------------------------------------------------------------

/**
  This is a User Managed Identity that we use to associate with the batch account and pool nodes.
  This Identity is used to provide access to resources that the batch account/pool needs
  to access.
*/
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: '${rsPrefix}-mi'
  location: location
  tags: tags
}

/**
 Setup key vault to store all secrets, if needed.

 KeyVault is also required when using Batch with 'User Subscription' pool allocation
 mode. In that case, we need to assign access policy to the key valut so that
 batch service can access/modify it.
 Currently, it doesn't seem like we can use RBAC to grant Batch Service access to the
 key-vault.
*/
var needsKeyVault = config.batchAccount.poolAllocationMode == 'UserSubscription'
@description('key vault required to use fo')
resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = if (needsKeyVault) {
  name: take('kv-${guid('kv', rsPrefix, resourceGroup().id)}', 24)
  location: location
  tags: tags
  properties: {
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    enableRbacAuthorization: false /* see note above */
    enableSoftDelete: config.keyVault.enableSoftDelete
    publicNetworkAccess: 'disabled'
    tenantId: tenant().tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }

    accessPolicies: [
      {
        /* for 'user subscription' pool allocation mode, we need these access policies */
        objectId: batchServiceObjectId
        tenantId: tenant().tenantId
        permissions: {
          secrets: [
            'get'
            'set'
            'list'
            'delete'
            'recover'
          ]
        }
      }

      // {
      //   /* access policy for MI */
      //   objectId: managedIdentity.properties.principalId
      //   tenantId: managedIdentity.properties.tenantId
      //   permissions: {
      //     secrets: [
      //       'get'
      //       'set'
      //       'list'
      //       'delete'
      //       'recover'
      //     ]
      //   }
      // }
    ]
  }
}

resource keyVault_diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (needsKeyVault && !empty(logConfig)) {
  name: '${keyVault.name}-diag'
  scope: keyVault
  properties: union(logConfig, diagConfig)
}

/**
  When using application packages to upload applications / data to batch pool nodes
  we need a storage account.
*/
resource sa 'Microsoft.Storage/storageAccounts@2022-09-01' = if (enableApplicationPackages) {
  name: take('sa0${join(split(guid('sa', rsPrefix, resourceGroup().id), '-'), '')}', 24)
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
    publicNetworkAccess: 'Disabled'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true // required
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: null
    }
  }

  resource blobServices 'blobServices' existing = {
    name: 'default'
  }
}

// container within the storage account
resource saContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = if (enableApplicationPackages) {
  name: 'container0'
  parent: sa::blobServices
  properties: {
    publicAccess: 'None'
  }
}

// give the managedIdentity access to the storage account
resource roleSA 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableApplicationPackages) {
  name: guid(managedIdentity.id, sa.id, 'StorageBlobDataContributor')
  scope: sa
  properties: {
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', builtinRoles.StorageBlobDataContributor)
  }
}

@description('storage account diagnostics setting')
resource sa_diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableApplicationPackages && !empty(logConfig)) {
  name: '${sa.name}-diag'
  scope: sa
  properties: union(logConfig, diagConfig)
}

/**
 Deploy container registry if containers are renabled.
*/
resource acr 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' = if (enableApplicationContainers) {
  name: take('acr${join(split(guid('acr', rsPrefix, resourceGroup().id), '-'), '')}', 50)
  location: location
  sku: {
    name: 'Premium' // needed for private endpoints
  }
  properties: {
    adminUserEnabled: config.containerRegistry.publicNetworkAccess ? true : false // RBAC only
    publicNetworkAccess: config.containerRegistry.publicNetworkAccess ? 'Enabled' : 'Disabled'
    zoneRedundancy: 'Disabled'
    networkRuleBypassOptions: 'AzureServices'
  }
}

resource roleAssignmentACR 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in ['AcrPull', 'AcrPush', 'AcrDelete', 'AcrImageSigner']: if (enableApplicationContainers) {
  name: guid(managedIdentity.id, acr.id, role)
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', builtinRoles[role])
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}]

resource acr_diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableApplicationContainers && !empty(logConfig)) {
  name: '${acr.name}-diag'
  scope: acr
  properties: union(logConfig, diagConfig)
}

/**
  The batch account.
*/
resource batchAccount 'Microsoft.Batch/batchAccounts@2022-10-01' = {
  name: take('ba${join(split(guid('ba', rsPrefix, resourceGroup().id), '-'), '')}', 24)
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}' : {}
    }
  }
  properties: {
    allowedAuthenticationModes: [
      'AAD'
      'TaskAuthenticationToken'
    ]

    autoStorage: enableApplicationPackages ? {
      storageAccountId: sa.id
      authenticationMode: 'BatchAccountManagedIdentity'
      nodeIdentityReference: {
        resourceId: managedIdentity.id
      }
    } : null

    poolAllocationMode: config.batchAccount.poolAllocationMode
    publicNetworkAccess: config.batchAccount.publicNetworkAccess? 'Enabled' : 'Disabled'
    networkProfile: {
      accountAccess: {
        defaultAction: 'Deny'
        ipRules: config.batchAccount.publicNetworkAccess ? [
          {
            action: 'Allow'
            value: '0.0.0.0/0'
          }
        ] : []
      }

      nodeManagementAccess: {
        defaultAction: 'Allow' /// FIXME: Deny?
      }
    }

    keyVaultReference: needsKeyVault ? {
      id: keyVault.id
      url: keyVault.properties.vaultUri
    } : null
  }

  dependsOn: [
    roleSA
  ]
}

resource batchAccount_diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logConfig)) {
  name: '${batchAccount.name}-diag'
  scope: batchAccount
  properties: union(logConfig, diagConfig)
}


@description('start tasks for each os')
var batchInsightsStartTask = {
  windows: {
    commandLine: 'cmd /c @"%SystemRoot%\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString(\'https://raw.githubusercontent.com/Azure/batch-insights/master/scripts/run-windows.ps1\'))"'
    environmentSettings: [
      {
        name: 'APP_INSIGHTS_INSTRUMENTATION_KEY'
        value: !empty(appInsightsConfig) ? appInsightsConfig.instrumentationKey : ''
      }
      {
        name: 'APP_INSIGHTS_APP_ID'
        value: !empty(appInsightsConfig) ? appInsightsConfig.appId : ''
      }
      {
        name: 'BATCH_INSIGHTS_DOWNLOAD_URL'
        value: 'https://github.com/Azure/batch-insights/releases/download/v1.3.0/batch-insights.exe'
      }
    ]
  }

  linux: {
    commandLine: '/bin/bash -c \'wget  -O - https://raw.githubusercontent.com/Azure/batch-insights/master/scripts/run-linux.sh | bash\''
    environmentSettings: [
      {
        name: 'APP_INSIGHTS_INSTRUMENTATION_KEY'
        value: !empty(appInsightsConfig) ? appInsightsConfig.instrumentationKey : ''
      }
      {
        name: 'APP_INSIGHTS_APP_ID'
        value: !empty(appInsightsConfig) ? appInsightsConfig.appId : ''
      }
      {
        name: 'BATCH_INSIGHTS_DOWNLOAD_URL'
        value: 'https://github.com/Azure/batch-insights/releases/download/v1.3.0/batch-insights'
      }
    ]
  }
}


resource poolVNet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: vnet.name
  scope: resourceGroup(vnet.group)
}

resource pools 'Microsoft.Batch/batchAccounts/pools@2022-10-01' = [for (item, index) in config.pools: {
  name: item.name
  parent: batchAccount
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }

  properties: {
    vmSize: item.virtualMachine.size
    taskSlotsPerNode: item.virtualMachine.taskSlotsPerNode

    taskSchedulingPolicy: {
     nodeFillType: 'Spread' // or 'Pack'
    }

    deploymentConfiguration: {
      virtualMachineConfiguration: {
        imageReference: config.images[item.virtualMachine.image].imageReference
        nodeAgentSkuId: config.images[item.virtualMachine.image].nodeAgentSkuId

        // provide ACR information if containers are enabled (and supported)
        containerConfiguration: (!enableApplicationContainers || config.images[item.virtualMachine.image].isWindows) ? null : {
          type: 'DockerCompatible'
          containerRegistries: [
            {
              registryServer: enableApplicationContainers ? acr.properties.loginServer : null
              identityReference: {
                resourceId: managedIdentity.id
              }
            }
          ]

          // we don't prefetch any images when pool nodes are allocated.
          // for production setups, one may want to prefetch image to avoid
          // having to fetch them when jobs are allocated.
          // containerImageNames: []
        }
      }
    }

    scaleSettings: {
      fixedScale: {
        targetDedicatedNodes: 0
        targetLowPriorityNodes: 0
        resizeTimeout: 'PT15M'
      }
    }

    targetNodeCommunicationMode: 'Simplified'
    interNodeCommunication: item.interNodeCommunication ? 'Enabled' : 'Disabled'
    networkConfiguration: {
      subnetId: '${poolVNet.id}/subnets/${item.subnet}'
      publicIPAddressConfiguration: {
        provision: 'NoPublicIPAddresses'
      }
    }

    startTask: !empty(appInsightsConfig) ? union(batchInsightsStartTask[config.images[item.virtualMachine.image].isWindows? 'windows': 'linux'], {
      maxTaskRetryCount: 1
      userIdentity: {
        autoUser: {
          elevationLevel: 'admin'
          scope: 'pool'
        }
      }}) : {}
  }
}]

var endpoints = [
  {
    name: batchAccount.name
    group: resourceGroup().name
    privateLinkServiceId: batchAccount.id
    groupIds: [ 'batchAccount' ]
    privateDnsZoneName: 'privatelink.batch.azure.com'
  }

  {
    name: batchAccount.name
    group: resourceGroup().name
    privateLinkServiceId: batchAccount.id
    groupIds: [ 'nodeManagement' ]
    privateDnsZoneName: 'privatelink.batch.azure.com'
  }

  needsKeyVault ? {
    name: keyVault.name
    group: resourceGroup().name
    privateLinkServiceId: keyVault.id
    groupIds: ['vault']
    privateDnsZoneName: 'privatelink.vaultcore.azure.net'
  } : {}

  enableApplicationContainers ? {
    name: acr.name
    group: resourceGroup().name
    privateLinkServiceId: acr.id
    groupIds: ['registry']
    privateDnsZoneName: 'privatelink${environment().suffixes.acrLoginServer}'

  } : {}

  enableApplicationPackages ? {
    name: sa.name
    group: resourceGroup().name
    privateLinkServiceId: sa.id
    groupIds: ['blob']
    privateDnsZoneName: 'privatelink.blob.${environment().suffixes.storage}'
  } : {}
]

output endpoints array = filter(endpoints, arg => !empty(arg))
