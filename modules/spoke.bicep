/**
  Deploy a vnet for our use.
*/

@description('prefix to use for resources created')
param rsPrefix string

@description('location of all resources')
param location string

@description('tags to assign to all resources created')
param tags object

@description('diagnostics config')
param diagnosticsConfig object = {}

var config = loadJsonContent('../config/spoke.json')
var diagConfig = loadJsonContent('../config/diagnostics.json')

@description('default nsg')
resource defaultNSG 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: 'default-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: config.networkSecurityGroups.default
  }
}

@description('batch pool nsg')
resource poolNSG 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: 'pool-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: config.networkSecurityGroups['batch-simplified']
  }
}

@description('the virtual network')
resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: '${rsPrefix}-spoke'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: config.addressPrefixes
    }
    subnets: [
      {
        name: 'snet-private-endpoints'
        properties: {
          // addressPrefixes: config.subnets['private-endpoints']
          addressPrefix: config.subnets['private-endpoints'][0]
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
          networkSecurityGroup: {
            id: defaultNSG.id
          }
        }
      }
      {
        name: 'snet-pool'
        properties: {
          // addressPrefixes: config.subnets.pool
          addressPrefix: config.subnets.pool[0]
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
          networkSecurityGroup: {
            id: poolNSG.id
          }
        }
      }
    ]
  }

  resource snetPrivateEndpoints 'subnets' existing = {
    name: 'snet-private-endpoints'
  }

  resource snetPool 'subnets' existing = {
    name: 'snet-pool'
  }
}

//------------------------------------------------------------------------------
// diagnostic settings
resource defaultNSG_diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(diagnosticsConfig)) {
  scope: defaultNSG
  name: '${defaultNSG.name}-diag'
  properties: union(diagnosticsConfig, {logs: diagConfig.logs})
}

resource poolNSG_diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(diagnosticsConfig)) {
  scope: poolNSG
  name: '${poolNSG.name}-diag'
  properties: union(diagnosticsConfig, {logs: diagConfig.logs})
}

resource vnetNSG_diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(diagnosticsConfig)) {
  scope: vnet
  name: '${vnet.name}-diag'
  properties: union(diagnosticsConfig, diagConfig)
}

//------------------------------------------------------------------------------
@description('virtual network')
output vnet object = {
  group: resourceGroup().name
  name: vnet.name
  id: vnet.id
  subnets: {
    privateEndpoints: {
      name: vnet::snetPrivateEndpoints.name
      id: vnet::snetPrivateEndpoints.id
    }
    pool: {
      name: vnet::snetPool.name
      id: vnet::snetPool.id
    }
  }
}

@description('subnet to use for all private endpoints')
output snetPrivateEndpoints object = {
  group: resourceGroup().name
  name: vnet.name
  snet: vnet::snetPrivateEndpoints.name
  snetId: vnet::snetPrivateEndpoints.id
}

@description('subnet to use for all batch pools')
output snetPool object = {
  group: resourceGroup().name
  name: vnet.name
  snet: vnet::snetPool.name
  snetId: vnet::snetPool.id
}

@description('resources for which diagnostic settings can be added')
output diagnosableResoures array = [
  {
    id: vnet.id
    name: vnet.name
    group: resourceGroup().name
    type: vnet.type
  }
  {
    id: defaultNSG.id
    name: defaultNSG.name
    group: resourceGroup().name
    type: defaultNSG.type
  }
  {
    id: poolNSG.id
    name: poolNSG.name
    group: resourceGroup().name
    type: poolNSG.type
  }
]
