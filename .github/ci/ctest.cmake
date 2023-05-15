# error if variable not defined
macro(required_var var)
    if (NOT DEFINED ${var})
        message(FATAL_ERROR "Required variable ${var} is not defined")
    endif()
endmacro()

required_var(SB_TEST_SUITE)
required_var(SB_DEPLOYMENT_CONFIG)
required_var(SB_SUBSCRIPTION_ID)
required_var(SB_RESOURCE_GROUP_NAME)
required_var(SB_DEPLOYMENT_ENABLE_CONTAINERS)

set(CTEST_CMAKE_GENERATOR "Unix Makefiles")
ctest_start(Experimental)

# Gather update information.
find_package(Git)
set(CTEST_UPDATE_VERSION_ONLY ON)
set(CTEST_UPDATE_COMMAND "${GIT_EXECUTABLE}")
ctest_update(RETURN_VALUE exit_code)

if (exit_code EQUAL 0)
    message(STATUS "Configure passed")
else()
    message(FATAL_ERROR "Configure failed")
endif()

# Configure the project.
set(cmake_args
    -DCTEST_USE_LAUNCHERS=1
    -DSB_CONFIG:STRING=${SB_DEPLOYMENT_CONFIG}
    -DSB_SUBSCRIPTION_ID:STRING=${SB_SUBSCRIPTION_ID}
    -DSB_RESOURCE_GROUP_NAME:STRING=${SB_RESOURCE_GROUP_NAME}
    -DSB_JUMPBOX_RESOURCE_GROUP_NAME:STRING=${SB_JUMPBOX_RESOURCE_GROUP_NAME}
    -DSB_JUMPBOX_NAME:STRING=${SB_JUMPBOX_NAME}
    -DSB_SUPPORTS_ACR:BOOL=${SB_DEPLOYMENT_ENABLE_CONTAINERS}
    -C ${CMAKE_CURRENT_LIST_DIR}/configure-${SB_TEST_SUITE}.cmake
)
ctest_configure(OPTIONS "${cmake_args}")

# run the tests
ctest_test(RETURN_VALUE exit_code)

# submit the results
if (DEFINED SB_SKIP_SUBMIT AND "${SB_SKIP_SUBMIT}")
    message(STATUS "Skipping test submission")
else()
    # ctest_upload(
    #     FILES ${SB_BINARY_DIR}/CMakeCache.txt)
    ctest_submit()
endif()

if (exit_code EQUAL 0)
    message(STATUS "Tests passed")
else()
    message(FATAL_ERROR "Tests failed")
endif()
