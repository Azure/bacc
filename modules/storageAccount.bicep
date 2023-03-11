/// deploys a single storage account

@description('prefix for deployments')
param dplPrefix string

@description('location of all resources')
param location string

@description('tags to assign to all resources created')
param tags object

param account object

var sanitizedAccount = union({
  enableNFSv3: true
  containers: []
  shares: []
}, account)

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: sanitizedAccount.name
  location: location
  tags: union({'config-key': sanitizedAccount.key}, tags)
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    isHnsEnabled: sanitizedAccount.enableNFSv3 ? true : false
    isNfsV3Enabled: sanitizedAccount.enableNFSv3 ? true : false

    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
  }

  resource blobServices 'blobServices' existing = {
    name: 'default'
  }

  resource fileServices 'fileServices' existing = {
    name: 'default'
  }
}

resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = [for container in sanitizedAccount.containers: {
  name: container
  parent: storageAccount::blobServices
  properties: {
    publicAccess: 'None'
  }
}]

resource shares 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-09-01' = [for share in sanitizedAccount.shares: {
  name: share
  parent: storageAccount::fileServices
  properties: {
    enabledProtocols: 'SMB'
  }
}]

var nfsMounts = [for container in sanitizedAccount.containers: {
  nfsMountConfiguration: {
    mountOptions: '-o sec=sys,vers=3,nolock,proto=tcp,rw'
    relativeMountPath: container
    source: '${storageAccount.name}.blob.${az.environment().suffixes.storage}:/${storageAccount.name}/${container}'
  }
}]

var afsMounts = [for share in sanitizedAccount.shares: {
  azureFileShareConfiguration : {
    relativeMountPath: share
    accountName: storageAccount.name
    azureFileUrl: 'https://${storageAccount.name}.file.${az.environment().suffixes.storage}/${share}'
    mountOptions: '-o vers=3.0,dir_mode=0777,file_mode=0777,sec=ntlmssp'
  }
}]

module mdlPopulateKeys 'populateKeys.bicep' = {
  name: '${dplPrefix}-populateKeys'
  params: {
    key: storageAccount.listKeys().keys[0].value
    objectList: afsMounts
    objectKey: 'azureFileShareConfiguration'
  }
}

output nfsMountConfigurations array = nfsMounts
output afsMountConfigurations array = mdlPopulateKeys.outputs.result

var blobEndpoints = [for container in sanitizedAccount.containers: {
  name: storageAccount.name
  group: resourceGroup().name
  privateLinkServiceId: storageAccount.id
  groupIds: [ 'blob' ]
  privateDnsZoneName: 'privatelink.blob.${az.environment().suffixes.storage}'
}]

var fileEndpoints = [for share in sanitizedAccount.shares: {
  name: storageAccount.name
  group: resourceGroup().name
  privateLinkServiceId: storageAccount.id
  groupIds: [ 'file' ]
  privateDnsZoneName: 'privatelink.file.${az.environment().suffixes.storage}'
}]

output endpoints array = union(blobEndpoints, fileEndpoints)
