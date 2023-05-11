from knack.commands import CommandGroup
from knack.arguments import ArgumentsContext
from knack.help_files import helps
from knack.log import get_logger

import math
import os.path

from . import utils

log = get_logger(__name__)

helps[
    "azfinsim"
] = r"""
    type: command
    short-summary: Execute the azfinsim demo
    long-summary: |
        This command executes the azfinsim demo. This will submit a job to Azure Batch
        to process a set of trades. The trades will be generated randomly if no trades file
        is specified. The results will be stored in a CSV file on the Azure Storage account
        mounted on the pool. The path to the CSV file is returned as the output from this
        command.
"""


def populate_commands(loader):
    with CommandGroup(loader, "", "az_sbatch.azfinsim#{}") as g:
        g.command("azfinsim", "execute")


def populate_arguments(loader):
    with ArgumentsContext(loader, "azfinsim") as c:
        c.argument(
            'mode',
            options_list=['--mode', '-m'],
            help='The mode to use for the job.',
            choices=['container', 'package']
        )
        c.argument(
            "pool_id",
            options_list=["--pool-id", "-p"],
            help="The ID of the pool to use for the job.",
            choices=['linux', 'windows']
        )
        c.argument(
            "num_tasks",
            options_list=["--num-tasks", "-k"],
            help="The number of concurrent tasks to use for the job.",
            type=int,
        )
        c.argument(
            "await_completion",
            options_list=["--await-completion", "-c"],
            help="Wait for the job to complete before returning.",
            action="store_true",
        )
        c.argument(
            "trades_file",
            options_list=["--trades-file", "-t"],
            help="The path to the trades file to use instead of generating random trades.",
            arg_group="AzFinSim",
        )
        c.argument(
            "num_trades",
            options_list=["--num-trades", "-n"],
            help="The number of trades to generate if no trades file is specified.",
            type=int,
            arg_group="AzFinSim",
        )
        c.argument(
            "algorithm",
            options_list=["--algorithm", "-a"],
            help="The algorithm to use for the job.",
            choices=["deltavega", "pvonly"],
            arg_group="AzFinSim",
        )
        c.argument(
            "data_dir",
            options_list=["--data-dir", "-d"],
            help="The path to the shared data directory to use for the job. If not specified, "
                 "for Linux compute nodes, the default is `$AZ_BATCH_NODE_MOUNTS_DIR/data`; for Windows "
                 "compute nodes, the default is `l:`.",
            arg_group="AzFinSim",
        )
        # container image options
        c.argument(
            "image_name",
            options_list=["--image-name", "-i"],
            help="The name of the container image to use for the job.",
            arg_group="Container",
        )
        c.argument(
            "container_registry",
            options_list=["--container-registry", "-r"],
            help="The name of the container registry to use for the job. If not specified, "
                 "ACR deployed as part of the sbatch deployment is used",
            arg_group="Container",
        )
        c.argument(
            "python_executable",
            options_list=["--python-executable", "-e"],
            help="The path to the python executable to use for the job.",
            arg_group="Package"
        )


