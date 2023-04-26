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
param batchServiceObjectId string = ''

@description('enable application packages for batch account')
param enableApplicationPackages bool = false

@description('enable container support for applications')
param enableApplicationContainers bool = false

@description('deployment timestamp')
param timestamp string = utcNow('g')

// @description('admin password for pool nodes')
// @secure()
// param password string

//------------------------------------------------------------------------------
// Variables
//------------------------------------------------------------------------------
@description('resource group suffix')
var rgSuffix = empty(suffixSalt) ? '' : '-${uniqueString(suffixSalt)}'

@description('suffix used for all nested deployments')
var dplSuffix = uniqueString(deployment().name, location, prefix, environment, suffixSalt)

@description('tags for all resources')
var allTags = union(tags, {
  'last deployed': timestamp
  codebase: 'azbatch-starter'
  version: '0.1.0'
})


@description('hub configuration')
var hubConfig = union({
  diagnostics: {
    logAnalyticsWorkspace: {
      id: ''
    }
    appInsights: {
      appId: ''
      instrumentationKey: ''
    }
  }
  network: {
    routes: []
    peerings: []
    dnsZones: []
  }
}, loadJsonContent('config/hub.jsonc'))

@description('log analytics configuration to use for adding diagnostics settings to resources')
var logConfig = contains(hubConfig.diagnostics, 'logAnalyticsWorkspace')  && !empty(hubConfig.diagnostics.logAnalyticsWorkspace.id)? {
  workspaceId: hubConfig.diagnostics.logAnalyticsWorkspace.id
} : {}

var hasAppInsights = contains(hubConfig.diagnostics, 'appInsights') && !empty(hubConfig.diagnostics.appInsights.appId) && !empty(hubConfig.diagnostics.appInsights.instrumentationKey)

@description('app insights configuration')
var appInsightsConfig = hasAppInsights? {
  appId: hubConfig.diagnostics.appInsights.appId
  instrumentationKey: hubConfig.diagnostics.appInsights.instrumentationKey
} : {}

//------------------------------------------------------------------------------
// Resources
//------------------------------------------------------------------------------

@description('all resources group')
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${prefix}${rgSuffix}-${environment}'
  location: location
  tags: allTags
}

//------------------------------------------------------------------------------
@description('deploy networking resources')
module dplSpoke 'modules/spoke.bicep' = {
  name: 'spoke-${dplSuffix}'
  scope: rg
  params: {
    location: location
    tags: allTags
    logConfig: logConfig
    routes: hubConfig.network.routes
    peerings: hubConfig.network.peerings
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
    location: location
    tags: allTags
    batchServiceObjectId: batchServiceObjectId
    enableApplicationPackages: enableApplicationPackages
    enableApplicationContainers: enableApplicationContainers
    // password: password
    vnet: dplSpoke.outputs.vnet
    logConfig: logConfig
    appInsightsConfig: appInsightsConfig
    storageConfigurations: reduce(dplStorage.outputs.unlattedConfigs, {}, (acc, x) => union(acc, x))
    gatewayPeeringEnabled: dplSpoke.outputs.gatewayPeeringEnabled
  }
}

@description('deploy private endpoints and all related resources')
module dplEndpoints 'modules/endpoints.bicep' = {
  name: 'endpoints-${dplSuffix}'
  scope: rg
  params: {
    location: location
    tags: allTags
    endpoints: union(dplBatch.outputs.endpoints, flatten(dplStorage.outputs.unflattedEndpoints))
    snetInfo: dplSpoke.outputs.snetPrivateEndpoints
    existingDnsZones: hubConfig.network.dnsZones
  }
}

/// TODO: in case of non-owner subscription access, we need to skip this and instead
/// allow it to be done as a separate step after deployment completes
@description('deploy role assignments')
module dplRoleAssignments 'modules/roleAssignments.bicep' = {
  name: 'roleAssignments-${dplSuffix}'
  params: {
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

@description('batch account public network access')
output batchAccountPublicNetworkAccess bool = dplBatch.outputs.batchAccountPublicNetworkAccess
