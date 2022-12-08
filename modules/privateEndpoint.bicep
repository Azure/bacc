/**
  Helper to deploy a private endpoint together with a DNS zone / group etc.
*/
param location string = resourceGroup().location

@description('name for the endpoint')
param name string

@description('private link service id')
param privateLinkServiceId string

param groupIds array

param privateDnsZone object = {
  name: ''
  group: ''
}

@description('the subnet under which to deploy the private endpoints')
@metadata({
  group: 'name of the vnet group'
  name: 'name of the vnet resource'
  snet: 'name of the subnet'
})
param vnetInfo  object = {
  name: null
  group: null
  snet: null
}

param tags object = {}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: vnetInfo.name
  scope: resourceGroup(vnetInfo .group)
}

resource snet 'Microsoft.Network/virtualNetworks/subnets@2022-05-01' existing = {
  name: vnetInfo.snet
  parent: virtualNetwork
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-05-01' = {
  name: name
  tags: tags
  location: location
  properties: {
    subnet: {
      id: snet.id
    }
    privateLinkServiceConnections: [
      {
        name: name
        properties: {
          privateLinkServiceId: privateLinkServiceId
          groupIds: groupIds
        }
      }
    ]
  }
}

resource dnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: privateDnsZone.name
  scope: resourceGroup(privateDnsZone.group)
}

resource pvtEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = {
  name: 'dnsgroup'
  parent: privateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: dnsZone.id
        }
      }
    ]
  }
}
