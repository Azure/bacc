# Example Configurations

In this directory, we have a few example configurations that you can use to get
started with customizing deployments.To use any of these configurations, you
replace overwrite the contents of the config directory with the contents of the
example configuration you want to use.

```sh
# to use azfinsim-linux configuration
> cp -r examples/azfinsim-linux/* config/
```

## azfinsim-linux: Batch account with BatchService pool allocation mode (Linux-only pool)

[azfinsim-linux] demonstrates Batch account with **BatchService**
pool allocation mode. It is setup to have single pool with Linux VMs. The pool is
setup to mount a single storage account as "data" using blobfuse (and not NFSv3). The configuration
files are also intentionally minimal to demonstrate the minimal configuration necessary. If deployed with
default parameters for deployment, the resources created will also be minimal, avoiding things like Azure Container Registry,
Key Vault, etc.

## azfinsim-win: Batch account with BatchService pool allocation mode (Windows-only pool)

[azfinsim-windows] is similar with intentions as [azfinsim-linux], but it is setup to
to use Windows VMs instead of Linux VMs. For storage, it uses Azure Files instead
of Azure Blobs and mounts it using SMB. This configuration also demonstrates
how to setup a start task for a pool.
The config is also setup to run the AzFinSim demo on Windows pool in 'package' mode. Instead of using a container image,
the application is installed on the pool in the start task. The application is then run in the task command line.

[azfinsim-linux]: https://github.com/utkarshayachit/azbatch-starter/tree/main/examples/azfinsim-linux
[azfinsim-windows]: https://github.com/utkarshayachit/azbatch-starter/tree/main/examples/azfinsim-windows
