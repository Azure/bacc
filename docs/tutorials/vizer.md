# Tutorial: Interactive 3D web visualization with vizer / vizer-hub

This tutorial is a step-by-step guide on how to deploy [`vizer-hub`](https://github.com/utkarshayachit/vizer-hub),
a NodeJS-based web-server, using an Azure App Service. `vizer-hub` is configured to use Azure Batch as the compute backend
for running the visualization tasks.

For this tutorial, we will use configuration files from [examples/vizer] folder.
The `deployment.bicep` is the entry point for this deployment and `config.jonc` is the configuration file that contains all the
To use these files, copy them to the config folder.

## Key Design Elements

* `vizer-hub`, deployed as an Azure App Service, acts as the landing page for users. The UI allows users to browse
  a connected blob storage container and select dataset(s) to visualize. Once selected, the app then submits a
  job to the connected Azure Batch account to run an interactive visualization task for the selected dataset(s).
  This task is an instance of the [`vizer`](https://github.com/utarshayachit/vizer) visualization application
  which itself launches an HTTP server to serve the interactive visualization over WebSockets.
* `vizer-hub` also acts as web server proxy allowing the users' web browser to connect to the
  `vizer` web server running on the compute node.
* In this tutorial, we use an existing storage account for the datasets instead of creating a new one. Either a SAS token
  or a storage account key can be used to connect to the storage account. These must be passed as parameters to
  the deployment. If you want to let the deployment create a new storage account, then do not provide any of the
  `storage*` parameters described below.
* Uses Azure Batch service deployed with pool allocation mode set to **Batch Service**.
* Both `vizer-hub` and `vizer` are packaged as container images. The container images are pulled from a
  Docker Hub repository.

## Step 1: Prerequisites and environment setup

Follow the [environment setup instructions](./environment-setup.md) to set up your environment. Since
this tutorial uses **Batch Service** pool allocation mode, you can skip the **User Subscription** specific
requirements and  steps described in that document.

This tutorial is designed to use an existing storage account for the datasets instead of creating a new one. If you don't already
have one, create a storage with a blob container and upload some datasets to it. Make sure the storage account is accessible
from a public network. If you want to let the deployment create a new storage account, then do not provide any of the
`storage*` parameters described below.

## Step 2: Deploy the batch account and other resources

For this step, you have two options. You can use Azure CLI to deploy the resources using the bicep template provided. Or you can
simply click the following link to deploy using Azure Portal.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fbacc%2Fmain%2Ftemplates%2Fvizer_deploy.json)

To create deployment using Azure CLI for these steps. Since in this example we are using an existing storage account, we need to
provide the storage account name, container name and the account access key or SAS token to access it.

```bash 
#!/bin/bash

# create deployment
AZ_LOCATION=eastus2
AZ_DEPLOYMENT_NAME=vizer0
AZ_RESOURCE_GROUP=vizer0

# storage credentials
AZ_STORAGE_ACCOUNT_NAME='<storage-account-name>'
AZ_STORAGE_ACCOUNT_CONTAINER='<storage-account-container>'
AZ_STORAGE_ACCOUNT_SAS_TOKEN='<storage-account-sas-token>'

az deployment sub create                                    \
  --name $AZ_DEPLOYMENT_NAME                                \
  --location $AZ_LOCATION                                   \
  --template-file examples/vizer/deployment.bicep           \
  --parameters                                              \
      resourceGroupName=$AZ_RESOURCE_GROUP                  \
      storageAccountName=$AZ_STORAGE_ACCOUNT_NAME           \
      storageAccountContainer=$AZ_STORAGE_ACCOUNT_CONTAINER \
      storageAccountSasToken=$AZ_STORAGE_ACCOUNT_SAS_TOKEN

# To use storage account key instead of SAS token, use the following parameters instead.
AZ_STORAGE_ACCOUNT_KEY='<storage-account-key>'
az deployment sub create                                    \
  --name $AZ_DEPLOYMENT_NAME                                \
  --location $AZ_LOCATION                                   \
  --template-file examples/vizer/deployment.bicep           \
  --parameters                                              \
      resourceGroupName=$AZ_RESOURCE_GROUP                  \
      storageAccountName=$AZ_STORAGE_ACCOUNT_NAME           \
      storageAccountContainer=$AZ_STORAGE_ACCOUNT_CONTAINER \
      storageAccountKey=$AZ_STORAGE_ACCOUNT_KEY
```

> **NOTE**:
> Only one of `storageAccountKey` or `storageAccountSasToken` parameters must be provided.
> If both are provided, `storageAccountKey` will be used.

> **NOTE**:
> To let the deployment create a new storage account instead of using an existing one,
> simply skip all the `storage*` parameters.

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

Once the web-server has started, you can navigate to the URL and start using the application. Before visualizing any dataset,
you will first want to resize the Batch account pool to have at least 1 node to run the visualization tasks. You can do this
using the following command.

```bash
# resize pool
bacc pool resize -s $AZ_SUBSCRIPTION_ID -g $AZ_RESOURCE_GROUP -p linux --target-dedicated-nodes 1
# this will block until the pool is resized and then print the following:
{
  "current_dedicated_nodes": 1,
  "current_low_priority_nodes": 0
}
```

You can also use the Azure Portal or Azure Batch Explorer to resize the pool.
