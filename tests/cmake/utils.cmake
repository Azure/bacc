function(sb_get_config_files out_var config_name)
    file(GLOB config_files RELATIVE "${SB_SOURCE_DIR}/config"
         "${SB_SOURCE_DIR}/config/*.jsonc")
    if (NOT config_name STREQUAL "DEFAULT")
        file(GLOB config_files_custom
             RELATIVE ${SB_SOURCE_DIR}/config/${config_name}
             "${SB_SOURCE_DIR}/examples/${config_name}/*.jsonc")
        list(REMOVE_ITEM config_files ${config_files_custom})
        list(TRANSFORM config_files PREPEND "${SB_SOURCE_DIR}/config/")
        list(TRANSFORM config_files_custom PREPEND "${SB_SOURCE_DIR}/examples/${config_name}/")
        list(APPEND config_files ${config_files_custom})
    else()
        list(TRANSFORM config_files PREPEND "${SB_SOURCE_DIR}/config/")
    endif()
    set(${out_var} ${config_files} PARENT_SCOPE)
endfunction()

# function to return a JSON string for the chosen deployment configuration
function(sb_get_config out_var config_name)
    sb_get_config_files(config_files ${config_name})
    execute_process(
        COMMAND sb json concat --use-union -i ${config_files}
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        # COMMAND_ECHO STDOUT
        COMMAND_ERROR_IS_FATAL ANY
    )
    set(${out_var} ${output} PARENT_SCOPE)
endfunction()

function(sb_get_pools out_var config_name)
    sb_get_config_files(config_files ${config_name})
    execute_process(
        COMMAND sb json concat --use-union -i ${config_files} --query "sort(pools[].name)"
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

function(sb_get_pool_vm_size out_var config_name pool_name)
    sb_get_config_files(config_files ${config_name})
    execute_process(
        COMMAND sb json concat --use-union -i ${config_files} --query "pools[?name=='${pool_name}'].virtualMachine.size | [0]" -o tsv
        COMMAND tr "[:upper:]" "[:lower:]"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        # COMMAND_ECHO STDOUT
        COMMAND_ERROR_IS_FATAL ANY
    )
    set(${out_var} ${output} PARENT_SCOPE)
endfunction()

function(sb_get_pool_mounts_count out_var config_name pool_name)
    sb_get_config_files(config_files ${config_name})
    execute_process(
        COMMAND sb json concat --use-union -i ${config_files} --query "pools[?name=='${pool_name}'].mounts | [0] | length(@)"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        # COMMAND_ECHO STDOUT
        COMMAND_ERROR_IS_FATAL ANY
    )
    set(${out_var} ${output} PARENT_SCOPE)
endfunction()

function(sb_add_test)
    set(options)
    set(oneValueArgs PASS_REGULAR_EXPRESSION FAIL_REGULAR_EXPRESSION NAME WILL_FAIL TIMEOUT REQUIRES)
    set(multiValueArgs)
    cmake_parse_arguments(sb_args "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if (sb_args_REQUIRES)
        # skip test if any of the required conditions is not met
        string(REGEX REPLACE " +" ";" condition "${sb_args_REQUIRES}")
        if (${condition})
        else()
            return()
        endif()
    endif()

    add_test(NAME "${sb_args_NAME}" ${sb_args_UNPARSED_ARGUMENTS})

    if (sb_args_PASS_REGULAR_EXPRESSION)
        set_tests_properties("${sb_args_NAME}"
                             PROPERTIES PASS_REGULAR_EXPRESSION "${sb_args_PASS_REGULAR_EXPRESSION}")
    endif()

    if (sb_args_FAIL_REGULAR_EXPRESSION)
        set_tests_properties("${sb_args_NAME}"
                             PROPERTIES FAIL_REGULAR_EXPRESSION "${sb_args_FAIL_REGULAR_EXPRESSION}")
    endif()

    if (sb_args_WILL_FAIL)
        set_tests_properties("${sb_args_NAME}"
                             PROPERTIES WILL_FAIL TRUE)
    endif()

    if (sb_args_TIMEOUT)
        set_tests_properties("${sb_args_NAME}"
                             PROPERTIES TIMEOUT "${sb_args_TIMEOUT}")
    endif()

endfunction()

function(sb_test_workflow fixture_name)
    set(options)
    set(oneValueArgs SETUP CLEANUP)
    set(multiValueArgs TESTS)

    cmake_parse_arguments(sb_args "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    # raise error if unknown arguments are passed
    if (DEFINED sb_args_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "Unknown arguments passed to sb_test_workflow: ${sb_args_UNPARSED_ARGUMENTS}")
    endif()

    if (DEFINED sb_args_SETUP AND TEST "${sb_args_SETUP}")
        set_tests_properties("${sb_args_SETUP}"
                             PROPERTIES FIXTURES_SETUP "${fixture_name}")
        set_property(TEST "${sb_args_SETUP}"
                     APPEND PROPERTY LABELS "${fixture_name}")
    endif()
    if (DEFINED sb_args_CLEANUP AND TEST "${sb_args_CLEANUP}")
        set_tests_properties("${sb_args_CLEANUP}"
                             PROPERTIES FIXTURES_CLEANUP "${fixture_name}")
        set_property(TEST "${sb_args_CLEANUP}"
                     APPEND PROPERTY LABELS "${fixture_name}")
    endif()
    set(tests ${sb_args_TESTS})
    foreach(test IN LISTS tests)
        if (TEST "${test}")
            set_tests_properties("${test}"
                                 PROPERTIES FIXTURES_SETUP "${fixture_name}")
            set_property(TEST "${test}"
                         APPEND PROPERTY LABELS "${fixture_name}")
        endif()
    endforeach()
endfunction()
