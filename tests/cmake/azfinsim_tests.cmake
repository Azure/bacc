## This modules adds various test for azfinsim application demo.

#=======================================================================================================================
function(add_azfinsim_tests pool_name)
    set(prefix "azfinsim-${pool_name}:")

    # resize pool
    sb_add_test(
        NAME "${prefix}resize"
        COMMAND sb pool resize
                    -g ${SB_RESOURCE_GROUP_NAME}
                    -s ${SB_SUBSCRIPTION_ID}
                    -p ${pool_name}
                    --target-dedicated-nodes 1
                    --await-compute-nodes
                    --query "current_dedicated_nodes"
                    -o tsv
        PASS_REGULAR_EXPRESSION "^1"
        REQUIRES "SB_SUPPORTS_AZFINSIM AND SB_SUPPORTS_NETWORK_ACCESS"
    )

    # downsize pool
    set(downsize_target_nodes 0)
    if (SB_TESTING_SKIP_POOL_DOWNSIZE)
        set(downsize_target_nodes 1)
    endif()

    sb_add_test(
        NAME "${prefix}downsize"
        COMMAND sb pool resize
                    -g ${SB_RESOURCE_GROUP_NAME}
                    -s ${SB_SUBSCRIPTION_ID}
                    -p ${pool_name}
                    --target-dedicated-nodes ${downsize_target_nodes}
                    --target-spot-nodes 0
                    --await-compute-nodes
                    -o tsv
        PASS_REGULAR_EXPRESSION "^${downsize_target_nodes}.*0"
        REQUIRES "SB_SUPPORTS_AZFINSIM AND SB_SUPPORTS_NETWORK_ACCESS"
    )

    sb_add_test(
        NAME "${prefix}docker-pvonly"
        COMMAND sb azfinsim
                    -g ${SB_RESOURCE_GROUP_NAME}
                    -s ${SB_SUBSCRIPTION_ID}
                    -p ${pool_name}
                    --num-trades 100
                    --num-tasks 9
                    --algorithm "pvonly"
                    --container-registry "docker.io"
                    --image-name "utkarshayachit/azfinsim:main"
                    --await-completion
                --query "job_status"
                -o tsv
        PASS_REGULAR_EXPRESSION "^AllTasksCompleted"
        REQUIRES "SB_SUPPORTS_AZFINSIM AND SB_SUPPORTS_NETWORK_ACCESS AND SB_SUPPORTS_DOCKERHUB AND \"${pool_name}\" MATCHES \".*linux.*\""
    )

    sb_add_test(
        NAME "${prefix}docker-deltavega"
        COMMAND sb azfinsim
                    -g ${SB_RESOURCE_GROUP_NAME}
                    -s ${SB_SUBSCRIPTION_ID}
                    -p ${pool_name}
                    --num-trades 10
                    --num-tasks 7
                    --algorithm "deltavega"
                    --container-registry "docker.io"
                    --image-name "utkarshayachit/azfinsim:main"
                    --await-completion
                --query "job_status"
                -o tsv
        PASS_REGULAR_EXPRESSION "^AllTasksCompleted"
        REQUIRES "SB_SUPPORTS_AZFINSIM AND SB_SUPPORTS_NETWORK_ACCESS AND SB_SUPPORTS_DOCKERHUB AND \"${pool_name}\" MATCHES \".*linux.*\""
    )

    #-------------------------------------------------------------------------------------------------------------------
    # add ACR tests
    sb_add_test(
        NAME "${prefix}acr-pvonly"
        COMMAND sb azfinsim
                    -g ${SB_RESOURCE_GROUP_NAME}
                    -s ${SB_SUBSCRIPTION_ID}
                    -p ${pool_name}
                    --num-trades 100
                    --num-tasks 9
                    --algorithm "pvonly"
                    --await-completion
                --query "job_status"
                -o tsv
        PASS_REGULAR_EXPRESSION "^AllTasksCompleted"
        REQUIRES "SB_SUPPORTS_AZFINSIM AND SB_SUPPORTS_NETWORK_ACCESS AND SB_SUPPORTS_ACR AND \"${pool_name}\" MATCHES \".*linux.*\""
    )

    sb_add_test(
        NAME "${prefix}acr-deltavega"
        COMMAND sb azfinsim
                    -g ${SB_RESOURCE_GROUP_NAME}
                    -s ${SB_SUBSCRIPTION_ID}
                    -p ${pool_name}
                    --num-trades 10
                    --num-tasks 7
                    --algorithm "deltavega"
                    --await-completion
                --query "job_status"
                -o tsv
        PASS_REGULAR_EXPRESSION "^AllTasksCompleted"
        REQUIRES "SB_SUPPORTS_AZFINSIM AND SB_SUPPORTS_NETWORK_ACCESS AND SB_SUPPORTS_ACR AND \"${pool_name}\" MATCHES \".*linux.*\""
    )

    #-------------------------------------------------------------------------------------------------------------------
    # add tests for package tasks
    sb_add_test(
        NAME "${prefix}pkg-pvonly"
        COMMAND sb azfinsim
                    -g ${SB_RESOURCE_GROUP_NAME}
                    -s ${SB_SUBSCRIPTION_ID}
                    -p ${pool_name}
                    --num-trades 100
                    --num-tasks 9
                    --algorithm "pvonly"
                    --mode "package"
                    --await-completion
                --query "job_status"
                -o tsv
        PASS_REGULAR_EXPRESSION "^AllTasksCompleted"
        REQUIRES "SB_SUPPORTS_AZFINSIM AND SB_SUPPORTS_NETWORK_ACCESS AND SB_SUPPORTS_AZFINSIM_PREINSTALLED_PACKAGES"
    )

    sb_add_test(
        NAME "${prefix}pkg-deltavega"
        COMMAND sb azfinsim
                    -g ${SB_RESOURCE_GROUP_NAME}
                    -s ${SB_SUBSCRIPTION_ID}
                    -p ${pool_name}
                    --num-trades 10
                    --num-tasks 7
                    --algorithm "deltavega"
                    --mode "package"
                    --await-completion
                --query "job_status"
                -o tsv
        PASS_REGULAR_EXPRESSION "^AllTasksCompleted"
        REQUIRES "SB_SUPPORTS_AZFINSIM AND SB_SUPPORTS_NETWORK_ACCESS AND SB_SUPPORTS_AZFINSIM_PREINSTALLED_PACKAGES"
    )

    sb_test_workflow("azfinsim-${pool_name}"
        SETUP   "${prefix}resize"
        CLEANUP "${prefix}downsize"
        TESTS
            "${prefix}docker-pvonly"
            "${prefix}docker-deltavega"
            "${prefix}pkg-pvonly"
            "${prefix}pkg-deltavega"
    )

    sb_test_workflow("azfinsim-acr-${pool_name}"
        SETUP
            "${prefix}resize"
            "azfinsim-acr-import"
        CLEANUP "${prefix}downsize"
        TESTS
            "${prefix}acr-pvonly"
            "${prefix}acr-deltavega"
    )

endfunction()
#=======================================================================================================================

# add ACR import tests
sb_add_test(
    NAME "azfinsim-acr-import"
    COMMAND ${CMAKE_COMMAND}
            -D SB_RESOURCE_GROUP_NAME:STRING=${SB_RESOURCE_GROUP_NAME}
            -D SB_SUBSCRIPTION_ID:STRING=${SB_SUBSCRIPTION_ID}
            -D SB_SOURCE_CONTAINER_REGISTRY_NAME:STRING=docker.io
            -D SB_SOURCE_CONTAINER_IMAGE_NAME:STRING=utkarshayachit/azfinsim:main
            -D SB_TARGET_CONTAINER_IMAGE_NAME:STRING=azfinsim/azfinsim:latest
            -P "${CMAKE_CURRENT_LIST_DIR}/acr_import.cmake"
    REQUIRES "SB_SUPPORTS_AZFINSIM AND SB_SUPPORTS_NETWORK_ACCESS AND SB_SUPPORTS_ACR"
)

# add tests for all pools
sb_get_pools(pool_names "${SB_CONFIG}")
foreach(pool_name IN LISTS pool_names)
    add_azfinsim_tests(${pool_name})
endforeach()
