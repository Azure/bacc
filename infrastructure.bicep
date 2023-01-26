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

@description('hub configuration')
param hubConfig object = loadJsonContent('config/hub.json')

@description('deployment timestamp')
param timestamp string = utcNow('g')

//------------------------------------------------------------------------------
// Features: additive components
//------------------------------------------------------------------------------
// none available currently


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

// diagnostics configuration is set to empty object if logAnalyticsWorkspaceId is not provided
// otherwise, it is set to the workspace id provided in the hub configuration. We then use
// it to add diagnostics settings to all resources that support it.
@description('diagnostics configuration')
module dplDiagnostics 'modules/diagnostics.bicep' = {
  name: '${dplPrefix}-diagnostics'
  params: {
    diagnosticsConfig: contains(hubConfig, 'diagnostics') ? hubConfig.diagnostics : {}
  }
}

@description('deploy networking resources')
module dplSpoke 'modules/spoke.bicep' = {
  scope: resourceGroup(resourceGroupNames.networkRG.name)
  name: '${dplPrefix}-spoke'
  params: {
    location: location
    rsPrefix: rsPrefix
    tags: allTags
    logConfig: dplDiagnostics.outputs.logConfig
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
    logConfig: dplDiagnostics.outputs.logConfig
    appInsightsConfig: dplDiagnostics.outputs.appInsightsConfig
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

@description('resource groups created')
output resourceGroupNames array = uniqueGroups
