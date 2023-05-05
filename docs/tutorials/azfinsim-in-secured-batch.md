# Deploying Secured-Batch

**Secured-Batch** refers to a configuration of `sbatch` that is deployed in a secure manner. The primary target
for such a deployment is FSIs (Financial Services Institutions) that have strict security requirements. Of course, this
configuration can be a starting point for any deployment that requires a secure deployment.

## Design Considerations

* **Private endpoints**: All resources deployed by `sbatch` are accessible only via private endpoints. Network security
  rules prohibit access from public networks using Azure-provided name resolution. This includes storage accounts,
  key vaults, batch accounts, etc. This adds additional complexity when accessing these resources from your workstation, for
  example, but it is a necessary trade-off for a secure deployment.

* **User-subscription pool allocation mode**: Batch service is set up to use **User Subscription** as the pool allocation mode. This
  implies that all resources that Batch service itself needs for managing and deploying the pools are allocated under the user's
  subscription. This is in contrast to the default **Batch Subscription** mode where Batch service itself allocates the resources
  needed for managing and deploying the pools under the Batch service subscription. The advantage of using **User Subscription** mode
  is that the user has full control over the resources that are allocated for managing and deploying the pools. This is especially
  useful in a secure deployment where the user may want to restrict access to these resources to a specific set of users. This, however,
  does mean the deployer needs to have **Owner** access to the subscription. This is because the deployer needs to be able to create
  roles and assign roles to resources / subscription etc. This is not possible with **Contributor** access. Refer to
  updated requirements for user-subscription mode
  [here](https://learn.microsoft.com/en-us/azure/batch/batch-account-create-portal#configure-user-subscription-mode).

* **Reroute all traffic through firewall**: All outgoing traffic from the compute nodes is routed through a firewall. This is done
  to ensure that all traffic from the compute nodes is routed through a single point of egress. This is useful for monitoring and
  auditing purposes. This also means that the compute nodes do not have direct access to the Internet. This is not a problem for
  most workloads as the compute nodes can still access the Internet via the firewall. However, if your workload requires direct
  access to the Internet, then you will need to configure the firewall to allow such access.

* **TODO**: add other important design considerations.

## Step 1: Prerequisites and environment setup

Follow the [environment setup instructions](./environment-setup.md) to set up your environment. Since
this tutorial uses **User Subscription** pool allocation mode, make sure you follow the extra
requirements and steps described in that document for the same.

## Step 2: Select deployment configuration

For this tutorial, we will use default configuration and hence we don't need to change any of the config files -- a step we have
to do for other tutorials.

## Step 3: Deploy hub

Deploy the hub network and resources. For this demo, we will use Azure Bastion to get to the jumboxes that then allow us to access the resources.

```bash
#!/bin/bash
cd .../azbatch-starter-connectivity

AZ_LOCATION=eastsus2
AZ_HUB_DEPLOYMENT_NAME=azfinsim-sb-hub
AZ_HUB_PREFIX=azfinsim-sb-hub

az deployment sub create                \
    --location $AZ_LOCATION             \
    --name $AZ_HUB_DEPLOYMENT_NAME      \
    --template-file connectivity.bicep  \
    --parameters prefix=$AZ_HUB_PREFIX  \
       useSingleResourceGroup=true      \
       deployVPNGateway=false

# >> ENTER PASSWORD:
#    the deployment will prompt for a password to use for jumpboxes, enter a string that
#    containers uppercase and lowercase letters, numbers.
```

## Step 4: Fetch hub configuration

Once the deployment is complete, you can fetch the hub configuration using the following command:

```bash
#!/bin/bash
az deployment sub show           \
  --name $AZ_HUB_DEPLOYMENT_NAME \
  --query properties.outputs.azbatchStarter.value > /[location of your choice]/hub.jsonc
```

## Step 5: Deploy spoke with Batch account

Deploy the spoke network and resources.

```bash
#!/bin/bash

cd .../azbatch-starter

# replace default hub.jsonc with the hub.jsonc you downloaded in the previous step
cp [location of you chose earlier]/hub.jsonc config/hub.jsonc

AZ_LOCATION=eastsus2
AZ_DEPLOYMENT_NAME=azfinsim-sb # name for the deployment
AZ_RESOURCE_GROUP=azfinsim-sb  # name for the resource group
BATCH_SERVICE_OBJECT_ID= ....  # should be set to the id obtained in prerequisites step

az deployment sub create                              \
    --location $AZ_LOCATION                           \
    --name $AZ_DEPLOYMENT_NAME                        \
    --template-file infrastructure.bicep              \
    --parameters                                      \
      resourceGroupName=$AZ_RESOURCE_GROUP            \
      batchServiceObjectId=$BATCH_SERVICE_OBJECT_ID   \
      enableApplicationContainers=true
```

On success, a new resource group with the specified name will be created. This resource group will contain all
the resources deployed by this deployment.

## Step 6: Connect to Windows Jumpbox

Once the deployment is complete, you can connect to the Windows jumpbox using Azure Bastion. Locate the Windows
jumpbox under the resource group created in the hub deployment. Click on the **Connect** button and follow the
instructions to connect to the jumpbox using Bastion. The username, by default, is set to `localadmin` and the password
is the password you provided during the hub deployment.

## Step 7: Connect to Linux Jumpbox

Once the deployment is complete, you can connect to the Linux jumpbox using Azure Bastion. Locate the Linux
jumpbox under the resource group created in the hub deployment. Click on the **Connect** button and follow the
instructions to connect to the jumpbox using Bastion. The username, by default, is set to `localadmin` and the password
is the password you provided during the hub deployment.

## Step 8: Setup CLI and submit jobs

Once connected to the Linux Jumpbox, you can now run the demo from there. The steps are same as the [With Containers](./azfinsim.md) tutorial.
Simply follow the steps after the deployment step i.e. [`Step 4: Install CLI`](./azfinsim.md#step-4-install-cli) onwards.
The only difference being instead of executing those commands on your local machine, you will execute them on the Linux jumpbox.
