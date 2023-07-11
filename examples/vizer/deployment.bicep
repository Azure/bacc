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

@description('deployment timestamp')
param timestamp string = utcNow('g')


@description('storage account credentials')
@secure()
@metadata({
  accountName: 'name of the storage account'
  accountKey: 'storage account access key'
  sasKey: 'storage account SAS token'
})
param storageCredentials object

//------------------------------------------------------------------------------
var batchJS = loadJsonContent('./batch.jsonc')
var spokeJS = loadJsonContent('./spoke.jsonc')
var storageJS = loadJsonContent('./storage.jsonc')

var storage0 = union(storageJS.storage0, {
  credentials: storageCredentials
})

@description('suffix used for all nested deployments')
var dplSuffix = uniqueString(deployment().name, location, resourceGroupName)

//------------------------------------------------------------------------------
module mdlInfrastructure '../../modules/infrastructure.bicep' = {
  name: 'infrastructure-${dplSuffix}'
  params: {
    resourceGroupName: resourceGroupName
    location: location
    batchJS: batchJS
    storageJS: { storage0: storage0 }
    spokeJS: spokeJS
    tags: tags
    enableApplicationContainers: false
    enableApplicationPackages: false
    timestamp: timestamp
  }
}

//------------------------------------------------------------------------------
module mdlVizerHub 'vizer-hub.bicep' = {
  name:  'vizer-hub-${dplSuffix}'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    config: mdlInfrastructure.outputs.summary
    tags: tags
  }
}

@description('deployment summary')
output summary object = mdlInfrastructure.outputs.summary

@description('vizer Hub URL')
output vizerHubUrl string = mdlVizerHub.outputs.vizerHubUrl
