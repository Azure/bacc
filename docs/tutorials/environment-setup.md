# Prerequisites and Environment Setup

## Prerequisites

Before you can deploy the Azure resources and try out the demos, you need to ensure that you have the following:

1. __Ensure valid subscription__: Ensure that you a chargeable Azure subscription that you
   can use and you have __Owner__ access to the subscription.

2. __Ensure Batch service has authorization to access your subscription__. Using the portal,
   access your Subscription and select the __Access Control (IAM)__ page. Under there, we need to assign
  __Contributor__ or __Owner__ role to the Batch API. You can find this account by searching for
  __Microsoft Azure Batch__ (application ID should be __ddbf3205-c6bd-46ae-8127-60eb93363864__). For additional
  details, see [this](https://learn.microsoft.com/en-us/azure/batch/batch-account-create-portal#allow-azure-batch-to-access-the-subscription-one-time-operation).

3. __Validate Batch account quotas__: Ensure that the region you will deploy under has
   not reached its batch service quota limit. Your subscription may have limits on
   how many batch accounts can be created in a region. If you hit this limit, you
   may have to delete old batch account, or deploy to a different region, or have the
   limit increased by contacting your administrator.

4. __Validate compute quotas__: Ensure that the region you will deploy under has
   sufficient quota left for the SKUs picked for batch compute nodes. Each of the examples
   may use different SKUs. Look the example specific configuration file to determine which SKU
   it uses by default. In most examples, you can change the SKU in the config file for a different
   one, if so preferred.

Some of the examples use Batch pool allocation mode set to User Subscription. This mode has a few additional requirements:

1. __Accept legal terms__: The demos use container images that require you to accept
   legal terms. This only needs to be done once for the subscription. To accept these legal terms,
   you need to execute the following Azure CLI command once. You can do this using the
   [Azure Cloud Shell](https://ms.portal.azure.com/#cloudshell/) in the [Azure portal](https://ms.portal.azure.com)
   or your local computer. To run these commands on your local computer, you must have Azure CLI installed.

   ```sh
   # For Azure Cloud Shell, pick Bash (and not powershell)
   # If not using Azure Cloud Shell, use `az login` to login if needed.

   # accept image terms
   az vm image terms accept --urn microsoft-azure-batch:ubuntu-server-container:20-04-lts:latest
   ```

2. __Get Batch Service Id__: Based on your tenant, which may be different, hence it's
   best to confirm. In [Azure Cloud Shell](https://ms.portal.azure.com/#cloudshell/),
   run the following:

   ```sh
    az ad sp list --display-name "Microsoft Azure Batch" \
      --filter "displayName eq 'Microsoft Azure Batch'"  \
      --query "[].id" -o tsv

    # output some alpha numeric string e.g.
    f520d84c-3fd3-4cc8-88d4-2ed25b00d27a
   ```

   Save the value shown then you will need to enter that value,
   instead of the default, for `batchServiceObjectId` (shown as __Batch Service Object Id__,
   if deploying using the portal) when deploying the infrastructure.

   If the above returns an empty string, you may have to register "Microsoft.Batch" as a registered
   resource provider for your subscription. You can do that using the portal, browse to your `Subscription >
   Resource Providers` and then search for `Microsoft.Batch`. Or use the following command and then try
   the `az ad sp list ...` command again

   ```sh
   az provider register -n Microsoft.Batch --subscription <your subscription name> --wait
   ```

## Environment Setup

To create the deployment and try out several of the demos, you need access to workstation with
Azure CLI and Python (> 3.8) installed. You can use the [Azure Cloud Shell](https://ms.portal.azure.com/#cloudshell/)
in the [Azure portal](https://ms.portal.azure.com) or your local computer.

Typical steps to setup your environment are as follows:

1. Install Azure CLI. Follow the instructions [here](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
   for your operating system.
2. Install Python 3.10 or higher. Follow the instructions [here](https://www.python.org/downloads/).

3. Download source code from [GitHub](https://github.com/utkarshayachit/azbatch-starter). Since the repository uses
   submodules, it's easiest to clone the repository using `Git` as follows:

   ```bash
   cd [work-dir] # directory where you want to download the source code

   # clone the repository
   git clone --recursive https://github.com/utkarshayachit/azbatch-starter
   ```

   This fetches the code and all the submodules. If you have already cloned the repository, you can fetch the submodules
   using the following command:

   ```bash
   cd [work-dir]/azbatch-starter # directory where you downloaded the source code

   # fetch the submodules
   git submodule update --init --recursive
   ```

Steps `1` and `2` can be skipped if using Azure Cloud Shell since those tools / dependencies are already installed
in the default Cloud Shell environment.
