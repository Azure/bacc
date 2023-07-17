# Tutorial: Interactive 3D web visualization with vizer / vizer-hub

This tutorial is a step-by-step guide on how to deploy [`vizer-hub`](https://github.com/utkarshayachit/vizer-hub),
a NodeJS-based web-server, using an Azure App Service. `vizer-hub` is configured to use Azure Batch as the compute backend
for running the visualization tasks.

## Key Design Elements

* `vizer-hub`, deployed as an Azure App Service, acts as the landing page for users. The UI allows users to browse
  a connected blob storage container and select dataset(s) to visualize. Once selected, the app then submits a
  job to the connected Azure Batch account to run an interactive visualization task for the selected dataset(s).
  This task is an instance of the [`vizer`](https://github.com/utarshayachit/vizer) visualization application
  which itself launches an HTTP server to serve the interactive visualization over WebSockets.
* `vizer-hub` also acts as web server proxy allowing the users' web browser to connect to the
  `vizer` web server running on the compute node.
* In this tutorial, we use an existing storage account for the datasets instead of creating a new one. Either a SAS token
  or a storage account key can be used to connect to the storage account. These must be provided in the
  [`storage.jsonc`](../../examples/vizer/storage.jsonc) configuration file during deployment.
* Uses Azure Batch service deployed with pool allocation mode set to **Batch Service**.
* Both `vizer-hub` and `vizer` are packaged as container images. The container images are pulled from a
  Docker Hub repository.

## Step 1: Prerequisites and environment setup

Follow the [environment setup instructions](./environment-setup.md) to set up your environment. Since
this tutorial uses **Batch Service** pool allocation mode, you can skip the **User Subscription** specific
requirements and  steps described in that document.

This tutorial is designed to use an existing storage account for the datasets instead of creating a new one. If you don't already
have one, create a storage with a blob container and upload some datasets to it. Make sure the storage account is accessible
from a public network. If you want the deployment to create a new storage account, you can modify the
[`storage.jsonc`](../../examples/vizer/storage.jsonc) configuration file by simply removing the `credentials` section.

## Step 2: Select deployment configuration

For this tutorial, we will use configuration files from [examples/vizer] folder.
The `deployment.bicep`
is the entry point for this deployment and `config.jonc` is the configuration file that contains all the
To use these files, copy them to the config folder.

## Step 3: Deploy the batch account and other resources

Create deployment using Azure CLI. Since in this example we are using an existing storage account, we need to
provide the storage account name and the SAS token to access it. The SAS token must have read access to the
storage account. Before running the deployment, make sure you have the SAS token ready and update the
[`storage.json`] configuration file with the storage account name and the SAS token.

```bash 
#!/bin/bash

# create deployment
AZ_LOCATION=eastus2
AZ_DEPLOYMENT_NAME=vizer0
AZ_RESOURCE_GROUP=vizer0

# storage credentials
AZ_STORAGE_CREDENTIALS="{\"accountName\": \"<storage-account-name>\", \"sasToken\": \"<sas-token>\"}"
# or you can use storage account access key as follows
# AZ_STORAGE_CREDENTIALS="{\"accountName\": \"<storage-account-name>\", \"accountKey\": \"<storage-account-key>\"}"

az deployment sub create                          \
  --name $AZ_DEPLOYMENT_NAME                      \
  --location $AZ_LOCATION                         \
  --template-file examples/vizer/deployment.bicep \
  --parameters                                    \
      resourceGroupName=$AZ_RESOURCE_GROUP        \
      storageCredentials=$AZ_STORAGE_CREDENTIALS
```

On success, a new resource group will be created with the name specified.
To obtain the URL for the `vizer-hub` web server, run the following command.

```bash
#!/bin/bash

az deployment group show \
  --name $AZ_DEPLOYMENT_NAME \
  --resource-group $AZ_RESOURCE_GROUP \
  --query properties.outputs.vizerHubUrl.value \
  --output tsv
```

Once the web-server has started, you can navigate to the URL and start using the application.
