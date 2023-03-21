targetScope = 'subscription'

@description('suffix used for resources')
param suffix string

param miConfig object

param roleAssignments array

var dplSuffix = uniqueString(subscription().id, deployment().name)

// var storageRoles = filter(roleAssignments, (roleAssignment) => roleAssignment.kind == 'storage')
// var acrRoles = filter(roleAssignments, (roleAssignment) => roleAssignment.kind == 'acr')

module roles 'roles.bicep' = [for config in roleAssignments: {
  name: take('roles-${config.name}-${dplSuffix}', 64)
  scope: resourceGroup(config.group)
  params: {
    suffix: suffix
    kind: config.kind
    name: config.name
    roles: config.roles
    miConfig: miConfig
  }
}]
