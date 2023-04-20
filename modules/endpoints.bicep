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

@description('resource group name for existing dns zones')
param existingDnsZones array

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

// let's convert the existingDnsZones array into a map
// key: dns zone name, value: resource-group name
var existingDnsZonesObject = toObject(existingDnsZones, item => item.name, item => item.group)

var newDnsZoneNames = filter(dnsZoneNames, name => !contains(existingDnsZonesObject, name))
var newDnsZonesObject = toObject(newDnsZoneNames, arg => arg, arg => resourceGroup().name)

var dnsZonesObject = union(existingDnsZonesObject, newDnsZonesObject)

@description('deploy new dns zones, if needed')
resource privateDnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for zone in newDnsZoneNames: {
  name: zone
  location: 'global'
  properties: {}
  tags: tags
}]

module dplVNetLinks 'vnetLinks.bicep' = [for (item, idx) in items(dnsZonesObject): {
  name: take('vnetLinks-${item.key}-${idx}-${dplSuffix}', 64)
  scope: resourceGroup(item.value)
  params: {
    dnsZoneName: item.key
    vnetInfo: snetInfo
    suffix: suffix
    tags: tags
  }
  dependsOn: [
    privateDnsZones
  ]
}]

module dplPrivateEndpoints 'privateEndpoint.bicep' = [for (item, idx) in endpoints: {
  name: take('privateEndpoint-${uniqueString(item.name, '${idx}')}-${dplSuffix}', 64)
  scope: resourceGroup(item.group)
  params: {
    name: '${item.name}-${idx}-pl'
    location: location
    privateDnsZone: {
      group: dnsZonesObject[item.privateDnsZoneName]
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
