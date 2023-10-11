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
// Connectivity parameters
//------------------------------------------------------------------------------
@description('enable Azure Bastion')
param enableBastion bool = true

@description('enable Azure VPN Gateway')
param enableVPNGateway bool = false

@description('enable Linux jumpbox')
param enableLinuxJumpbox bool = true

@description('enable Windows jumpbox')
param enableWindowsJumpbox bool = true

@description('admin password for jumpboxes')
@secure()
param adminPassword string

@description('root certificate for point-to-site (P2S) VPN configuration')
@secure()
param clientRootCertData string = ''

//------------------------------------------------------------------------------
// spoke parameters
//------------------------------------------------------------------------------
@description('Batch Service Object Id (az ad sp show --id "ddbf3205-c6bd-46ae-8127-60eb93363864" --query id)')
param batchServiceObjectId string

//------------------------------------------------------------------------------
@description('suffix used for all nested deployments')
var dplSuffix = uniqueString(deployment().name, location, resourceGroupName)

//------------------------------------------------------------------------------
var hubPrefix = take('hub-${uniqueString(resourceGroupName)}', 13)
module mdlConnectivity '../../tpl/connectivity/connectivity.bicep' = {
  name: 'connectivity-${dplSuffix}'
  params: {
    location: location
    environment: 'dev'
    prefix: hubPrefix
    tags: tags
    deployAzureFirewall: true
    deployAzureBastion: enableBastion
    deployVPNGateway: enableVPNGateway
    deployLinuxJumpbox: enableLinuxJumpbox
    deployWindowsJumpbox: enableWindowsJumpbox
    adminPassword: adminPassword
    clientRootCertData: clientRootCertData
  }
}

module mdlInfrastructure '../../modules/infrastructure.bicep' = {
  name: 'infrastructure-${dplSuffix}'
  params: {
    location: location
    resourceGroupName: resourceGroupName
    enableApplicationContainers: true
    enableApplicationPackages: false 
    batchServiceObjectId: batchServiceObjectId
    tags: tags
    timestamp: timestamp
    hubConfig: mdlConnectivity.outputs.azbatchStarter
    config: loadJsonContent('./config.jsonc')
  }
}

var hubRGName = 'rg-dev-${hubPrefix}'
@description('summary of the deployment')
output summary object = mdlInfrastructure.outputs.summary

@description('hub resource group name')
output hubResourceGroupName string = hubRGName

@description('hub prefix')
output hubPrefix string = hubPrefix

@description('resource group names')
output resourceGroups array = [ resourceGroupName, hubRGName]
