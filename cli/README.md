# Command Line Interface (CLI)

One the deployment is complete, one can use the Azure Portal or Azure CLI to interact with the resources
to do various tasks like resizing batch pools, submitting jobs etc.

You can also use CLI tool developed specifically for this project to make it easier to work with the deployment
and included demos. The tool also demonstrate how one can develop such tools to make it easy for non-expert users to
interact with your specific deployments to perform common tasks with ease.

The CLI is developed using Python and is available as a Python package. The CLI is modelled after Azure CLI
for consistency and familiarity.

## Installation

To install the CLI extensions, use the following command once you have installed
Azure CLI on your workstation.

```sh
# install the CLI tools
> pip install -e ./cli

# verify that the CLI tools are installed
> sb --help
```

## Usage

Once the CLI is installed, you can use the `sb ...` command to interact with the `sbatch`.
The commands have the following format:

```sh
> sb [command] [subcommand] [parameters]
```

You can use `--help` to get help on the commands and subcommands.

```sh
# `--help` shows all available commands
> sb --help

Group
    sb

Subgroups:
    pool     : Manage batch pools.

Commands:
    azfinsim : Execute the azfinsim demo.
    show     : Show the configuration of the sbatch deployment.
```

### `sb show`

`sb show` command can be used to get information about the deployment. This is useful to get
information about the batch account, storage account, container registry etc. that are created as part of the deployment.

```sh
> sb show --help

Command
    sb show : Show the configuration of the sbatch deployment.
        Shows the configuration details of the sbatch deployment. This is useful
        to get access to various resources and endpoints for resources that
        are used for management and trying of the demos.

Arguments
    --only-validate                     : Only validate the resource group and subscription ID.

Deployment Arguments
    --resource-group-name -g [Required] : The name of the resource group.
    --subscription-id -s     [Required] : The subscription ID.

Global Arguments
    --debug                             : Increase logging verbosity to show all debug logs.
    --help -h                           : Show this help message and exit.
    --only-show-errors                  : Only show errors, suppressing warnings.
    --output -o                         : Output format.  Allowed values: json, jsonc, none, table,
                                          tsv, yaml, yamlc.  Default: json.
    --query                             : JMESPath query string. See http://jmespath.org/ for more
                                          information and examples.
    --verbose                           : Increase logging verbosity. Use --debug for full debug
                                          logs.
```

### `sb pool`

`sb pool` subcommands can be used to manage the pools in the deployment.

```sh
> sb pool --help

Group
    sb pool : Manage batch pools.
        Commands to manage batch pools.

Commands:
    list   : List the pools in the batch account.
    resize : Resize the pool.
```

`sb pool list`  returns a list of names for the pool setup on the batch account. Unless changed manually after deployment,
these will match the names specified in `batch.jsonc` configuration file.

```sh
> sb pool list --help

Command
    sb pool list : List the pools in the batch account.
        Lists the pools in the batch account.

Arguments

Deployment Arguments
    --resource-group-name -g [Required] : The name of the resource group.
    --subscription-id -s     [Required] : The subscription ID.

Global Arguments
    --debug                             : Increase logging verbosity to show all debug logs.
    --help -h                           : Show this help message and exit.
    --only-show-errors                  : Only show errors, suppressing warnings.
    --output -o                         : Output format.  Allowed values: json, jsonc, none, table,
                                          tsv, yaml, yamlc.  Default: json.
    --query                             : JMESPath query string. See http://jmespath.org/ for more
                                          information and examples.
    --verbose                           : Increase logging verbosity. Use --debug for full debug
                                          logs.
```

`sb pool resize` can be used to resize a pool. Unlike `az batch pool resize ..` commands, this command waits until
the resize is complete (unless `--no-wait` is specified). `--await-compute-nodes` can be used to wait until
not only the allocation of the compute nodes, but also their startup and other initialization.

```sh
> sb pool resize --help

Command
    sb pool resize : Resize the pool.

Arguments
    --pool-id -p             [Required] : The ID of the pool to resize.
    --await-compute-nodes               : Wait for the compute nodes to be ready; ignored if `--no-
                                          wait` is specified.
    --no-wait                           : Do not wait for the operation to complete.
    --target-dedicated-nodes -d         : The target dedicated node count for the pool.
    --target-spot-nodes -l              : The target spot node count for the pool.

Deployment Arguments
    --resource-group-name -g [Required] : The name of the resource group.
    --subscription-id -s     [Required] : The subscription ID.

Global Arguments
    --debug                             : Increase logging verbosity to show all debug logs.
    --help -h                           : Show this help message and exit.
    --only-show-errors                  : Only show errors, suppressing warnings.
    --output -o                         : Output format.  Allowed values: json, jsonc, none, table,
                                          tsv, yaml, yamlc.  Default: json.
    --query                             : JMESPath query string. See http://jmespath.org/ for more
                                          information and examples.
    --verbose                           : Increase logging verbosity. Use --debug for full debug
                                          logs.
```
