/// deploys a single storage account
/// this code can either deploy a new one or "process" and existing one

@description('location of all resources')
param location string

@description('tags to assign to all resources created')
param tags object

param account object

var sanitizedAccount = union({
  containers: []
  shares: []
}, account)

var useExisting = contains(sanitizedAccount, 'credentials') && !empty(sanitizedAccount.credentials)
var sasCredentials = useExisting && contains(sanitizedAccount.credentials, 'sasKey') ? {
  // Azure portal is inconsistent in how it displays the sas key, sometimes it has a leading '?', sometimes not
  // this code ensures that the sas key always has a leading '?'. By manaully testing on batch pool with blobfuse,
  // it seems that the leading '?' is required.
  sasKey: startsWith(sanitizedAccount.credentials.sasKey, '?') ? sanitizedAccount.credentials.sasKey : '?${sanitizedAccount.credentials.sasKey}'
} : {}
var accessKeyCredentials = useExisting && empty(sasCredentials) ? {
  accountKey: sanitizedAccount.credentials.accountKey
} : {}

// for containers, enable nfs by default, unless disabled
// for non containers, don't enable nfs, unless enabled
var enableNFSv3 = contains(sanitizedAccount, 'enableNFSv3') ? sanitizedAccount.enableNFSv3 : !empty(sanitizedAccount.containers)

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = if (!useExisting) {
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
    isHnsEnabled: enableNFSv3
    isNfsV3Enabled: enableNFSv3
    allowBlobPublicAccess: false
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

resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = [for container in sanitizedAccount.containers: if (!useExisting) {
  name: container
  parent: storageAccount::blobServices
  properties: {
    publicAccess: 'None'
  }
}]

resource shares 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-09-01' = [for share in sanitizedAccount.shares: if (!useExisting) {
  name: share
  parent: storageAccount::fileServices
  properties: {
    enabledProtocols: 'SMB'
  }
}]

var containerConfigs = map(sanitizedAccount.containers, (container) => {
  key: '${sanitizedAccount.key}/${container}'
  value: {
    name: sanitizedAccount.name
    group: resourceGroup().name
    kind: 'blob'
    container: container
    nfsv3: enableNFSv3 && !useExisting
    credentials: union(sasCredentials, accessKeyCredentials)
  }
})

var shareConfigs = map(sanitizedAccount.shares, (share) => {
  key: '${sanitizedAccount.key}/${share}'
  value: {
    name: sanitizedAccount.name
    group: resourceGroup().name
    kind: 'file'
    share: share
    // FIXME: can't see to avoid doing this for now :/
    accountKey: useExisting ? accessKeyCredentials.accountKey : storageAccount.listKeys().keys[0].value
  }
})

output configs object = toObject(union(containerConfigs, shareConfigs), arg => arg.key, arg => arg.value)

/// private endpoints are only requested for newly created storage accounts.
/// existing storage accounts are assumed to be accessible by the pool(s) vnet(s)
var blobEndpoints = [for container in sanitizedAccount.containers: {
  name: useExisting? '' : storageAccount.name
  group: resourceGroup().name
  privateLinkServiceId: useExisting ? '' : storageAccount.id
  groupIds: [ 'blob' ]
  privateDnsZoneName: 'privatelink.blob.${az.environment().suffixes.storage}'
}]

var fileEndpoints = [for share in sanitizedAccount.shares: {
  name: useExisting ? '' : storageAccount.name
  group: resourceGroup().name
  privateLinkServiceId: useExisting ? '' : storageAccount.id
  groupIds: [ 'file' ]
  privateDnsZoneName: 'privatelink.file.${az.environment().suffixes.storage}'
}]

output endpoints array = useExisting ? [] : union(blobEndpoints, fileEndpoints)
