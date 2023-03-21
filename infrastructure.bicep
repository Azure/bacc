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

@description('suffix used for all nested deployments')
var dplSuffix = uniqueString(deployment().name, location, prefix, suffixSalt)

@description('suffix used for all nested resources')
var rsSuffix = '-${uniqueString(deployment().name, location, prefix, suffixSalt)}'

@description('tags for all resources')
var allTags = union(tags, {
  'last deployed': timestamp
  source: 'azbatch-starter:v0.1'
})

//------------------------------------------------------------------------------
// Resources
//------------------------------------------------------------------------------

@description('all resources group')
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${environment}-${prefix}${suffix}'
  location: location
  tags: allTags
}

//------------------------------------------------------------------------------
// Process hub config

// diagnostics configuration is set to empty object if logAnalyticsWorkspaceId is not provided
// otherwise, it is set to the workspace id provided in the hub configuration. We then use
// it to add diagnostics settings to all resources that support it.
@description('diagnostics configuration')
module dplDiagnostics 'modules/diagnostics.bicep' = {
  name: 'diagnostics-${dplSuffix}'
  params: {
    diagnosticsConfig: contains(hubConfig, 'diagnostics') ? hubConfig.diagnostics : {}
  }
}

// process network configuration
@description('network configuration')
module dplHubNetwork 'modules/hub_network.bicep' = {
  name: 'hubnetwork-${dplSuffix}'
  params: {
    networkConfig: contains(hubConfig, 'network') ? hubConfig.network : {}
  }
}

//------------------------------------------------------------------------------
@description('deploy networking resources')
module dplSpoke 'modules/spoke.bicep' = {
  name: 'spoke-${dplSuffix}'
  scope: rg
  params: {
    suffix: rsSuffix
    location: location
    tags: allTags
    logConfig: dplDiagnostics.outputs.logConfig
    routes: dplHubNetwork.outputs.routes
    peerings: dplHubNetwork.outputs.peerings
  }
}

@description('deployment for storage accounts')
module dplStorage 'modules/storage.bicep' = {
  name: 'storage-${dplSuffix}'
  scope: rg
  params: {
    location: location
    tags: allTags
  }
}

@description('deployment for batch resources')
module dplBatch 'modules/batch.bicep' = {
  name: 'batch-${dplSuffix}'
  scope: rg
  params: {
    suffix: rsSuffix
    location: location
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
}

@description('deploy private endpoints and all related resources')
module dplEndpoints 'modules/endpoints.bicep' = {
  name: 'endpoints-${dplSuffix}'
  scope: rg
  params: {
    suffix: rsSuffix
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
  name: 'roleAssignments-${dplSuffix}'
  params: {
    suffix: rsSuffix
    miConfig: dplBatch.outputs.miConfig
    roleAssignments: union(dplBatch.outputs.roleAssignments, dplStorage.outputs.roleAssignments)
  }
}

@description('resource groups created')
output resourceGroupNames array = [rg.name]

@description('batch account endpoint')
output batchAccountEndpoint string = dplBatch.outputs.batchAccountEndpoint

@description('batch account resource group')
output batchAccountResourceGroup string = dplBatch.outputs.batchAccountResourceGroup

@description('batch account name')
output batchAccountName string = dplBatch.outputs.batchAccountName
