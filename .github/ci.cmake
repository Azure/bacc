# set variable iff it is defined in the environment
macro(set_if_env var env_var)
    if (DEFINED ${env_var})
        set(${var} "${${env_var}}")
    elseif (DEFINED ENV{${env_var}})
        set(${var} "$ENV{${env_var}}")
    endif()
endmacro()

# set variable from a required environment variable
macro(set_required var env_var)
    if (DEFINED ${env_var})
        set(${var} "${${env_var}}")
    elseif (DEFINED ENV{${env_var}})
        set(${var} "$ENV{${env_var}}")
    else()
        message(FATAL_ERROR "Required environment variable ${env_var} is not defined")
    endif()
endmacro()

set_if_env(CTEST_SITE SB_SITE_NAME)
set_if_env(CTEST_BUILD_NAME SB_BUILD_NAME)
set_if_env(SB_SKIP_SUBMIT SB_SKIP_SUBMIT)
set_if_env(SB_JUMPBOX_RESOURCE_GROUP SB_JUMPBOX_RESOURCE_GROUP)
set_if_env(SB_JUMPBOX_NAME SB_JUMPBOX_NAME)

set_required(CTEST_SOURCE_DIRECTORY SB_SOURCE_DIR)
set_required(CTEST_BINARY_DIRECTORY SB_BINARY_DIR)
set_required(SB_RESOURCE_GROUP_NAME SB_RESOURCE_GROUP_NAME)
set_required(SB_SUBSCRIPTION_ID SB_SUBSCRIPTION_ID)
set_required(SB_CONFIG SB_CONFIG)


if ((NOT DEFINED ENV{SB_TEST_SECURED_BATCH}) OR ("$ENV{SB_TEST_SECURED_BATCH}" STREQUAL "FALSE"))
    set(SB_TEST_SECURED_BATCH FALSE)
else()
    set(SB_TEST_SECURED_BATCH TRUE)
    set(CTEST_BUILD_NAME "${CTEST_BUILD_NAME}-secured")
endif()

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

if (NOT DEFINED ENV{SB_DOCKERHUB_RESTRICTED})
    set(SB_DOCKERHUB_RESTRICTED FALSE)
else()
    set_if_env(SB_DOCKERHUB_RESTRICTED SB_DOCKERHUB_RESTRICTED)
endif()


# Configure the project.
set(cmake_args
    -D CTEST_USE_LAUNCHERS=1
    -D SB_CONFIG:STRING=${SB_CONFIG}
    -D SB_RESOURCE_GROUP_NAME:STRING=${SB_RESOURCE_GROUP_NAME}
    -D SB_SUBSCRIPTION_ID:STRING=${SB_SUBSCRIPTION_ID}
    -D SB_TEST_SECURED_BATCH:BOOL=${SB_TEST_SECURED_BATCH}
    -D SB_JUMPBOX_RESOURCE_GROUP:STRING=${SB_JUMPBOX_RESOURCE_GROUP}
    -D SB_JUMPBOX_NAME:STRING=${SB_JUMPBOX_NAME}
    -D SB_DOCKERHUB_RESTRICTED:BOOL=${SB_DOCKERHUB_RESTRICTED}
)
ctest_configure(OPTIONS "${cmake_args}")

# run the tests
ctest_test(RETURN_VALUE exit_code)

# submit the results
if (SB_SKIP_SUBMIT)
    message(STATUS "Skipping test submission")
else()
    ctest_submit()
endif()

if (exit_code EQUAL 0)
    message(STATUS "Tests passed")
else()
    message(FATAL_ERROR "Tests failed")
endif()
