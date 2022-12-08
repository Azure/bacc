/**
@allowed([
  {
    name: sa.name
    group: resourceGroup().name
    privateLinkServiceId: sa.id
    groupIds: ['blob']
    privateDnsZoneName: 'privatelink.blob.${environment().suffixes.storage}'
  }
])
*/
@description('array of endpoints to deploy')
param endpoints array

@description('prefix use for deployments')
param dplPrefix string

@description('prefix used for resources')
param rsPrefix string

@description('tags')
param tags object

@description('subnet info')
@metadata({
  name: 'vnet name'
  group: 'vnet group'
  snet: 'snet-name'
  snetId: 'snetId'
})
param snetInfo object

@description('location for all resources')
param location string = resourceGroup().location

var dnsZoneNames = union(map(endpoints, item => item.privateDnsZoneName), [])

@description('deploy dns zones')
resource privateDnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for zone in dnsZoneNames: {
  name: zone
  location: 'global'
  properties: {}
  tags: tags
}]

resource vnet  'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: snetInfo.name
  scope: resourceGroup(snetInfo.group)
}

resource links 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (item, index) in dnsZoneNames: {
  parent: privateDnsZones[index]
  name: '${rsPrefix}-${vnet.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
  tags: tags
}]

module dplPrivateEndpoints 'privateEndpoint.bicep' = [for (item, idx) in endpoints: {
  name: '${dplPrefix}-${item.name}-${idx}-eps'
  scope: resourceGroup(item.group)
  params: {
    name: '${item.name}-${idx}-pl'
    location: location
    privateDnsZone: {
      group: resourceGroup().name
      name: item.privateDnsZoneName
    }

    privateLinkServiceId: item.privateLinkServiceId
    groupIds: item.groupIds
    vnetInfo: snetInfo
  }
  dependsOn: [
    privateDnsZones
  ]
}]
