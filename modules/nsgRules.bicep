// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

/**
  Simply builds a list of NSG security rules objects from a list of NSG rule names
*/

param ruleNames array

@description('priority number to start assigning priorities to rules.')
param priority int = 100

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
var nsgRules = loadJsonContent('./nsgRules.jsonc')

/// securityRues is a list-of-lists
var rules =  map(ruleNames, ruleName => {
  name: ruleName
  properties: nsgRules[ruleName]
})

/// separate inbound and outbound rules
var rulesIn0 = filter(rules, rule => toLower(rule.properties.direction) == 'inbound')
var rulesOut0 = filter(rules, rule => toLower(rule.properties.direction) == 'outbound')

/// assign priorities to inbound and outbound rules separately
var rulesIn = map(range(0, length(rulesIn0)), index => {
  name: rulesIn0[index].name
  properties: union({priority: index + priority}, rulesIn0[index].properties)
})

var rulesOut = map(range(0, length(rulesOut0)), index => {
  name: rulesOut0[index].name
  properties: union({priority: index + priority}, rulesOut0[index].properties)
})

output rules array = concat(rulesIn, rulesOut)
