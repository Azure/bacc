// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

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
param subnetId string
param tags object = {}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-05-01' = {
  name: name
  tags: tags
  location: location
  properties: {
    subnet: {
      id: subnetId
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
