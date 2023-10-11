# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# test script to import container image to ACR

# get ACR name from deployment
execute_process(
    COMMAND bacc show -s ${SB_SUBSCRIPTION_ID} -g ${SB_RESOURCE_GROUP_NAME} --query "acr_name" -o tsv
    OUTPUT_VARIABLE SB_ACR_NAME
    COMMAND_ERROR_IS_FATAL ANY
    COMMAND_ECHO STDOUT
)

# remove newlines
string(STRIP "${SB_ACR_NAME}" SB_ACR_NAME)

# import container image to ACR
execute_process(
    COMMAND az acr import -n ${SB_ACR_NAME}
                --source ${SB_SOURCE_CONTAINER_REGISTRY_NAME}/${SB_SOURCE_CONTAINER_IMAGE_NAME}
                --image ${SB_TARGET_CONTAINER_IMAGE_NAME}
                --force
    COMMAND_ERROR_IS_FATAL ANY
    COMMAND_ECHO STDOUT
)
