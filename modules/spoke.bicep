/**
  Deploy a vnet for our use.
*/
@description('deployment prefix')
param dplPrefix string

@description('prefix to use for resources created')
param rsPrefix string

@description('location of all resources')
param location string

@description('tags to assign to all resources created')
param tags object

@description('diagnostics config')
param logConfig object = {}

@description('udrs')
param routes array = []

@description('vnet peerings')
param peerings array = []

var config = loadJsonContent('../config/spoke.jsonc')
var diagConfig = loadJsonContent('../config/diagnostics.json')

//----------------------------------------------------------------------------------------------------------------------
// build nsg security rules.
module dplNSGRules 'nsgRules.bicep' = {
  name: '${dplPrefix}-nsgRules'
  params: {
    config: config.networkSecurityGroups
  }
}

//----------------------------------------------------------------------------------------------------------------------
resource nsgs 'Microsoft.Network/networkSecurityGroups@2022-09-01' = [for item in items(config.networkSecurityGroups): {
  name: '${item.key}-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: dplNSGRules.outputs.rules[item.key]
  }
}]


@description('next-hop route table, if any')
resource routeTable 'Microsoft.Network/routeTables@2022-07-01' = if (!empty(routes)) {
  name: 'route-table'
  location: location
  tags: tags
  properties: {
    routes: routes
  }
}

var commonSubnetConfig = union({
  privateEndpointNetworkPolicies: 'Disabled'
  privateLinkServiceNetworkPolicies: 'Disabled'
}, empty(routes) ? {} : { routeTable: { id: routeTable.id } })

var osnets = filter(items(config.subnets), item => item.key != 'private-endpoints')
var snets = map(osnets, item => {
  name: item.key
  properties: union(commonSubnetConfig, {
      addressPrefix: item.value
      networkSecurityGroup: {
        id: resourceId('Microsoft.Network/networkSecurityGroups', '${item.key}-nsg')
      }
  })
})

@description('the virtual network')
resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: '${rsPrefix}-spoke'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: config.addressPrefixes
    }
    subnets: concat(snets, [{
        name: 'private-endpoints'
        properties: union(commonSubnetConfig, {
          addressPrefix: config.subnets['private-endpoints']
          networkSecurityGroup: {
            id: resourceId('Microsoft.Network/networkSecurityGroups', 'private-endpoints-nsg')
          }
        })
      }])
  }

  resource snetPrivateEndpoints 'subnets' existing = {
    name: 'private-endpoints'
  }

  dependsOn: [
    nsgs
  ]
}

//------------------------------------------------------------------------------
// diagnostic settings
resource nsgs_diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (item, index) in items(config.networkSecurityGroups): if (!empty(logConfig)) {
  scope: nsgs[index]
  name: 'diag'
  properties: union(logConfig, {logs: diagConfig.logs})
}]

resource vnetNSG_diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logConfig)) {
  scope: vnet
  name: '${vnet.name}-diag'
  properties: union(logConfig, diagConfig)
}

//------------------------------------------------------------------------------
// peerings
module mdlPeerFwd 'peering.bicep' = [for ovnetConfig in peerings: {
  name: take('${dplPrefix}-fwd-${ovnetConfig.name}', 64)
  params: {
    vnetName: vnet.name
    targetConfig: ovnetConfig
    enableGateway: false
    useRemoteGateway: ovnetConfig.useGateway
  }
}]

module mdlPeerRev 'peering.bicep' = [for ovnetConfig in peerings: {
  name: take('${dplPrefix}-rev-${ovnetConfig.name}', 64)
  scope: resourceGroup(ovnetConfig.group)
  params: {
    vnetName: ovnetConfig.name
    enableGateway: ovnetConfig.useGateway
    useRemoteGateway: false
    targetConfig: {
      name: vnet.name
      group: resourceGroup().name
    }
  }
}]

//------------------------------------------------------------------------------
@description('virtual network')
output vnet object = {
  group: resourceGroup().name
  name: vnet.name
  id: vnet.id
}

@description('subnet to use for all private endpoints')
output snetPrivateEndpoints object = {
  group: resourceGroup().name
  name: vnet.name
  snet: vnet::snetPrivateEndpoints.name
  snetId: vnet::snetPrivateEndpoints.id
}
