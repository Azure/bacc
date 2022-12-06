/**
  Deploys core resources needed for batch.
*/

@description('prefix to use for resources created')
param rsPrefix string

@description('prefix to use for all deployments')
param dplPrefix string

@description('location of all resources')
param location string

@description('tags to assign to all resources created')
param tags object

