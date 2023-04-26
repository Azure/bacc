param dnsZoneName string
param vnetInfo object = {
  group: null
  name: null
}
param tags object = {}

resource dnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: dnsZoneName
}

resource vnet 'Microsoft.Network/virtualNetworks@2022-09-01' existing = {
  scope: resourceGroup(vnetInfo.group)
  name: vnetInfo.name
}

resource link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: dnsZone
  name: 'link-${vnetInfo.group}-${vnetInfo.name}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
  tags: tags
}
