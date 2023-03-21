param mounts object
param storageConfigurations object
param isWindows bool

var sconfigs = map(items(mounts), item => union(storageConfigurations[item.value], {key: item.key}))
// Format:
//    configs == [{"name":...,"group":...,"kind":"file", "key": ....}, ...]

// remove unsupported configs e.g. blob storage is not supported on Windows
var chosen = isWindows ? filter(sconfigs,  c => c.kind != 'blob') : sconfigs

var configs = [for (c,index) in chosen: c.kind == 'blob' ? {
  // pre: isWindows == false
  nfsMountConfiguration: {
    mountOptions: '-o sec=sys,vers=3,nolock,proto=tcp,rw'
    relativeMountPath: c.key
    source: '${c.name}.blob.${az.environment().suffixes.storage}:/${c.name}/${c.container}'
  }
} : {
  azureFileShareConfiguration: {
    relativeMountPath: c.key
    mountOptions: isWindows? '' : '-o vers=3.0,dir_mode=0777,file_mode=0777,sec=ntlmssp'
    accountName: c.name
    accountKey: c.accountKey // FIXME: this should use a 'secret'
    azureFileUrl: 'https://${c.name}.file.${az.environment().suffixes.storage}/${c.share}'
  }

}]

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
