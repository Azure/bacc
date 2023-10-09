# include common utilities
include(utils)

# generate jumpbox script
configure_file("cmake/jumpbox_script.sh.in" "${SB_BINARY_DIR}/jumpbox_script.sh" @ONLY)

bacc_add_test(
    NAME "linux-jumpbox-await-provisioning"
    COMMAND az vm wait
        -g ${SB_JUMPBOX_RESOURCE_GROUP_NAME}
        -n ${SB_JUMPBOX_NAME}
        --created
    TIMEOUT 1800 # 30 minutes
)

bacc_add_test(
    NAME "linux-jumpbox-dashboard"
    COMMAND az vm run-command invoke
        -g ${SB_JUMPBOX_RESOURCE_GROUP_NAME}
        -n ${SB_JUMPBOX_NAME}
        --command-id RunShellScript
        --scripts @${SB_BINARY_DIR}/jumpbox_script.sh
    PASS_REGULAR_EXPRESSION ".*100% tests passed,.*"
    TIMEOUT 1800 # 30 minutes
)

bacc_test_workflow("linux-jumpbox-tests"
    SETUP
        "linux-jumpbox-await-provisioning"
    TESTS
        "linux-jumpbox-dashboard"
)
