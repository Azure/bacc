// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

param mounts object
param storageConfigurations object
param isWindows bool
param mi string

var sconfigs = map(items(mounts), item => union(storageConfigurations[item.value], {key: item.key}))
// Format:
//    configs == [{"name":...,"group":...,"kind":"file", "key": ....}, ...]

var blobNFSConfigs = isWindows ? [] : filter(sconfigs, c => c.kind == 'blob' && c.nfsv3 == true)
var blobBFSConfigs = isWindows ? [] : filter(sconfigs, c => c.kind == 'blob' && c.nfsv3 == false)
var fsConfigs = filter(sconfigs, c => c.kind == 'file')

var configsNFS = map(blobNFSConfigs, c => {
  // pre: isWindows == false
  nfsMountConfiguration: {
    mountOptions: '-o sec=sys,vers=3,nolock,proto=tcp,rw'
    relativeMountPath: c.key
    source: '${c.name}.blob.${az.environment().suffixes.storage}:/${c.name}/${c.container}'
  }
})

var configsBFS = map(blobBFSConfigs, c => {
  // pre: isWindows == false
  azureBlobFileSystemConfiguration : union({
    accountName: c.name
    containerName: c.container
    blobfuseOptions: '-o attr_timeout=240 -o entry_timeout=240 -o negative_timeout=120 -o allow_other'
    relativeMountPath: c.key
  }, !empty(c.credentials) ? c.credentials : {
    identityReference: {
      resourceId: mi
    }
  })
})

var configsFS = map(fsConfigs, c => {
  azureFileShareConfiguration: union(isWindows? {} : {
    // only added for linux
    mountOptions: '-o vers=3.0,dir_mode=0777,file_mode=0777,sec=ntlmssp'
  } , {
    relativeMountPath: c.key
    accountName: c.name
    accountKey: c.accountKey // FIXME: this should use a 'secret'
    azureFileUrl: 'https://${c.name}.file.${az.environment().suffixes.storage}/${c.share}'
  })
})

var configs = concat(configsNFS, configsBFS, configsFS)
/**
  Format:
  [
    {
      "nfsMountConfiguration": {
        ...
      }
    },
    {
      "...": {
        ...
      }
    },
    ...
  ]
  {

  }
*/
output mountConfigurations array = filter(configs, c => !empty(c))
// output mountConfigurations array = []
