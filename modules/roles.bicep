param suffix string

@allowed([
  'acr'
  'storage'
])
param kind string

param name string
param roles array

@metadata({
  name: 'resource name'
  group: 'resource group name'
})
param miConfig object

var builtinRoles = loadJsonContent('./builtinRoles.json')

resource mi 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: miConfig.name
  scope: resourceGroup(miConfig.group)
}

resource sa 'Microsoft.Storage/storageAccounts@2022-09-01' existing = if (kind == 'storage') {
  name: name
}

resource roleAssignmentSA 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in roles: if (kind == 'storage') {
  name: guid(suffix, mi.id, name, role)
  scope: sa
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', builtinRoles[replace(role, ' ', '')])
    principalId: mi.properties.principalId
    principalType: 'ServicePrincipal'
  }
}]


resource acr 'Microsoft.ContainerRegistry/registries@2022-12-01' existing = if (kind == 'acr') {
  name: name
}

resource roleAssignmentACR 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in roles: if (kind == 'acr') {
  name: guid(suffix, mi.id, name, role)
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', builtinRoles[replace(role, ' ', '')])
    principalId: mi.properties.principalId
    principalType: 'ServicePrincipal'
  }
}]
