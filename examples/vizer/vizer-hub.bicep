// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

//------------------------------------------------------------------------------
// Options: parameters having broad impact on the deployement.
//------------------------------------------------------------------------------
@description('location where all the resources are to be deployed')
param location string = resourceGroup().location

@description('additonal tags to attach to resources created')
param tags object = {}

@description('deployment config')
@secure()
param config object

@description('delegated subnet name')
param delegatedSubnetName string = 'app-service'

//------------------------------------------------------------------------------
// existing resources
resource mi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: config.mi.name
}

resource ba 'Microsoft.Batch/batchAccounts@2022-10-01' existing = {
  name: config.batchAccount.name
}

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: config.vnet.name
}

resource snet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: delegatedSubnetName
  parent: vnet
}

// TODO: eventually, we may support multiple storage accounts
var saConfig = items(config.storageConfigs)[0].value

// app service plan
@description('app service plan for the vizer-hub web app deployment')
resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: 'vizer-hub-plan'
  location: location
  tags: tags
  properties: {
    reserved: true
  }
  sku: {
    name: 'B1'
  }
  kind: 'linux'
}

@description('app command line')
var cmdLine = union([
  '--port'
  '80'
  '-i'
  '${mi.properties.clientId}'
  '-b'
  'https://${ba.properties.accountEndpoint}'
  '-s'
  '${saConfig.name}'
  '--storage-container'
  '${saConfig.container}'
], contains(saConfig, 'credentials') && contains(saConfig.credentials, 'accountKey') ? [
  '-k'
  '"${saConfig.credentials.accountKey}"'
] : contains(saConfig, 'credentials') && contains(saConfig.credentials, 'sasKey') ? [
  '-t'
  '${saConfig.credentials.sasKey}'
] : [])

var appServiceNameSuffix = replace(guid('vizer-hub', resourceGroup().id), '-', '')

@description('app service')
resource appService 'Microsoft.Web/sites@2022-09-01' = {
  name: take('vizer-hub-${appServiceNameSuffix}', 60)
  location: location
  identity: {
    // using mi for batch service access avoids having to use shared-key
    // access which is not supported for UserSubscription pool allocation mode.
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${mi.id}': {}
    }
  }
  properties: {
    enabled: true
    serverFarmId: appServicePlan.id
    httpsOnly: true
    vnetRouteAllEnabled: true
    vnetContentShareEnabled: false
    virtualNetworkSubnetId: snet.id
    publicNetworkAccess: 'Enabled'
    siteConfig: {
      appCommandLine: join(cmdLine, ' ')
      linuxFxVersion: 'DOCKER|docker.io/utkarshayachit/vizer-hub:main'
      numberOfWorkers: 1
      appSettings: [
        {
          name: 'WEBSITES_PORT'
          value: '80'
        }
      ]
    }
  }
}

@description('vizer Hub URL')
output vizerHubUrl string = 'https://${appService.properties.defaultHostName}'
