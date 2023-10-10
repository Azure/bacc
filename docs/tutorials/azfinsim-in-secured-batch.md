# Deploying Secured-Batch

**Secured-Batch** models a reference architecture for a secured deployment of resources for use with Azure Batch.
The primary target for such a deployment is FSIs (Financial Services Institutions) that have strict security requirements. Of course, this
configuration can be a starting point for any deployment that requires a secure deployment.

For this tutorial, we will use configuration files from [examples/secured-batch] folder.
The `deployment.bicep` is the entry point for this deployment and `config.jonc` is the configuration
file that contains all the resource configuration parameters for this deployment.

The deployment deploys a hub using the `connectivity.bicep` template from the [azbatch-starter-connectivity]
repository. The hub is deployed in a separate resource group. The hub contains a firewall and a virtual network
gateway. The firewall is used to route all traffic from the compute nodes through a single point of egress.
The virtual network gateway is used to connect the hub to the spoke network. The spoke network is deployed
using the `deployment.bicep` template from the `bacc` repository. The spoke network contains
a virtual network and a batch account.

## Design Considerations

* **Private endpoints**: All resources deployed by bacc are accessible only via private endpoints. Network security
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

## Step 2: Deploy hub, spoke, and other resources

For this step, you have two options. You can use Azure CLI to deploy the resources using the bicep template provided. Or you can
simply click the following link to deploy using Azure Portal.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fbacc%2Fmain%2Ftemplates%2Fsecured-batch_deploy.json)

To deploy using the CLI, use the following steps:

```bash
#!/bin/bash
cd .../azbatch-starter-connectivity

AZ_LOCATION=eastsus2
AZ_DEPLOYMENT_NAME=azfinsim-sb
AZ_RESOURCE_GROUP=azfinsim-sb
BATCH_SERVICE_OBJECT_ID= ....  # should be set to the id obtained in prerequisites step

az deployment sub create                                    \
    --location $AZ_LOCATION                                 \
    --name $AZ_DEPLOYMENT_NAME                              \
    --template-file examples/secured-batch/deployment.bicep \
    --parameters                                            \
      resourceGroupName=$AZ_RESOURCE_GROUP_NAME             \
      batchServiceObjectId=$BATCH_SERVICE_OBJECT_ID

# >> ENTER PASSWORD:
#    the deployment will prompt for a password to use for jumpboxes, enter a string that
#    containers uppercase and lowercase letters, numbers.
```

On success, a new resource with the specified name will be created with all the resources deployed by this deployment.
Another resource group will be created with all resources that form the hub. The name of this resource group
can be obtained from the output of the deployment as follows:

```bash
#!/bin/bash

az deployment sub show \
  --name $AZ_DEPLOYMENT_NAME \
  --query properties.outputs.hubResourceGroupName.value
```

## Step 3: Connect to Windows Jumpbox

Once the deployment is complete, you can connect to the Windows jumpbox using Azure Bastion. Locate the Windows
jumpbox under the resource group created in the hub deployment. Click on the **Connect** button and follow the
instructions to connect to the jumpbox using Bastion. The username, by default, is set to `localadmin` and the password
is the password you provided during the hub deployment.

## Step 4: Connect to Linux Jumpbox

Once the deployment is complete, you can connect to the Linux jumpbox using Azure Bastion. Locate the Linux
jumpbox under the resource group created in the hub deployment. Click on the **Connect** button and follow the
instructions to connect to the jumpbox using Bastion. The username, by default, is set to `localadmin` and the password
is the password you provided during the hub deployment.

## Step 5: Setup CLI and submit jobs

Once connected to the Linux Jumpbox, you can now run the demo from there. The steps are same as the
[With Containers](./azfinsim.md) tutorial. Simply follow the steps after the deployment step
i.e. [`Step 3: Install CLI`](./azfinsim-linux.md#step-3-install-cli) onwards.
The only differences being the following:

* instead of using your local machine, you will execute the commands on the Linux jumpbox.
* to login in to Azure CLI, you have two options: either use your own credentials or use the managed identity
  created during the hub deployment. If you choose to use your own credentials, then you will need to login
  to Azure CLI using the following command:

  ```bash
  az login --use-device-code
  # ... follow the instructions posted on terminal to login
  ```

  To use managed identity, you can use the following command:

  ```bash
  az login --identity
  ```

  Experienced users will soon realize that even this logging in to Azure CLI on the jumpbox is not required.
  This is only necessary for the few commands we execute in the tutorial steps viz. obtaining the subscription ID.
  You can skip these CLI login steps and instead manually provide the subscription ID in the `bacc ...` commands.

[examples/secured-batch]: https://github.com/Azure/bacc/tree/main/examples/secured-batch
[azbatch-starter-connectivity]: https://github.com/mocelj/azbatch-starter-connectivity
