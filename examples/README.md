# Example Configurations

In this directory, we have a few example configurations that you can use to get
started with customizing deployments.To use any of these configurations, you
replace overwrite the contents of the config directory with the contents of the
example configuration you want to use.

```sh
# to use config0
> cp -r examples/config0/* config/
```

## config0: Batch account with BatchService pool allocation mode

[config0](./config0/) demonstrates Batch account with **BatchService**
pool allocation mode. It is setup to have single pool with Linux VMs. The pool is
setup to mount a single storage account as "data" using blobfuse (and not NFSv3). The configuration
files are also intentionally minimal to demonstrate the minimal configuration necessary. If deployed with
default parameters for deployment, the resources created will also be minimal, avoiding things like Azure Container Registry,
Key Vault, etc.

[config1](./config1/) is similar with intentions as config0, but it is setup to
to use Windows VMs instead of Linux VMs. For storage, it uses Azure Files instead
of Azure Blobs and mounts it using SMB. This configuration also demonstrates
how to setup a start start for a pool. The start task is used to install the
applications and dependencies that are needed for the AzFinSim application demo
to run in this configuration.
