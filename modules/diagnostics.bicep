/**
  This process diagnostics config from hub configuration and processes it
  to a standard format that the other modules can use.

  We intentionally handle this separately so that we can adopt this in future as needed
  if the hub configuration changes.
*/
targetScope = 'subscription'

@description('diagnotics config')
param diagnosticsConfig object

var sanitizedConfig = union({
  logAnalyticsWorkspace: {}
  appInsights: {}
}, diagnosticsConfig)

var sanitizedLA = union({
  id: ''
}, sanitizedConfig.logAnalyticsWorkspace)

var workspaceId = sanitizedLA.id

var sanitizedAI = union({
  appId: ''
  instrumentationKey: ''
}, sanitizedConfig.appInsights)

var appId = sanitizedAI.appId
var intrumentationKey =  sanitizedAI.instrumentationKey

output loggingEnabled bool = !empty(workspaceId)
output logConfig object = !empty(workspaceId) ? {
  workspaceId: workspaceId
} : {}

output appInsightsEnabled bool = !empty(appId) && !empty(intrumentationKey)
output appInsightsConfig object = !empty(appId) && !empty(intrumentationKey) ? {
  appId: appId
  instrumentationKey: intrumentationKey
} : {}
