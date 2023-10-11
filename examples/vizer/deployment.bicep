// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

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

//------------------------------------------------------------------------------
// storage account parameters
@description('existing storage account name')
param storageAccountName string = ''

@description('existing storage account access key')
@secure()
param storageAccountKey string = ''

@description('existing storage account SAS token')
@secure()
param storageAccountSasToken string = ''

@description('storage account container name')
@minLength(3)
param storageAccountContainer string = 'datasets'

//------------------------------------------------------------------------------
var configTXT = loadTextContent('./config.jsonc')
var config = json(replace(configTXT, '\${storageAccountContainer}', storageAccountContainer))

var credentials = !empty(storageAccountKey) ? {
  accountKey: storageAccountKey
} : !empty(storageAccountSasToken) ? {
  sasKey: storageAccountSasToken
} : {}

var storage0 = union(config.storage.storage0, !empty(storageAccountName) ? {
  credentials: union(credentials, { accountName: storageAccountName })
} : {})

@description('suffix used for all nested deployments')
var dplSuffix = uniqueString(deployment().name, location, resourceGroupName)

//------------------------------------------------------------------------------
module mdlInfrastructure '../../modules/infrastructure.bicep' = {
  name: 'infrastructure-${dplSuffix}'
  params: {
    resourceGroupName: resourceGroupName
    location: location
    tags: tags
    enableApplicationContainers: false
    enableApplicationPackages: false
    timestamp: timestamp
    config: {
      batch: config.batch
      network: config.network
      storage: { storage0: storage0 }
    }
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

@description('resource group names')
output resourceGroups array = [ resourceGroupName ]
