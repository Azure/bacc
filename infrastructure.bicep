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

@description('additonal tags to attach to resources created')
param tags object = {}

@description('when true, all resources will be deployed under a single resource-group')
param useSingleResourceGroup bool = false

@description('Batch Service Object Id (az ad sp show --id "ddbf3205-c6bd-46ae-8127-60eb93363864" --query id)')
param batchServiceObjectId string

@description('enable application packages for batch account')
param enableApplicationPackages bool

@description('enable container support for applications')
param enableApplicationContainers bool

@description('deployment timestamp')
param timestamp string = utcNow('g')

//------------------------------------------------------------------------------
// Features: additive components
//------------------------------------------------------------------------------

@description('when true, log analytics workspace and related resources will be deployed')
param deployDiagnostics bool = false

@description('existing log analytics workspace id')
param externalLogAnalyticsWorkspaceId string = ''

//------------------------------------------------------------------------------
// Variables
//------------------------------------------------------------------------------

@description('resources prefix')
var rsPrefix = '${environment}-${prefix}'

@description('deployments prefix')
var dplPrefix = 'dpl-${environment}-${prefix}'

@description('tags for all resources')
var allTags = union(tags, {
  'last deployed': timestamp
  source: 'azbatch-starter:v0.1'
})

@description('resource group names')
var resourceGroupNames = {
  diagnosticsRG:  {
    name: useSingleResourceGroup? 'rg-${rsPrefix}' : 'rg-${rsPrefix}-diag'
    enabled: deployDiagnostics && empty(externalLogAnalyticsWorkspaceId)
  }

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

@description('deployment for diagnostics resources')
module dplDiagnostics 'modules/diagnostics.bicep' = if (resourceGroupNames.diagnosticsRG.enabled) {
  name: '${dplPrefix}-diagnostics'
  scope: resourceGroup(resourceGroupNames.diagnosticsRG.name)
  params: {
    rsPrefix: rsPrefix
    location: location
    tags: allTags
  }
  dependsOn: [
    // this is necessary to ensure all resource groups have been deployed
    // before we attempt to deploy resources under those resource groups.
    resourceGroups
  ]
}

var workpaceId = resourceGroupNames.diagnosticsRG.enabled ? dplDiagnostics.outputs.logAnalyticsWorkspace.id : externalLogAnalyticsWorkspaceId
var diagnosticsConfig = empty(workpaceId) ? {} : {
  workspaceId: workpaceId
}

@description('deploy networking resources')
module dplSpoke 'modules/spoke.bicep' = {
  scope: resourceGroup(resourceGroupNames.networkRG.name)
  name: '${dplPrefix}-spoke'
  params: {
    location: location
    rsPrefix: rsPrefix
    tags: allTags
    diagnosticsConfig: diagnosticsConfig
  }
  dependsOn: [
    // this is necessary to ensure all resource groups have been deployed
    // before we attempt to deploy resources under those resource groups.
    resourceGroups
  ]
}

@description('deployment for batch resources')
module dplBatch 'modules/batch.bicep' = {
  name: '${dplPrefix}-batch'
  scope: resourceGroup(resourceGroupNames.batchRG.name)
  params: {
    location: location
    rsPrefix: rsPrefix
    tags: allTags
    batchServiceObjectId: batchServiceObjectId
    enableApplicationPackages: enableApplicationPackages
    enableApplicationContainers: enableApplicationContainers
    poolSubnetId: dplSpoke.outputs.snetPool.snetId
    diagnosticsConfig: diagnosticsConfig
    appInsightsInfo: resourceGroupNames.diagnosticsRG.enabled ? dplDiagnostics.outputs.appInsights : {}
  }
  dependsOn: [
    // this is necessary to ensure all resource groups have been deployed
    // before we attempt to deploy resources under those resource groups.
    resourceGroups
  ]
}

var endpoints = dplBatch.outputs.endpoints

@description('deploy private endpoints and all related resources')
module dplEndpoints 'modules/endpoints.bicep' = {
  name: '${dplPrefix}-endpoints'
  scope: resourceGroup(resourceGroupNames.networkRG.name)
  params: {
    dplPrefix: dplPrefix
    rsPrefix: rsPrefix
    location: location
    tags: allTags
    endpoints: endpoints
    snetInfo: dplSpoke.outputs.snetPrivateEndpoints
  }
}

@description('log analytics workspace id')
output logAnalyticsWorkspaceId string = workpaceId

@description('resource groups created')
output resourceGroupNames array = uniqueGroups
