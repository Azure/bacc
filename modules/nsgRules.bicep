/**
  Simply builds a list of NSG rules.
*/

/**
Format:
{
  '<rulename>': {
    /// "properties" for the NSG security rule
    'description': '<description>',
    'protocol': '<protocol>',
    'sourcePortRange': '<sourcePortRange>',
    'destinationPortRange': '<destinationPortRange>',
    'sourceAddressPrefix': '<sourceAddressPrefix>',
    'destinationAddressPrefix': '<destinationAddressPrefix>',
    'access': '<access>',
    'priority': <priority>,
    'direction': '<direction>'
    ....
  },
  ....
}
*/
param nsgRules object = loadJsonContent('../config/nsgRules.jsonc')

/**
Format:
{
  "<key0>": [
    "<rulename>",
    "<rulename>",
    ...
  ],
  "<key1>": [
    "<rulename>",
    "<rulename>",
    ...
  ],
}
*/
param config object = loadJsonContent('../config/spoke.jsonc', 'networkSecurityGroups')

@description('priority number to start assigning priorities to rules.')
param priority int = 100

/// securityRues is a list-of-lists
var rules = [for item in items(config): map(item.value, ruleName => {
  name: ruleName
  properties: nsgRules[ruleName]
})]


/// separate inbound and outbound rules
var rulesIn0 = map(rules, rulesList=>filter(rulesList, rule => toLower(rule.properties.direction) == 'inbound'))
var rulesOut0 = map(rules, rulesList=>filter(rulesList, rule => toLower(rule.properties.direction) == 'outbound'))

/// assign priorities to inbound and outbound rules separately
var rulesIn = map(rulesIn0, rulesList => map(range(0, length(rulesList)), index => {
  name: rulesList[index].name
  properties: union({priority: index + priority}, rulesList[index].properties)
}))

var rulesOut = map(rulesOut0, rulesList => map(range(0, length(rulesList)), index => {
  name: rulesList[index].name
  properties: union({priority: index + priority}, rulesList[index].properties)
}))

/// combine the inbound and outbound rules into a single list
var rulesX = [for (item, index) in items(config): {
    key: item.key
    value: union(rulesIn[index], rulesOut[index])
}]

output rules object = toObject(rulesX, item=>item.key, item=>item.value)
