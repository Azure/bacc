/**
  This process diagnostics config from hub configuration and processes it
  to a standard format that the other modules can use.

  We intentionally handle this separately so that we can adopt this in future as needed
  if the hub configuration changes.
*/
targetScope = 'subscription'

@description('diagnotics config')
param diagnosticsConfig object

var workspaceId = contains(diagnosticsConfig, 'logAnalyticsWorkspace') && !contains(diagnosticsConfig.logAnalyticsWorkspace, 'id') ? diagnosticsConfig.logAnalyticsWorkspace.id : ''

var appInsights = contains(diagnosticsConfig, 'appInsights') && !empty(diagnosticsConfig.appInsights) ? diagnosticsConfig.appInsights : {}
var appId = contains(appInsights, 'appId') && !empty(appInsights.appId) ? appInsights.appId : ''
var intrumentationKey = contains(appInsights, 'instrumentationKey') && !empty(appInsights.instrumentationKey) ? appInsights.instrumentationKey : ''

output loggingEnabled bool = !empty(workspaceId)
output logConfig object = !empty(workspaceId) ? {
  workspaceId: workspaceId
} : {}

output appInsightsEnabled bool = !empty(appId) && !empty(intrumentationKey)
output appInsightsConfig object = !empty(appId) && !empty(intrumentationKey) ? {
  appId: appId
  instrumentationKey: intrumentationKey
} : {}
