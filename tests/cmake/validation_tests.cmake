
## This module adds various deployment validate tests
## to the CTest suite.  These tests are run after the
## deployment is complete to ensure that the deployment
## was successful and has the expected resources.

# Confirm that the deployment is valid
sb_add_test(
    NAME "validate-deployment"
    COMMAND sb show -g ${SB_RESOURCE_GROUP_NAME} -s ${SB_SUBSCRIPTION_ID} --only-validate --query "status" -o json
    PASS_REGULAR_EXPRESSION "true"
)

# get list of all pools defined in the chosen configuration
sb_get_pools(pool_names "${SB_CONFIG}")
list(JOIN pool_names ".*" pool_names_regex)

# Confirm that requested pools have been created.
sb_add_test(
    NAME "validate-pools"
    COMMAND sb pool list -g ${SB_RESOURCE_GROUP_NAME} -s ${SB_SUBSCRIPTION_ID} --query "[].id" -o tsv
    PASS_REGULAR_EXPRESSION "${pool_names_regex}"
    REQUIRES "SB_SUPPORTS_NETWORK_ACCESS"
)

# Confirm we don't have network access when not available
sb_add_test(
    NAME "validate-no-network-access"
    COMMAND sb pool list -g ${SB_RESOURCE_GROUP_NAME} -s ${SB_SUBSCRIPTION_ID} --query "[].id" -o tsv
    FAIL_REGULAR_EXPRESSION "AuthorizationFailure"
    WILL_FAIL TRUE
    REQUIRES "NOT SB_SUPPORTS_NETWORK_ACCESS"
)

# validate various pool properties.
foreach(pool_name IN LISTS pool_names)
    # verify pool name / id
    sb_add_test(
        NAME "validate-pool-${pool_name}-id"
        COMMAND sb pool show -g ${SB_RESOURCE_GROUP_NAME} -s ${SB_SUBSCRIPTION_ID} -p ${pool_name} --query "id" -o tsv
        PASS_REGULAR_EXPRESSION "^${pool_name}"
        REQUIRES "SB_SUPPORTS_NETWORK_ACCESS"
    )

    # verify pool vm size
    sb_get_pool_vm_size(vm_size "${SB_CONFIG}" "${pool_name}")
    sb_add_test(
        NAME "validate-pool-${pool_name}-vm-size"
        COMMAND sb pool show -g ${SB_RESOURCE_GROUP_NAME} -s ${SB_SUBSCRIPTION_ID} -p ${pool_name} --query "vmSize" -o tsv
        PASS_REGULAR_EXPRESSION "^${vm_size}"
        REQUIRES "SB_SUPPORTS_NETWORK_ACCESS"
    )

    # verify pool has mounted volumes
    sb_get_pool_mounts_count(mounts_count "${SB_CONFIG}" "${pool_name}")
    sb_add_test(
        NAME "validate-pool-${pool_name}-mounts-count"
        COMMAND sb pool show -g ${SB_RESOURCE_GROUP_NAME} -s ${SB_SUBSCRIPTION_ID} -p ${pool_name} --query "mountConfiguration | length(@)" -o tsv
        PASS_REGULAR_EXPRESSION "^${mounts_count}"
        REQUIRES "SB_SUPPORTS_NETWORK_ACCESS"
    )

    # verify pool is not using public IPs
    sb_add_test(
        NAME "validate-pool-${pool_name}-no-public-ip"
        COMMAND sb pool show -g ${SB_RESOURCE_GROUP_NAME} -s ${SB_SUBSCRIPTION_ID} -p ${pool_name} --query "networkConfiguration.publicIpAddressConfiguration.provision" -o tsv
        PASS_REGULAR_EXPRESSION "^nopublicipaddresses"
        REQUIRES "SB_SUPPORTS_NETWORK_ACCESS"
    )
endforeach()
