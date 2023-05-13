set(CTEST_SITE "$ENV{SB_SITE_NAME}")
set(CTEST_BUILD_NAME "$ENV{SB_BUILD_NAME}")
set(CTEST_SOURCE_DIRECTORY "$ENV{SB_SOURCE_DIR}")
set(CTEST_BINARY_DIRECTORY "$ENV{SB_BINARY_DIR}")
set(CTEST_CMAKE_GENERATOR "Unix Makefiles")
set(SB_TEST_SECURED_BATCH "$ENV{SB_TEST_SECURED_BATCH}")

if (NOT SB_TEST_SECURED_BATCH OR SB_TEST_SECURED_BATCH STREQUAL "FALSE")
    set(SB_TEST_SECURED_BATCH FALSE)
else()
    set(SB_TEST_SECURED_BATCH TRUE)
    set(CTEST_BUILD_NAME "${CTEST_BUILD_NAME}-secured")
endif()

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
    -D CTEST_USE_LAUNCHERS=1
    -D SB_CONFIG:STRING=$ENV{SB_CONFIG}
    -D SB_RESOURCE_GROUP_NAME:STRING=$ENV{SB_RESOURCE_GROUP_NAME}
    -D SB_SUBSCRIPTION_ID:STRING=$ENV{SB_SUBSCRIPTION_ID}
    -D SB_TEST_SECURED_BATCH:BOOL=${SB_TEST_SECURED_BATCH}
)
ctest_configure(OPTIONS "${cmake_args}")

# run the tests
ctest_test(RETURN_VALUE exit_code)

# submit the results
ctest_submit()

if (exit_code EQUAL 0)
    message(STATUS "Tests passed")
else()
    message(FATAL_ERROR "Tests failed")
endif()
