targetScope = 'subscription'

//------------------------------------------------------------------------------
// Options: parameters having broad impact on the deployement.
//------------------------------------------------------------------------------

@description('location where all the resources are to be deployed')
param location string = deployment().location

@description('short string used to identify deployment environment')
@minLength(3)
@maxLength(10)
param environment string = 'dev'

@description('short string used to generate all resources')
@minLength(5)
@maxLength(13)
param prefix string = uniqueString(environment, subscription().id, location)

@description('string used as salt for generating unique suffix for all resources')
param suffixSalt string = ''

@description('additonal tags to attach to resources created')
param tags object = {}

@description('when true, all resources will be deployed under a single resource-group')
param useSingleResourceGroup bool = false

@description('Batch Service Object Id (az ad sp show --id "ddbf3205-c6bd-46ae-8127-60eb93363864" --query id)')
param batchServiceObjectId string

@description('enable application packages for batch account')
param enableApplicationPackages bool = false

@description('enable container support for applications')
param enableApplicationContainers bool = false

@description('hub configuration')
param hubConfig object = loadJsonContent('config/hub.jsonc')

@description('deployment timestamp')
param timestamp string = utcNow('g')

// @description('admin password for pool nodes')
// @secure()
// param password string

//------------------------------------------------------------------------------
// Features: additive components
//------------------------------------------------------------------------------
// none available currently


//------------------------------------------------------------------------------
// Variables
//------------------------------------------------------------------------------

var suffix = empty(suffixSalt) ? '' : '-${uniqueString(suffixSalt)}'

@description('resources prefix')
var rsPrefix = '${environment}-${prefix}${suffix}'

@description('deployments prefix')
var dplPrefix = 'dpl-${environment}-${prefix}${suffix}'

@description('tags for all resources')
var allTags = union(tags, {
  'last deployed': timestamp
  source: 'azbatch-starter:v0.1'
})

@description('resource group names')
var resourceGroupNames = {
  networkRG: {
    name: useSingleResourceGroup? 'rg-${rsPrefix}' : 'rg-${rsPrefix}-network'
    enabled: true
  }

  batchRG: {
    name: useSingleResourceGroup? 'rg-${rsPrefix}' : 'rg-${rsPrefix}-batch'
    enabled: true
  }

}

//------------------------------------------------------------------------------
// Resources
//------------------------------------------------------------------------------

// dev notes: `union()` is used to remove duplicates
var uniqueGroups = union(map(filter(items(resourceGroupNames), arg => arg.value.enabled), arg => arg.value.name), [])

@description('all resource groups')
resource resourceGroups 'Microsoft.Resources/resourceGroups@2021-04-01' = [for name in uniqueGroups: {
  name: name
  location: location
  tags: allTags
}]

//------------------------------------------------------------------------------
// Process hub config

// diagnostics configuration is set to empty object if logAnalyticsWorkspaceId is not provided
// otherwise, it is set to the workspace id provided in the hub configuration. We then use
// it to add diagnostics settings to all resources that support it.
@description('diagnostics configuration')
module dplDiagnostics 'modules/diagnostics.bicep' = {
  name: take('${dplPrefix}-diagnostics', 64)
  params: {
    diagnosticsConfig: contains(hubConfig, 'diagnostics') ? hubConfig.diagnostics : {}
  }
}

// process network configuration
@description('network configuration')
module dplHubNetwork 'modules/hub_network.bicep' = {
  name: take('${dplPrefix}-hub-network', 64)
  params: {
    networkConfig: contains(hubConfig, 'network') ? hubConfig.network : {}
  }
}

//------------------------------------------------------------------------------
@description('deploy networking resources')
module dplSpoke 'modules/spoke.bicep' = {
  name: take('${dplPrefix}-spoke', 64)
  scope: resourceGroup(resourceGroupNames.networkRG.name)
  params: {
    location: location
    dplPrefix: dplPrefix
    rsPrefix: rsPrefix
    tags: allTags
    logConfig: dplDiagnostics.outputs.logConfig
    routes: dplHubNetwork.outputs.routes
    peerings: dplHubNetwork.outputs.peerings
  }

  dependsOn: [
    // this is necessary to ensure all resource groups have been deployed
    // before we attempt to deploy resources under those resource groups.
    resourceGroups
  ]
}

@description('deployment for storage accounts')
module dplStorage 'modules/storage.bicep' = {
  name: take('${dplPrefix}-storage', 64)
  scope: resourceGroup(resourceGroupNames.batchRG.name)
  params: {
    rsPrefix: rsPrefix
    dplPrefix: dplPrefix
    location: location
    tags: allTags
  }

  dependsOn: [
    // this is necessary to ensure all resource groups have been deployed
    // before we attempt to deploy resources under those resource groups.
    resourceGroups
  ]
}

@description('deployment for batch resources')
module dplBatch 'modules/batch.bicep' = {
  name: take('${dplPrefix}-batch', 64)
  scope: resourceGroup(resourceGroupNames.batchRG.name)
  params: {
    location: location
    rsPrefix: rsPrefix
    tags: allTags
    batchServiceObjectId: batchServiceObjectId
    enableApplicationPackages: enableApplicationPackages
    enableApplicationContainers: enableApplicationContainers
    // password: password
    vnet: dplSpoke.outputs.vnet
    logConfig: dplDiagnostics.outputs.logConfig
    appInsightsConfig: dplDiagnostics.outputs.appInsightsConfig
    storageConfigurations: reduce(dplStorage.outputs.unlattedConfigs, {}, (acc, x) => union(acc, x))
  }

  dependsOn: [
    // this is necessary to ensure all resource groups have been deployed
    // before we attempt to deploy resources under those resource groups.
    resourceGroups
  ]
}

@description('deploy private endpoints and all related resources')
module dplEndpoints 'modules/endpoints.bicep' = {
  name: take('${dplPrefix}-endpoints', 64)
  scope: resourceGroup(resourceGroupNames.networkRG.name)
  params: {
    dplPrefix: dplPrefix
    rsPrefix: rsPrefix
    location: location
    tags: allTags
    endpoints: union(dplBatch.outputs.endpoints, flatten(dplStorage.outputs.unflattedEndpoints))
    snetInfo: dplSpoke.outputs.snetPrivateEndpoints
  }
}

/// TODO: in case of non-owner subscription access, we need to skip this and instead
/// allow it to be done as a separate step after deployment completes
@description('deploy role assignments')
module dplRoleAssignments 'modules/roleAssignments.bicep' = {
  name: take('${dplPrefix}-roleAssignments', 64)
  params: {
    dplPrefix: dplPrefix
    rsPrefix: rsPrefix
    miConfig: dplBatch.outputs.miConfig
    roleAssignments: union(dplBatch.outputs.roleAssignments, dplStorage.outputs.roleAssignments)
  }
}

@description('resource groups created')
output resourceGroupNames array = uniqueGroups

@description('batch account endpoint')
output batchAccountEndpoint string = dplBatch.outputs.batchAccountEndpoint

@description('batch account resource group')
output batchAccountResourceGroup string = dplBatch.outputs.batchAccountResourceGroup

@description('batch account name')
output batchAccountName string = dplBatch.outputs.batchAccountName
