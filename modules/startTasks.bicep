// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

param commands array
param isWindows bool
param environmentSettings array

// esape all double-quotes
var escapedCommands = map(commands, cmd => replace(cmd, '"', '\\"'))
var cmdPrefix = isWindows ? 'cmd /c "' : '/bin/sh -c "'
var cmdSuffix = '"'

output startTask object = {
  commandLine: '${cmdPrefix}${join(escapedCommands, ' && ')}${cmdSuffix}'
  environmentSettings: environmentSettings
  maxTaskRetryCount: 0
  userIdentity: {
    autoUser: {
      scope: 'pool'
      elevationLevel: 'admin'
    }
  }
}
