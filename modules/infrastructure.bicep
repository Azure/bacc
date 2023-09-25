targetScope = 'subscription'

//------------------------------------------------------------------------------
// Options: parameters having broad impact on the deployement.
//------------------------------------------------------------------------------

@description('resource group name')
@minLength(1)
@maxLength(90)
param resourceGroupName string

@description('location where all the resources are to be deployed')
param location string = deployment().location

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
// parameters used to specify configuration options
@description('deployment configuration')
@secure()
param config object

@description('hub configuration')
@secure()
param hubConfig object = {}

//------------------------------------------------------------------------------
// Variables
//------------------------------------------------------------------------------
@description('suffix used for all nested deployments')
var dplSuffix = uniqueString(deployment().name, location, resourceGroupName)

@description('tags for all resources')
var allTags = union(tags, {
  'last deployed': timestamp
  codebase: 'azbatch-starter'
  version: '0.1.0'
})


@description('hub configuration')
var hubConfigSanitized = union({
  diagnostics: {
    logAnalyticsWorkspace: {
      id: ''
    }
    appInsights: {
      appId: ''
      instrumentationKey: ''
    }
  }
  managedIdentities: []
  network: {
    routes: []
    peerings: []
    dnsZones: []
  }
}, hubConfig)

@description('log analytics configuration to use for adding diagnostics settings to resources')
var logConfig = contains(hubConfigSanitized.diagnostics, 'logAnalyticsWorkspace')  && !empty(hubConfigSanitized.diagnostics.logAnalyticsWorkspace.id)? {
  workspaceId: hubConfigSanitized.diagnostics.logAnalyticsWorkspace.id
} : {}

var hasAppInsights = contains(hubConfigSanitized.diagnostics, 'appInsights') && !empty(hubConfigSanitized.diagnostics.appInsights.appId) && !empty(hubConfigSanitized.diagnostics.appInsights.instrumentationKey)

@description('app insights configuration')
var appInsightsConfig = hasAppInsights? {
  appId: hubConfigSanitized.diagnostics.appInsights.appId
  instrumentationKey: hubConfigSanitized.diagnostics.appInsights.instrumentationKey
} : {}

//------------------------------------------------------------------------------
// Resources
//------------------------------------------------------------------------------

@description('all resources group')
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: allTags
}

//------------------------------------------------------------------------------
@description('deploy networking resources')
module dplSpoke 'spoke.bicep' = {
  name: 'spoke-${dplSuffix}'
  scope: rg
  params: {
    location: location
    config: config.?network ?? {}
    tags: allTags
    logConfig: logConfig
    routes: hubConfigSanitized.network.routes
    peerings: hubConfigSanitized.network.peerings
  }
}

@description('deployment for storage accounts')
module dplStorage 'storage.bicep' = {
  name: 'storage-${dplSuffix}'
  scope: rg
  params: {
    location: location
    storageJS: config.storage
    tags: allTags
  }
}

@description('deployment for batch resources')
module dplBatch 'batch.bicep' = {
  name: 'batch-${dplSuffix}'
  scope: rg
  params: {
    location: location
    batchJS: config.batch
    images: config.?images ?? loadJsonContent('./images.jsonc')
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
module dplEndpoints 'endpoints.bicep' = {
  name: 'endpoints-${dplSuffix}'
  scope: rg
  params: {
    location: location
    tags: allTags
    endpoints: union(dplBatch.outputs.endpoints, flatten(dplStorage.outputs.unflattedEndpoints))
    snetInfo: dplSpoke.outputs.snetPrivateEndpoints
    existingDnsZones: hubConfigSanitized.network.dnsZones
  }
}

/// TODO: in case of non-owner subscription access, we need to skip this and instead
/// allow it to be done as a separate step after deployment completes
@description('deploy role assignments')
module dplRoleAssignments 'roleAssignments.bicep' = {
  name: 'roleAssignments-${dplSuffix}'
  params: {
    miConfig: dplBatch.outputs.miConfig
    roleAssignments: union(dplBatch.outputs.roleAssignments, dplStorage.outputs.roleAssignments)
  }
}

var rgRoleAssignments = union([
  // hub MIs need to be given reader role to resource group so our CLI tools work;
  // this is not absolutely necessary; only needed for our CLI tools that scan
  // through the resource group to locate and validate resources
  {
    kind: 'rg'
    name: rg.name
    group: rg.name
    roles: ['Reader']
  }

  // hub MIs need to be given contributor access to Batch account to be able to
  // submit jobs etc.; eventually, we may use a custom role
  {
    kind: 'ba'
    name: dplBatch.outputs.batchAccountName
    group: rg.name
    roles: ['Contributor']
  }
], enableApplicationContainers ? [{
    // hub  MIs need to be given contributor access to ACR for image import;
    // eventually should use a custom role
    kind: 'acr'
    name: dplBatch.outputs.acrName
    group: rg.name
    roles: ['Contributor']
  }] : [])

@description('deploy hub role assignments')
module dplRoleAssignmentsHub 'roleAssignments.bicep' = [for (config, index) in hubConfigSanitized.managedIdentities: {
  name: 'roleAssignments-${index}-${dplSuffix}'
  params: {
    miConfig: config
    roleAssignments: union(dplBatch.outputs.roleAssignments, dplStorage.outputs.roleAssignments, rgRoleAssignments)
  }
}]
@description('deployment summary')
output summary object = {
  batchAccount: {
    group: resourceGroupName
    name: dplBatch.outputs.batchAccountName
    endpoint: dplBatch.outputs.batchAccountEndpoint
  }
  mi : {
    group: resourceGroupName
    name: dplBatch.outputs.miConfig.name
  }
  storageConfigs: reduce(dplStorage.outputs.unlattedConfigs, {}, (acc, x) => union(acc, x))
  vnet: dplSpoke.outputs.vnet
}
