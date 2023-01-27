targetScope = 'subscription'

@description('hub network configuration')
param networkConfig object

var hasUDR = contains(networkConfig, 'routes') && length(networkConfig.routes) > 0

/**
  Routes should be defined as an array of objects with the following properties:
  {
    "routes": [
      {
        "name": "route1",
        "addressPrefix": ....
        "nextHopType": ....
        "nextHopIpAddress": ....
      },
      // more routes
    ]
  }
*/
@description('next-hop routes for subnet')
output routes array = !hasUDR ? [] : map(range(0, length(networkConfig.routes)), i => {
   name: contains(networkConfig.routes[i], 'name') ? networkConfig.routes[i].name : 'route_${i}'
   properties: {
     addressPrefix: networkConfig.routes[i].addressPrefix
     nextHopType: networkConfig.routes[i].nextHopType
     nextHopIpAddress: networkConfig.routes[i].nextHopIpAddress
   }
})
