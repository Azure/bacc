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

@description('vnet peer resource group name')
param vnetPeerResourceGroupName string = ''

@description('vnet peer name')
param vnetPeerName string = ''

@description('compute node SKUs')
param sku string = 'Standard_HB120rs_v3'

@description('GIT repository URL for custom CMake-based MPI workload to deploy')
param mpiWorkloadGitUrl string = 'https://github.com/utkarshayachit/mpi_workload.git'

@description('GIT repository branch for custom CMake-based MPI workload to deploy')
param mpiWorkloadGitBranch string = 'main'

@description('GIT repository path to CMakeLists.txt for custom CMake-based MPI workload to deploy')
param mpiWorkloadGitCMakePath string = '.'

@description('CIDR to use as the address prefix for the virtual network deployed')
param addressPrefix string = '10.121.0.0/16'

@description('Batch Service Object Id (az ad sp show --id "ddbf3205-c6bd-46ae-8127-60eb93363864" --query id)')
param batchServiceObjectId string

//------------------------------------------------------------------------------
var extraArgs = !empty(mpiWorkloadGitUrl) && !empty(mpiWorkloadGitBranch) && !empty(mpiWorkloadGitCMakePath) ? '-g ${mpiWorkloadGitUrl} -b ${mpiWorkloadGitBranch} -p ${mpiWorkloadGitCMakePath}' : ''
var c0 = replace(loadTextContent('./config.jsonc'), '\${sku}', sku)
var c1 = replace(c0, '\${addressPrefix}', addressPrefix)
var c2 = replace(c1, '\${addressPrefix/24/0}', cidrSubnet(addressPrefix, 24, 0))
var c3 = replace(c2, '\${addressPrefix/24/1}', cidrSubnet(addressPrefix, 24, 1))
var c4 = replace(c3, '\${extraArgs}', extraArgs)
var config = json(c4)

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
