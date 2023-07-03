/**
  Deploy a vnet for our use.
*/
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

@description('spoke configuration')
@secure()
param spokeJS object

var config = union(spokeJS, {
  delegations: {}
})

var diagConfig = loadJsonContent('./diagnostics.json')

@description('suffix to use for all nested deployments')
var dplSuffix = uniqueString(deployment().name)

//----------------------------------------------------------------------------------------------------------------------
// build nsg security rules.
module dplNSGRules 'nsgRules.bicep' = {
  name: 'nsgRules-${dplSuffix}'
  params: {
    config: config.networkSecurityGroups
  }
}

//----------------------------------------------------------------------------------------------------------------------
resource nsgs 'Microsoft.Network/networkSecurityGroups@2022-09-01' = [for item in items(config.networkSecurityGroups): {
  name: 'nsg-${item.key}'
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

// process snet delegations
var delegationsConfigsArray = map(items(config.delegations), item => {
  key: item.key
  delegations: map(item.value, sname => {
    name: sname
    properties: {
      serviceName: sname
    }
  })
})

var delegationsConfigs = reduce(delegationsConfigsArray, {}, (cur, next) => union(cur, {
  '${next.key}' : {
    delegations: next.delegations
  }
}))

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
        id: resourceId('Microsoft.Network/networkSecurityGroups', 'nsg-${item.key}')
      }
  }, contains(delegationsConfigs, item.key) ? delegationsConfigs[item.key] : {})
})

@description('the virtual network')
resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: 'spoke-batch'
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
            id: resourceId('Microsoft.Network/networkSecurityGroups', 'nsg-private-endpoints')
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
  name: take('peering-fwd-${ovnetConfig.name}-${dplSuffix}',64)
  params: {
    vnetName: vnet.name
    targetConfig: ovnetConfig
    enableGateway: false
    useRemoteGateway: ovnetConfig.useGateway
  }
}]

module mdlPeerRev 'peering.bicep' = [for ovnetConfig in peerings: {
  name: take('peering-rev-${ovnetConfig.name}-${dplSuffix}', 64)
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

@description('gateway peering deployed')
// output gatewayPeeringEnabled bool = !empty(filter(peerings, item => item.useGateway))
output gatewayPeeringEnabled bool = !empty(peerings)