def execute(
    resource_group_name: str,
    subscription_id: str,
    trades_file: str = None,
    num_trades: int = None,
    num_tasks: int = 1,
    algorithm: str = "deltavega",
    container_registry: str = None,
    image_name: str = "azfinsim/azfinsim:latest",
    pool_id: str = "linux",
    mode: str = "container",
    python_executable: str = "c:/Python310/python.exe",
    data_dir: str = None,
    await_completion: bool = False
):
    if num_trades is None and trades_file is None:
        log.critical("Either --num-trades or --trades-file must be specified.")
        return
    subscription_id = utils.get_subscription_id(subscription_id)
    credentials = utils.get_credentials()
    if not utils.validate_resource_group(credentials, subscription_id, resource_group_name):
        log.critical(
            "Resource group '%s' is not a valid sbatch spoke resource group", resource_group_name)
        return

    cr = None
    if mode == 'container':
        if container_registry is None:
            acr_name = utils.locate_acr(credentials, subscription_id, resource_group_name)
            if not acr_name:
                log.critical("ACR not found. Did you create the deployment?")
                return
            cr = f"{acr_name}.azurecr.io"
        else:
            cr = container_registry

    task_cmd_prefix = '' if mode == 'container' else f"{python_executable} "
    if data_dir is None:
        if "linux" in pool_id:
            shared_data_dir = '/mnt/batch/tasks/fsmounts/data'
        else:
            shared_data_dir = 'l:'
    else:
        shared_data_dir = data_dir

    uid = utils.get_unique_id()
    job_id = f"azfinsim-{uid}"
    job_dir = f"{shared_data_dir}/{job_id}"
    tasks = []
    dependencies = None

    if trades_file:
        log.info("Using existing trades file %s", trades_file)
        dependencies = None
        # TODO: maybe we want to support absolute paths?
        in_file = f"{shared_data_dir}/{trades_file}"
    else:
        log.info("Gen task", num_trades)
        in_file = f"{job_dir}/trades.csv"
        task_cmd = (
            f"{task_cmd_prefix} -m azfinsim.generator --no-color --trade-window {num_trades} "
            + f"--cache-path {in_file}"
        )
        gen_tasks = utils.create_tasks(
            task_command_lines=[task_cmd],
            task_container_image=f"{cr}/{image_name}" if cr else None,
            task_id_prefix="generate",
            elevatedUser=True,
        )
        tasks += gen_tasks

    # update dependencies for next task(s)
    dependencies = [tasks[-1].id] if len(tasks) > 0 else None

    # create task for splitting trade file into smaller chunks
    log.info("Splitting trades file into %s chunks", num_tasks)
    trades_per_file = math.ceil(num_trades / num_tasks)
    task_cmd = (
        f"{task_cmd_prefix} -m azfinsim.split --no-color --cache-path {in_file} "
        + f"--output-path {job_dir} "
        + f"--trade-window {trades_per_file}"
    )
    tasks += utils.create_tasks(
        task_command_lines=[task_cmd],
        task_container_image=f"{cr}/{image_name}" if cr else None,
        task_id_prefix="split",
        get_dependencies=lambda _: dependencies if dependencies else None,
        elevatedUser=True,
    )

    # update dependencies for next task(s)
    dependencies = [tasks[-1].id]

    # create tasks for processing each chunk
    name, ext = os.path.splitext(os.path.basename(in_file))

    def exec_generator():
        for i in range(num_tasks):
            yield f"{task_cmd_prefix} -m azfinsim.azfinsim --no-color " \
                   f"--cache-path {job_dir}/{name}.{i}{ext} --algorithm {algorithm}"

    pricing_tasks = utils.create_tasks(
        task_command_lines=exec_generator(),
        task_container_image=f"{cr}/{image_name}" if cr else None,
        task_id_prefix="process",
        get_dependencies=lambda _: dependencies if dependencies else None,
        elevatedUser=True,
    )
    tasks += pricing_tasks

    # update dependencies for next task(s)
    dependencies = [t.id for t in pricing_tasks]

    # create merge task
    task_cmd = (
        f"{task_cmd_prefix} -m azfinsim.concat --no-color "
        + f"--cache-path {job_dir}/{name}.[0-9]*.results{ext} "
        + f"--output-path {job_dir}/{name}.results{ext} "
    )
    merge_tasks = utils.create_tasks(
        task_command_lines=[task_cmd],
        task_container_image=f"{cr}/{image_name}" if cr else None,
        task_id_prefix="concat",
        get_dependencies=lambda _: dependencies if dependencies else None,
        elevatedUser=True,
    )
    tasks += merge_tasks

    utils.submit_job(
        credentials=credentials,
        subscription_id=subscription_id,
        resource_group_name=resource_group_name,
        job_id=job_id,
        pool_id=pool_id,
        tasks=tasks,
    )


    result = {
        "job_id": job_id,
        "trades_file": trades_file if trades_file else f"{job_id}/{name}{ext}",
        "results_file": f"{job_id}/{name}.results{ext}"
    }

    if await_completion:
        log.info("Waiting for job to complete...")
        utils.wait_until(lambda: utils.is_job_complete(credentials, subscription_id, resource_group_name, job_id) is True)
        result['job_status'] = utils.get_job_status(credentials, subscription_id, resource_group_name, job_id)

    return result
