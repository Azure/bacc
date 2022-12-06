/**
  Deploys all resources necessary for gathering diagnostics information.
*/

@description('prefix to use for resources created')
param rsPrefix string

@description('location of all resources')
param location string

@description('tags to assign to all resources created')
param tags object

@description('SKU name for log analytics workspace')
@allowed([
  'CapacityReservation'
  'Free'
  'LACluster'
  'PerGB2018'
  'PerNode'
  'Premium'
  'Standalone'
  'Standard'
])
param workspaceSkuName string = 'PerGB2018'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-10-01' = {
  name: '${rsPrefix}-log-wks'
  location: location
  properties: {
    sku: {
      name: workspaceSkuName
    }
  }
  tags: tags
}

resource appInsightsComponents 'Microsoft.Insights/components@2020-02-02' = {
  name: '${rsPrefix}-appinsights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
  tags: tags
}

output logAnalyticsWorkspace object = {
  group: resourceGroup().name
  name: logAnalyticsWorkspace.name
  id: logAnalyticsWorkspace.id
}

output appInsights object = {
  group: resourceGroup().name
  name: appInsightsComponents.name
}
