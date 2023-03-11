/**
*/
param key string
param objectKey string
param objectList array

output result array = [for config in objectList: {
  '${objectKey}': union(config[objectKey], {
    accountKey: key
  })
}]
