## This modules adds various test for azfinsim application demo.

if (SB_CONFIG STREQUAL "DEFAULT" OR
    SB_CONFIG MATCHES "^azfinsim-.*")
else()
    message(STATUS "Skipping azfinsim tests for ${SB_CONFIG}")
    return()
endif()

include(utils)

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
        PASS_REGULAR_EXPRESSION "^1")

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
        PASS_REGULAR_EXPRESSION "^${downsize_target_nodes}.*0")

    # generate n process
    set(tests)
    if (pool_name STREQUAL "linux")
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
            PASS_REGULAR_EXPRESSION "^AllTasksCompleted")

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
            PASS_REGULAR_EXPRESSION "^AllTasksCompleted")

        list(APPEND tests
            "${prefix}docker-pvonly"
            "${prefix}docker-deltavega")
    endif()

    if (SB_CONFIG STREQUAL "azfinsim-windows" AND pool_name STREQUAL "windows")
        # add tests for non-container tasks
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
            PASS_REGULAR_EXPRESSION "^AllTasksCompleted")

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
            PASS_REGULAR_EXPRESSION "^AllTasksCompleted")

        list(APPEND tests
            "${prefix}pkg-pvonly"
            "${prefix}pkg-deltavega")
    endif()

    sb_test_workflow(azfinsim
        SETUP   "${prefix}resize"
        CLEANUP "${prefix}downsize"
        TESTS
            ${tests})
endfunction()
#=======================================================================================================================

# add tests for all pools
sb_get_pools(pool_names "${SB_CONFIG}")
foreach(pool_name IN LISTS pool_names)
    add_azfinsim_tests(${pool_name})
endforeach()
