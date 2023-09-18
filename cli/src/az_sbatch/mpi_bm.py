from knack.commands import CommandGroup
from knack.arguments import ArgumentsContext
from knack.help_files import helps
from knack.log import get_logger

from . import utils
import math

log = get_logger(__name__)

helps["mpi-bm"] = r"""
    type: group
    short-summary: Execute tools in the mpi-benchmark demo
    long-summary: |
        This command executes the tools in mpi-benchmark demo. This will submit a job to Azure Batch
        to run the mpi benchmarks.
"""

def populate_commands(loader):
    with CommandGroup(loader, "", "az_sbatch.mpi_bm#{}") as g:
        g.command("mpi-bm", "imb")

def populate_commands(loader):
    with CommandGroup(loader, "mpi-bm", "az_sbatch.mpi_bm#{}") as g:
        g.command("imb", "imb")

def populate_arguments(loader):
    with ArgumentsContext(loader, "mpi-bm") as c:
        c.argument(
            "num_nodes",
            options_list=["--num-nodes", "-n"],
            type=int,
            help="The number of nodes to use for the job.",
            arg_group="MPI Arguments",
        )
        c.argument(
            "num_ranks",
            options_list=["--num-ranks", "-r"],
            type=int,
            help="The number of MPI ranks to use for the job.",
            arg_group="MPI Arguments",
        )
        c.argument(
            "imb_exe",
            options_list=["--exe", "-e"],
            type=str,
            help="The name of the Intel MPI Benchmark executable.",
        )
        c.argument(
            "imb_args",
            options_list=["--args", "-a"],
            type=str,
            help="The arguments to pass to the Intel MPI Benchmark executable.",
        )
        c.argument(
            "pool_id",
            options_list=["--pool-id", "-p"],
            help="The ID of the pool to use for the job.",
            choices=['linux-HBv3']
        )
        c.argument(
            "await_completion",
            options_list=["--await-completion", "-c"],
            help="Wait for the job to complete before returning.",
            action="store_true",
        )
        c.argument(
            "mpi_impl",
            options_list=["--mpi-implementation", "-m"],
            help="The MPI implementation to use for the job.",
            choices=['hpcx'],
            arg_group="MPI Arguments",
        )


helps["mpi-bm imb"] = r"""
    type: command
    short-summary: Execute the Intel MPI Benchmark
    long-summary: |
        This command executes the Intel MPI Benchmark. This will submit a job to Azure Batch
        to run the mpi benchmarks.
"""

def imb(resource_group_name:str, subscription_id:str,
        imb_exe:str, imb_args:str,
        pool_id:str="linux-HBv3",
        await_completion:bool=False,
        mpi_impl:str="hpcx",
        num_nodes:int=2, num_ranks:int=2):
    log.info("num_nodes: {}".format(num_nodes))
    log.info("num_ranks: {}".format(num_ranks))
    log.info("imb_exe: {}".format(imb_exe))
    log.info("imb_args: {}".format(imb_args))
    log.info("pool_id: {}".format(pool_id))
    log.info("await_completion: {}".format(await_completion))
    log.info("mpi_impl: {}".format(mpi_impl))

    subscription_id = utils.get_subscription_id(subscription_id)
    credentials = utils.get_credentials()
    if not utils.validate_resource_group(credentials, subscription_id, resource_group_name):
        log.critical(
            "Resource group '%s' is not a valid sbatch spoke resource group", resource_group_name)
        return

    uid = utils.get_unique_id()
    job_id = "{}-{}-{}".format(imb_exe.lower(), imb_args.lower(), uid)

    num_ranks_per_node = math.ceil(num_ranks / num_nodes)
    if mpi_impl == "hpcx":
        mpi_cmd=f"mpirun -host $AZ_BATCH_OMPI_HOSTS -x UCX_TLS=rc --map-by ppr:{num_ranks_per_node}:node -np {num_ranks}"
    
    imb_command = f"/mnt/intel_benchmarks/{mpi_impl}/{imb_exe} {imb_args}"
    task_cmd = f"bash -c 'source /etc/profile.d/modules.sh  && source /mnt/batch_utils.sh && module load mpi/{mpi_impl} && {mpi_cmd} {imb_command}'"

    utils.submit_job(credentials, subscription_id, resource_group_name, job_id, pool_id,
                     utils.create_tasks([task_cmd],
                                        task_id_prefix=imb_args.lower(),
                                        num_mpi_nodes=num_nodes))

    result = {
        "job_id": job_id,
    }
    if await_completion:
        log.info("Waiting for job to complete...")
        utils.wait_until(lambda: utils.is_job_complete(credentials, subscription_id, resource_group_name, job_id) is True)
        result['job_status'] = utils.get_job_status(credentials, subscription_id, resource_group_name, job_id)

    return result
