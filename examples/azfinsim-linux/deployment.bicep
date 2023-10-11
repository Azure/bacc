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

@description('enable container support for applications')
param enableApplicationContainers bool = false

@description('deployment timestamp')
param timestamp string = utcNow('g')

@description('CIDR to use as the address prefix for the virtual network deployed')
param addressPrefix string = '10.121.0.0/16'

//------------------------------------------------------------------------------
var configTXT = loadTextContent('./config.jsonc')

var config0 = replace(configTXT, '\${addressPrefix}', addressPrefix)
var config1 = replace(config0, '\${addressPrefix/24/0}', cidrSubnet(addressPrefix, 24, 0))
var config2 = replace(config1, '\${addressPrefix/24/1}', cidrSubnet(addressPrefix, 24, 1))
var config = json(config2)

@description('suffix used for all nested deployments')
var dplSuffix = uniqueString(deployment().name, location, resourceGroupName)

//------------------------------------------------------------------------------
module mdlInfrastructure '../../modules/infrastructure.bicep' = {
  name: 'infrastructure-${dplSuffix}'
  params: {
    resourceGroupName: resourceGroupName
    location: location
    config: config
    tags: tags
    enableApplicationContainers: enableApplicationContainers
    enableApplicationPackages: false
    timestamp: timestamp
  }
}

@description('deployment summary')
output summary object = mdlInfrastructure.outputs.summary

@description('resource group names')
output resourceGroups array = [ resourceGroupName ]
