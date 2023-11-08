# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

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
    with CommandGroup(loader, "", "bacc.mpi_bm#{}") as g:
        g.command("mpi-bm", "imb")

def populate_commands(loader):
    with CommandGroup(loader, "mpi-bm", "bacc.mpi_bm#{}") as g:
        g.command("imb", "imb")
        g.command("osu", "osu")
        g.command("custom", "wrk")

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
            "bm_exe",
            options_list=["--exe", "-e"],
            type=str,
            help="The name of the benchmark executable.",
        )
        c.argument(
            "bm_args",
            options_list=["--args", "-a"],
            type=str,
            help="The arguments to pass to the benchmark executable.",
        )
        c.argument(
            "pool_id",
            options_list=["--pool-id", "-p"],
            help="The ID of the pool to use for the job.",
            # choices=['almalinux', 'rhel8']
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
            help="The MPI implementation to use for the job. Ensure that the MPI implementation is available on the compute node.",
            choices=['hpcx', 'openmpi', 'impi-2021', 'mvapich2'],
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
        bm_exe:str, bm_args:str,
        pool_id:str,
        await_completion:bool=False,
        mpi_impl:str="hpcx",
        num_nodes:int=2, num_ranks:int=2):
    return execute(resource_group_name, subscription_id,
        pool_id,
        bm_exe, bm_args,
        "/mnt/intel_benchmarks",
        await_completion,
        mpi_impl,
        num_nodes, num_ranks)


helps["mpi-bm osu"] = r"""
    type: command
    short-summary: Execute the OSU Micro Benchmark
    long-summary: |
        This command executes the OSU Micro Benchmark. This will submit a job to Azure Batch
        to run the mpi benchmarks.
"""
def osu(resource_group_name:str, subscription_id:str,
        pool_id:str,
        bm_exe:str, bm_args:str="",
        await_completion:bool=False,
        mpi_impl:str="hpcx",
        num_nodes:int=2, num_ranks:int=2):
    return execute(resource_group_name, subscription_id,
        pool_id,
        bm_exe, bm_args,
        "/mnt/osu-micro-benchmarks",
        await_completion,
        mpi_impl,
        num_nodes, num_ranks)


helps["mpi-bm osu"] = r"""
    type: command
    short-summary: Execute the custom MPI workload
    long-summary: |
        This command executes the custom MPI workload. This will submit a job to Azure Batch
        to run the mpi executable.
"""
def wrk(resource_group_name:str, subscription_id:str,
        pool_id:str,
        bm_exe:str="mpi_workload", bm_args:str="",
        await_completion:bool=False,
        mpi_impl:str="hpcx",
        num_nodes:int=2, num_ranks:int=2):
    return execute(resource_group_name, subscription_id,
        pool_id,
        bm_exe, bm_args,
        "/mnt/mpi_workload",
        await_completion,
        mpi_impl,
        num_nodes, num_ranks)


def execute(resource_group_name:str, subscription_id:str,
        pool_id:str,
        bm_exe:str, bm_args:str,
        prefix:str,
        await_completion:bool,
        mpi_impl:str,
        num_nodes:int, num_ranks:int):
    log.info("num_nodes: {}".format(num_nodes))
    log.info("num_ranks: {}".format(num_ranks))
    log.info("pool_id: {}".format(pool_id))
    log.info("await_completion: {}".format(await_completion))
    log.info("mpi_impl: {}".format(mpi_impl))
    log.info("bm_exe: {}".format(bm_exe))
    log.info("bm_args: {}".format(bm_args))
    log.info("prefix: {}".format(prefix))

    subscription_id = utils.get_subscription_id(subscription_id)
    credentials = utils.get_credentials()
    if not utils.validate_resource_group(credentials, subscription_id, resource_group_name):
        log.critical(
            "Resource group '%s' is not a valid bacc spoke resource group", resource_group_name)
        return

    uid = utils.get_unique_id()
    job_id = "{}-{}".format('custom', uid)

    num_ranks_per_node = math.ceil(num_ranks / num_nodes)
    if mpi_impl == "hpcx" or mpi_impl == "openmpi":
        mpi_cmd=f"mpirun -host $(get_openmpi_hosts_with_slots) -mca coll_hcoll_enable 0 -x UCX_TLS=tcp -x LD_LIBRARY_PATH -x UCX_NET_DEVICES=eth0 --map-by ppr:{num_ranks_per_node}:node -np {num_ranks}"
    elif mpi_impl == "impi-2021":
        mpi_cmd=f"mpirun -hosts $(echo $AZ_BATCH_NODE_LIST | sed \"s/;/,/g\") -genv I_MPI_DEBUG 5 -genv I_MPI_FABRICS ofi -ppn {num_ranks_per_node} -np {num_ranks}"
    elif mpi_impl == "mvapich2":
        mpi_cmd=f"mpirun -host $(get_openmpi_hosts_with_slots) -x LD_LIBRARY_PATH --map-by ppr:{num_ranks_per_node}:node -np {num_ranks}"

    wrk_command = f"$(find {prefix}/{mpi_impl}/ -name {bm_exe} -type f | head -n 1) {bm_args}"
    task_cmd = f"bash -c 'source /etc/profile.d/modules.sh  && source /mnt/batch_utils.sh && module load mpi/{mpi_impl} && {mpi_cmd} {wrk_command}'"

    utils.submit_job(credentials, subscription_id, resource_group_name, job_id, pool_id,
                     utils.create_tasks([task_cmd],
                                        task_id_prefix='custom',
                                        num_mpi_nodes=num_nodes))
    result = { "job_id": job_id, }
    if await_completion:
        log.info("Waiting for job to complete...")
        utils.wait_until(lambda: utils.is_job_complete(credentials, subscription_id, resource_group_name, job_id) is True)
        result['job_status'] = utils.get_job_status(credentials, subscription_id, resource_group_name, job_id)
    return result
