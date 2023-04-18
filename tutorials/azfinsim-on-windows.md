# Tutorial: AzFinsim on Windows

This tutorial shows how to run the AzFinsim application on a Windows pool. This is a good reference for users
attempting to run applications on Windows pools in Azure Batch.

## Key Design Considerations

* Uses Azure batch deployment without public IP address and private endpoints.
* Powershell script is used as a start task for pool to install Python and then pip install the AzFinSim application.
* CLI demonstrates how to use Azure Python SDK to submit jobs and tasks.
* The batch account pool allocation mode is set to Batch Service.

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

## Step 2: Prerequisites

1. **Ensure valid subscription**: Ensure that you a chargeable Azure subscription that you can use and you have Owner
   access to the subscription.

2. **Validate Batch account quotas**: Ensure that the region you will deploy under has not reached its batch service quota limit.
   Your subscription may have limits on how many batch accounts can be created in a region. If you hit this limit,
   you may have to delete old batch account, or deploy to a different region, or have the limit increased by contacting
   your administrator.

3. **Validate compute quotas**: Ensure that the region you will deploy under has not sufficient quota left for the SKUs
   picked for batch compute nodes. For this demo, we're using `Standard_DS5_V2`.

## Step 3: Setup deployment configuration

For demo, we will use configuration files from [examples/config1](../../examples/config1) folder. To use these files,
copy them to the config folder.

```bash
# change directory to azbatch-starter (or where you cloned/downloaded the repository)
cd azbatch-starter

# copy config files
cp examples/config1/* config/
```

## Step 4: Deploy the batch account and other resources

Create deployment using Azure CLI.

```bash
# replace all [PLACEHOLDER] with appropriate values
# for example, [LOCATION] can be westus2
#              [DEPLOYMENT_NAME] can be azbatch-starter
#              [PREFIX] can be <your initials>-<random string>
az deployment sub create                 \
    --location [LOCATION]                \
    --name [DEPLOYMENT_NAME]             \
    --template-file infrastructure.bicep \
    --parameters prefix=[PREFIX]
```

On success, a new resource group named `[PREFIX]-dev` will be created. This resource group will contain all the resources
deployed by this deployment.

## Step 5: Install CLI

Next, we install the CLI tool provided by this repository. This tool is used to submit jobs and tasks to the batch account.
We will use a python virtual environment to install the CLI tool to avoid polluting the global python environment.

```bash
# create a virtual environment
python3 -m venv env0

# activate the virtual environment
source env0/bin/activate

# install the CLI tool
pip install -e ./cli

# verify the CLI tool is installed
sb --help
# expected output ->
 Group
     sb
 
 Subgroups:
     pool     : Manage batch pools.
 
 Commands:
     azfinsim : Execute the azfinsim demo.
     show     : Show the configuration of the sbatch deployment.
```

## Step 6: Resize the pool

The pool is created with 0 nodes. We need to resize the pool to add nodes to it. The pool is created with a start task
that installs Python and then pip installs the AzFinSim application. The start task runs only once when the node is
for as long as it remains in the pool. This includes when the node is first added to the pool and when it is restarted
or reimaged.

```bash
# resize the pool to 1 node
sb pool resize                \
   -g [PREFIX]-dev            \  # resource group name
   -s [subscription-id]       \  # subscription id
   -p windows                 \  # pool name
   --target-dedicated-nodes 1

# this will block until the pool is resized and print the pool status
# on completion
{
  "current_dedicated_nodes": 1,
  "current_low_priority_nodes": 0
}
```

## Step 7: Submit a job

Next, we submit a job to the batch account. The job will contain 10 tasks that will run the AzFinSim application.

```bash
sb azfinsim                \
   -g [PREFIX]-dev         \  # resource group name
   -s [subscription-id]    \  # subscription id
   --mode package          \  # mode of execution (default is container, not covered in this tutorial)
   --num-tasks 10          \  # number of concurrent tasks to submit
   --num-trades 100        \  # number of trades to generate and process
   --algorithm pvonly         # algorithm to use (pvonly, deltavega)
```

## Step 8: Monitor the job

You can use the Azure portal to monitor the job. The portal will show the status of the job and the tasks.
You can also use Batch Explorer to monitor the job.

## Step 10: Inspect the results

The generated trades and the results are stored in Azure Storage account deployed as part of the infrastructure. To view the files on the portal follow the following steps:

1. Browse to the resource group `[PREFIX]-dev` in the Azure portal.
2. Locate the storage account named `afs[unique string]`. It's the only storage account in the resource group
   deployed by this demo.
3. By default, the storage account does not allow access to files from outside network. To change it,
   navigate to `Networking` tab and then select `Enabled from selected virutal networks and IP addresses` and
   add your IP address (which should be listed automatically in the portal). Then hit `Save`.
4. Navigate to `File Shares` tab and then select `data` file share. Then click on `Browse` tab to see
   the files. Each job submitted will create a folder with the job id which will have all the trades and results. The job id is printed in the output of the CLI tool when submitting the job.
