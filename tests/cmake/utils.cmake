function(bacc_get_config_files out_var config_name)
    set(config_files "${SB_SOURCE_DIR}/examples/${config_name}/config.jsonc")
    set(${out_var} ${config_files} PARENT_SCOPE)
endfunction()

# function to return a JSON string for the chosen deployment configuration
function(bacc_get_config out_var config_name)
    bacc_get_config_files(config_files ${config_name})
    execute_process(
        COMMAND bacc json concat --use-union -i ${config_files}
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        # COMMAND_ECHO STDOUT
        COMMAND_ERROR_IS_FATAL ANY
    )
    set(${out_var} ${output} PARENT_SCOPE)
endfunction()

function(bacc_get_pools out_var config_name)
    bacc_get_config_files(config_files ${config_name})
    execute_process(
        COMMAND bacc json concat --use-union -i ${config_files} --query "sort(batch.pools[].name)"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output_json
        # COMMAND_ECHO STDOUT
        COMMAND_ERROR_IS_FATAL ANY
    )
    string(JSON pools_count LENGTH "${output_json}")
    math(EXPR pools_count "${pools_count} - 1")
    set(pools)
    foreach(i RANGE ${pools_count})
        string(JSON pool_name GET "${output_json}" ${i})
        list(APPEND pools ${pool_name})
    endforeach()
    set(${out_var} "${pools}" PARENT_SCOPE)
endfunction()

function(bacc_get_pool_vm_size out_var config_name pool_name)
    bacc_get_config_files(config_files ${config_name})
    execute_process(
        COMMAND bacc json concat --use-union -i ${config_files} --query "batch.pools[?name=='${pool_name}'].virtualMachine.size | [0]" -o tsv
        COMMAND tr "[:upper:]" "[:lower:]"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        # COMMAND_ECHO STDOUT
        COMMAND_ERROR_IS_FATAL ANY
    )
    set(${out_var} ${output} PARENT_SCOPE)
endfunction()

function(bacc_get_pool_mounts_count out_var config_name pool_name)
    bacc_get_config_files(config_files ${config_name})
    execute_process(
        COMMAND bacc json concat --use-union -i ${config_files} --query "batch.pools[?name=='${pool_name}'].mounts | [0] | length(@)"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        # COMMAND_ECHO STDOUT
        COMMAND_ERROR_IS_FATAL ANY
    )
    set(${out_var} ${output} PARENT_SCOPE)
endfunction()

function(bacc_add_test)
    set(options)
    set(oneValueArgs PASS_REGULAR_EXPRESSION FAIL_REGULAR_EXPRESSION NAME WILL_FAIL TIMEOUT REQUIRES)
    set(multiValueArgs)
    cmake_parse_arguments(bacc_args "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if (bacc_args_REQUIRES)
        # skip test if any of the required conditions is not met
        string(REGEX REPLACE " +" ";" condition "${bacc_args_REQUIRES}")
        if (${condition})
        else()
            return()
        endif()
    endif()

    add_test(NAME "${bacc_args_NAME}" ${bacc_args_UNPARSED_ARGUMENTS})

    if (bacc_args_PASS_REGULAR_EXPRESSION)
        set_tests_properties("${bacc_args_NAME}"
                             PROPERTIES PASS_REGULAR_EXPRESSION "${bacc_args_PASS_REGULAR_EXPRESSION}")
    endif()

    if (bacc_args_FAIL_REGULAR_EXPRESSION)
        set_tests_properties("${bacc_args_NAME}"
                             PROPERTIES FAIL_REGULAR_EXPRESSION "${bacc_args_FAIL_REGULAR_EXPRESSION}")
    endif()

    if (bacc_args_WILL_FAIL)
        set_tests_properties("${bacc_args_NAME}"
                             PROPERTIES WILL_FAIL TRUE)
    endif()

    if (bacc_args_TIMEOUT)
        set_tests_properties("${bacc_args_NAME}"
                             PROPERTIES TIMEOUT "${bacc_args_TIMEOUT}")
    endif()

endfunction()

function(bacc_test_workflow fixture_name)
    set(options)
    set(oneValueArgs)
    set(multiValueArgs SETUP CLEANUP TESTS)

    cmake_parse_arguments(bacc_args "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    # raise error if unknown arguments are passed
    if (DEFINED bacc_args_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "Unknown arguments passed to bacc_test_workflow: ${bacc_args_UNPARSED_ARGUMENTS}")
    endif()

    set(setup_tests ${bacc_args_SETUP})
    foreach(test IN LISTS setup_tests)
        if (TEST "${test}")
            set_property(TEST "${test}"
                         APPEND PROPERTY FIXTURES_SETUP "${fixture_name}")
        endif()
    endforeach()

    set(cleanup_tests ${bacc_args_CLEANUP})
    foreach(test IN LISTS cleanup_tests)
        if (TEST "${test}")
            set_property(TEST "${test}"
                         APPEND PROPERTY FIXTURES_CLEANUP "${fixture_name}")
        endif()
    endforeach()

    set(tests ${bacc_args_TESTS})
    foreach(test IN LISTS tests)
        if (TEST "${test}")
            set_property(TEST "${test}"
                         APPEND PROPERTY FIXTURES_REQUIRED "${fixture_name}")
        endif()
    endforeach()
endfunction()
