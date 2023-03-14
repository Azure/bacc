targetScope = 'subscription'

@description('prefix use for deployments')
param dplPrefix string

@description('prefix used for resources')
param rsPrefix string

param miConfig object

param roleAssignments array

// var storageRoles = filter(roleAssignments, (roleAssignment) => roleAssignment.kind == 'storage')
// var acrRoles = filter(roleAssignments, (roleAssignment) => roleAssignment.kind == 'acr')

module roles 'roles.bicep' = [for config in roleAssignments: {
  name: take('${dplPrefix}-roles-${config.name}', 64)
  scope: resourceGroup(config.group)
  params: {
    rsPrefix: rsPrefix
    kind: config.kind
    name: config.name
    roles: config.roles
    miConfig: miConfig
  }
}]
