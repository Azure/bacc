// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

/**
  Deploys storage accounts for the given environment.
*/
@description('location of all resources')
param location string

@description('tags to assign to all resources created')
param tags object

@description('storage configuration')
@secure()
param storageJS object

@description('suffix to use for unique deployment names')
var dplSuffix = uniqueString(deployment().name)

var config = storageJS
var existingAccounts =filter(items(config), item => contains(item.value, 'credentials') && !empty(item.value.credentials))
var newAccounts = filter(items(config), item => !contains(item.value, 'credentials') || empty(item.value.credentials))

@description('storage accounts to deploy')
var accountsNew = map(newAccounts, entity => union(entity.value, {
  name: take(replace('${entity.key}${guid(resourceGroup().id, location, entity.key)}','-',''), 24)
  key: entity.key
}))

var accountsOld = map(existingAccounts, entity => union(entity.value, {
  name: entity.value.credentials.accountName
  key: entity.key
}))

var accounts = union(accountsOld, accountsNew)

@description('deploy storage accounts')
module mdlStorageAccounts 'storageAccount.bicep' = [for account in accounts: {
  name: take('storageAccount-${account.key}-${dplSuffix}', 64)
  params: {
    location: location
    tags: tags
    account: account
  }
}]

@description('resources needing role assignments (only done for new storage accounts)')
output roleAssignments array = [for account in accountsNew: {
  kind: 'storage'
  name: account.name
  group: resourceGroup().name
  roles: [ 'Storage Blob Data Contributor' ]
}]

/// FIXME: due to a potential bug in Bicep, the following outputs cannot be `flatten`ed here.
@description('unflatted endpoints')
output unflattedEndpoints array = [for idx in range(0, length(accounts)): mdlStorageAccounts[idx].outputs.endpoints]

output unlattedConfigs array = [for idx in range(0, length(accounts)): mdlStorageAccounts[idx].outputs.configs]
