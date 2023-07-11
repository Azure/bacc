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

@description('CIDR to use as the address prefix for the virtual network deployed')
param addressPrefix string = '10.121.0.0/16'

//------------------------------------------------------------------------------
var batchJS = loadJsonContent('./batch.jsonc')
var storageJS = loadJsonContent('./storage.jsonc')
var spokeTXT = loadTextContent('./spoke.jsonc')

var spoke0 = replace(spokeTXT, '\${addressPrefix}', addressPrefix)
var spoke1 = replace(spoke0, '\${addressPrefix/24/0}', cidrSubnet(addressPrefix, 24, 0))
var spoke2 = replace(spoke1, '\${addressPrefix/24/1}', cidrSubnet(addressPrefix, 24, 1))
var spokeJS = json(spoke2)

@description('suffix used for all nested deployments')
var dplSuffix = uniqueString(deployment().name, location, resourceGroupName)

//------------------------------------------------------------------------------
module mdlInfrastructure '../../modules/infrastructure.bicep' = {
  name: 'infrastructure-${dplSuffix}'
  params: {
    resourceGroupName: resourceGroupName
    location: location
    batchJS: batchJS
    storageJS: storageJS
    spokeJS: spokeJS
    tags: tags
    enableApplicationContainers: false 
    enableApplicationPackages: false
    timestamp: timestamp
  }
}

@description('deployment summary')
output summary object = mdlInfrastructure.outputs.summary
