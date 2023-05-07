import os

from azure.identity import DefaultAzureCredential
from azure.mgmt.resource import ResourceManagementClient
from azure.batch import BatchServiceClient, models
from knack.log import get_logger
from .azure_identity_credential_adapter import AzureIdentityCredentialAdapter
import time

log = get_logger(__name__)


def get_unique_id() -> str:
    return str(time.time()).replace(".", "")


def get_credentials():
    """Get credentials from the CLI environment.

    :return: Credentials object
    :rtype: :class:`msrestazure.azure_active_directory.AdalAuthentication`
    """
    return DefaultAzureCredential()


def get_subscription_id(id):
    """Get the subscription ID from the CLI environment.

    :return: Subscription ID
    :rtype: str
    """
    return id if id is not None else os.environ["AZURE_SUBSCRIPTION_ID"]


def get_batch_client(credentials, subscription_id, resource_group_name):
    """Get the Batch client for a specified subscription and resource group.

    :param credentials: Credentials object
    :type credentials: :class:`msrestazure.azure_active_directory.AdalAuthentication`
    :param str subscription_id: Subscription ID
    :param str resource_group_name: Resource group name
    :return: Batch client
    :rtype: :class:`azure.mgmt.batch.BatchManagementClient`
    """
    ep = locate_batch_endpoint(credentials, subscription_id, resource_group_name)
    if not ep:
        log.critical("Batch account not found. Did you create the deployment?")
        return None
    client = BatchServiceClient(
        AzureIdentityCredentialAdapter(
            credentials, resource_id="https://batch.core.windows.net/"
        ),
        ep,
    )
    return client


def validate_resource_group(credentials, subscription_id, resource_group_name):
    """validate that a resource group specified is sbatch spoke resource group"""
    rclient = ResourceManagementClient(credentials, subscription_id)
    if rclient.resource_groups.check_existence(resource_group_name):
        rg = rclient.resource_groups.get(resource_group_name)
        if rg.tags is not None and rg.tags.get("codebase") == "azbatch-starter":
            log.debug("rg  '%s' has expected tags; rg is valid", resource_group_name)
            return True
        log.debug(
            "rg '%s' is missing expected tags; rg is not valid", resource_group_name
        )
    else:
        log.debug("rg '%s' does not exist; rg is not valid", resource_group_name)
        return False


def locate_acr(credentials, subscription_id, resource_group_name):
    filter = "tagName eq 'sbatch' and tagValue eq 'acr'"
    log.debug("filter expr: %s", filter)

    rclient = ResourceManagementClient(credentials, subscription_id)
    items = rclient.resources.list_by_resource_group(resource_group_name, filter=filter)
    for resource in items:
        if resource.type == "Microsoft.ContainerRegistry/registries":
            log.debug("resource: %s", resource)
            return resource.name
    log.debug("No ACR found. Did you enable container support in your deployment?")
    return None


def locate_batch_endpoint(credentials, subscription_id, resource_group_name):
    filter = "tagName eq 'sbatch' and tagValue eq 'batch-account'"
    log.debug("filter expr: %s", filter)

    rclient = ResourceManagementClient(credentials, subscription_id)
    items = rclient.resources.list_by_resource_group(resource_group_name, filter=filter)
    for resource in items:
        if resource.type == "Microsoft.Batch/batchAccounts":
            log.debug("resource: %s", resource)
            return f"https://{resource.name}.{resource.location}.batch.azure.com"
    log.debug(
        "No Batch Account found. Did you enable container support in your deployment?"
    )
    return None


def wait_until(x, timeout_in_mins=15):
    count_down = (timeout_in_mins * 60) // 15
    while count_down > 0:
        s = x()
        if s is True:
            return True
        if s is None:
            return False
        time.sleep(15)
        count_down -= 1
    return False


def create_tasks(
    task_command_lines,
    task_id_prefix="task",
    task_container_image=None,
    container_run_options=None,
    elevatedUser=False,
    get_dependencies=None,
):
    """create a list of tasks"""
    user = (
        models.UserIdentity(
            auto_user=models.AutoUserSpecification(
                scope="pool", elevation_level="admin"
            )
        )
        if elevatedUser
        else None
    )
    task_container_settings = (
        models.TaskContainerSettings(
            image_name=task_container_image, container_run_options=container_run_options
        )
        if task_container_image
        else None
    )

    return [
        models.TaskAddParameter(
            id="{}_{}".format(task_id_prefix, index),
            command_line=cmd,
            user_identity=user,
            container_settings=task_container_settings,
            depends_on=models.TaskDependencies(task_ids=get_dependencies(index))
            if get_dependencies
            else None,
        )
        for index, cmd in enumerate(task_command_lines)
    ]


def submit_job(
    credentials, subscription_id, resource_group_name, job_id, pool_id, tasks: list
):
    """submit a new workflow"""
    client = get_batch_client(credentials, subscription_id, resource_group_name)

    pool_info = models.PoolInformation(pool_id=pool_id)
    client.job.add(
        models.JobAddParameter(
            id=job_id, pool_info=pool_info, uses_task_dependencies=True
        )
    )
    client.task.add_collection(job_id, tasks)

    # once tasks are added to job, update the job to terminate the job
    # once all tasks complete
    client.job.update(
        job_id=job_id,
        job_update_parameter=models.JobUpdateParameter(
            on_all_tasks_complete="terminateJob", pool_info=pool_info
        ),
    )
