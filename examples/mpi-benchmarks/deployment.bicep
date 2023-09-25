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

@description('vnet peer resource group name')
param vnetPeerResourceGroupName string = ''

@description('vnet peer name')
param vnetPeerName string = ''


@description('Batch Service Object Id (az ad sp show --id "ddbf3205-c6bd-46ae-8127-60eb93363864" --query id)')
param batchServiceObjectId string

//------------------------------------------------------------------------------
var config = loadJsonContent('./config.jsonc')

var peerings = !empty(vnetPeerResourceGroupName) && !empty(vnetPeerName) ? [{
  group: vnetPeerResourceGroupName
  name: vnetPeerName
  useGateway: true
}] : []

var hubConfig = !empty(peerings) ? {
  network: {
    peerings: peerings
  }
} : {}

@description('suffix used for all nested deployments')
var dplSuffix = uniqueString(deployment().name, location, resourceGroupName)

//------------------------------------------------------------------------------
module mdlInfrastructure '../../modules/infrastructure.bicep' = {
  name: 'infrastructure-${dplSuffix}'
  params: {
    config: config
    hubConfig: hubConfig
    resourceGroupName: resourceGroupName
    location: location
    tags: tags
    enableApplicationContainers: false
    enableApplicationPackages: false
    timestamp: timestamp
    batchServiceObjectId: batchServiceObjectId
  }
}

@description('deployment summary')
output summary object = mdlInfrastructure.outputs.summary

@description('resource group names')
output resourceGroups array = [ resourceGroupName ]
