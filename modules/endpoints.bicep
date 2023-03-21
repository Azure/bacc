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

@description('suffix used for resources')
param suffix string

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
var dplSuffix = uniqueString(resourceGroup().id, deployment().name, location)

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
  name: 'link-${vnet.name}${suffix}'
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
  name: take('privateEndpoint-${uniqueString(item.name, '${idx}')}-${dplSuffix}', 64)
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
    subnetId: snetInfo.snetId
  }
  dependsOn: [
    privateDnsZones
  ]
}]
