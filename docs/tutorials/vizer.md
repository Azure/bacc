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
To use these files, copy them to the config folder.

```bash
# change directory to azbatch-starter (or where you cloned/downloaded the repository)
cd azbatch-starter

# copy config files
cp examples/vizer/*.jsonc config/
```

After copying the files, edit the `config/storage.jsonc` file to set the storage account name and SAS token or storage account key
to use.

## Step 3: Deploy the batch account and other resources

Create deployment using Azure CLI. The deployment is split into two parts. First, we deploy the
core set of resources using the `infrastructure.bicep` template. Then, we deploy the `vizer-hub`
application using the `vizer-hub.bicep` template.

```bash
#!/bin/bash

# create deployment
AZ_LOCATION=eastus2
AZ_DEPLOYMENT_NAME=vizer0
AZ_RESOURCE_GROUP=vizer0

az deployment sub create                  \
  --name $AZ_DEPLOYMENT_NAME              \
  --location $AZ_LOCATION                 \
  --template-file infrastructure.bicep    \
  --parameters                            \
      resourceGroupName=$AZ_RESOURCE_GROUP
```

Once the deployment is successful, you generate a config file for the `vizer-hub` deployment.

```bash
#!/bin/bash

# create config file
az deployment sub show \
  --name $AZ_DEPLOYMENT_NAME \
  --query properties.outputs.summary.value \
  --output json > /tmp/vizer-hub.json
```

Now, let's deploy the `vizer-hub` application.

```bash
#!/bin/bash

AZ_HUB_DEPLOYMENT_NAME=vizer-hub0

# create deployment
az deployment group create                              \
  --name $AZ_HUB_DEPLOYMENT_NAME                        \
  --resource-group $AZ_RESOURCE_GROUP                   \
  --template-file examples/vizer/vizer-hub.bicep        \
  --parameters                                          \
      config=@/tmp/vizer-hub.json
```

On success, a new resource group will be created with the name specified.
To obtain the URL for the `vizer-hub` web server, run the following command.

```bash
#!/bin/bash

az deployment group show \
  --name $AZ_HUB_DEPLOYMENT_NAME \
  --resource-group $AZ_RESOURCE_GROUP \
  --query properties.outputs.vizerHubUrl.value \
  --output tsv
```

Once the web-server has started, you can navigate to the URL and start using the application.
