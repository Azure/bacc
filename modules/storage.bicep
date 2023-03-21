/**
  Deploys storage accounts for the given environment.
*/

@description('prefix to use for resources created')
param rsPrefix string

@description('prefix for deployments')
param dplPrefix string

@description('location of all resources')
param location string

@description('tags to assign to all resources created')
param tags object

@description('configuration')
param config object = loadJsonContent('../config/storage.jsonc')

@description('suffix to use for unique storage account names')
var nameSuffix = guid(rsPrefix, resourceGroup().id, location)

@description('storage accounts to deploy')
var accounts = map(items(config), entity => union(entity.value, {
  name: take(replace('${entity.key}${nameSuffix}','-',''), 24)
  key: entity.key
}))

@description('deploy storage accounts')
module mdlStorageAccounts 'storageAccount.bicep' = [for account in accounts: {
  name: take('${dplPrefix}-${account.key}', 64)
  params: {
    location: location
    tags: tags
    account: account
  }
}]


@description('resources needing role assignments')
output roleAssignments array = [for account in accounts: {
  kind: 'storage'
  name: account.name
  group: resourceGroup().name
  roles: [ 'Storage Blob Data Contributor' ]
}]

/// FIXME: due to a potential bug in Bicep, the following outputs cannot be `flatten`ed here.
@description('unflatted endpoints')
output unflattedEndpoints array = [for idx in range(0, length(accounts)): mdlStorageAccounts[idx].outputs.endpoints]

output unlattedConfigs array = [for idx in range(0, length(accounts)): mdlStorageAccounts[idx].outputs.configs]
