param vnetName string
param targetConfig object
param enableGateway bool = false
param useRemoteGateway bool 

resource vnet 'Microsoft.Network/virtualNetworks@2022-09-01' existing = {
  name: vnetName
}

resource target 'Microsoft.Network/virtualNetworks@2022-09-01' existing = {
  name: targetConfig.name
  scope: resourceGroup(targetConfig.group)
}

resource peering0 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-09-01' = {
  name: '${targetConfig.group}_${targetConfig.name}'
  parent: vnet
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true 
    allowGatewayTransit: enableGateway
    useRemoteGateways: useRemoteGateway
    remoteVirtualNetwork: {
      id: target.id
    }
  }
}
