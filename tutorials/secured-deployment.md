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

## Step 1: Prepare the environment

1. Install Azure CLI. Follow the instructions [here](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli).
   This tutorial assumes you are on a Unix shell or a WSL2 under Windows. This is not a requirement and you should be
   able to run the same commands on a Windows CMD terminal too.

2. Install Python 3.10 or higher. Follow the instructions [here](https://www.python.org/downloads/).

3. Download source code from [GitHub](https://github.com/utkarshayachit/azbatch-starter). You can either download the
   source code as a [zip file](https://github.com/utkarshayachit/azbatch-starter/archive/refs/heads/main.zip)
   or clone the repository using `git`.

   ```bash
   # clone the repository
   git clone https://github.com/utkarshayachit/azbatch-starter
   ```

4. Download connectivity source code from [GitHub](https://github.com/mocelj/azbatch-starter-connectivity). You can either
   download the source ode as a [zip file](https://github.com/mocelj/azbatch-starter-connectivity/archive/refs/heads/main.zip)
   or clone the repository using `git`.

   ```bash
   # clone the repository
   git clone https://github.com/mocelj/azbatch-starter-connectivity/
   ```

## Step 2: Prerequisites

> **TODO**: link back to shared prerequisites for user-subscription mode.

## Step 3: Deploy hub

Deploy the hub network and resources. For this demo, we will use Azure Bastion to get to the jumboxes that then allow us to access the resources.

```bash
#!/bin/bash
cd azbatch-starter-connectivity

# replace all [PLACEHOLDER] with appropriate values
# for example, [LOCATION] can be westus2
#              [DEPLOYMENT_NAME] can be azbatch-starter-conn
#              [HUB_PREFIX] can be <your initials>-<random string>-hub

az deployment sub create                \
    --location [LOCATION]               \ 
    --name     [DEPLOYMENT_NAME]        \
    --template-file connectivity.bicep  \
    --parameters prefix=[HUB_PREFIX]    \
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
az deployment sub show      \
  --name [DEPLOYMENT_NAME]  \
  --query properties.outputs.azbatchStarter.value > /[location of your choice]/hub.jsonc
```

## Step 5: Deploy spoke with Batch account

Deploy the spoke network and resources.

```bash
#!/bin/bash

cd azbatch-starter

# replace default hub.jsonc with the hub.jsonc you downloaded in the previous step
cp [location of you chose earlier]/hub.jsonc config/hub.jsonc

# replace all [PLACEHOLDER] with appropriate values
# for example, [LOCATION] can be westus2
#              [DEPLOYMENT_NAME] can be azbatch-starter
#              [SPOKE_PREFIX] can be <your initials>-<random string>
# [BATCH_SERVICE_OBJECT_ID] should be set to the id obtained in prerequisites step.


az deployment sub create                 \
    --location [LOCATION]                \
    --name [DEPLOYMENT_NAME]             \
    --template-file infrastructure.bicep \
    --parameters prefix=[SPOKE_PREFIX]   \
      batchServiceObjectId=[BATCH_SERVICE_OBJECT_ID] \
      enableApplicationContainers=true
```

On success, a new resource group named `[SPOKE_PREFIX]-dev` will be created. This resource group will contain all
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

## Step 8: Setup CLI on Linux Jumpbox

For this demo, we will use the Linux jumpbox to submit jobs for execution on the Batch pools. Here are the steps

```bash

# login to Azure CLI
az login

# clone the repository
git clone https://github.com/utkarshayachit/azbatch-starter

# install pip
sudo apt install python3-pip python3-venv

# install CLI
cd azbatch-starter

# create virtual env
python3 -m venv env0

# activate virtual env
source env0/bin/activate

# install CLI
python3 -m pip install ./cli

# verify installation
sb --help

# resize linux pool
sb pool resize -g [SPOKE_PREFIX]-dev -s [subscription id] \
   -p linux --target-dedicated-nodes 1

# submit azfinsim job
sb azfinsim -g [SPOKE_PREFIX]-dev -s [subscription id] \
   --algorithm pvonly --num-trades 100 --num-tasks 10
```
