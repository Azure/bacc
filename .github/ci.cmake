set(CTEST_SITE "$ENV{SB_SITE_NAME}")
set(CTEST_BUILD_NAME "$ENV{SB_BUILD_NAME}")
set(CTEST_SOURCE_DIRECTORY "$ENV{SB_SOURCE_DIR}")
set(CTEST_BINARY_DIRECTORY "$ENV{SB_BINARY_DIR}")
set(CTEST_CMAKE_GENERATOR "Unix Makefiles")

ctest_start(Experimental)

# Gather update information.
find_package(Git)
set(CTEST_UPDATE_VERSION_ONLY ON)
set(CTEST_UPDATE_COMMAND "${GIT_EXECUTABLE}")
ctest_update()


# Configure the project.
set(cmake_args
    -D CTEST_USE_LAUNCHERS=1
    -D SB_CONFIG:STRING=$ENV{SB_CONFIG}
    -D SB_RESOURCE_GROUP_NAME:STRING=$ENV{SB_RESOURCE_GROUP_NAME}
    -D SB_SUBSCRIPTION_ID:STRING=$ENV{SB_SUBSCRIPTION_ID}
)
ctest_configure(OPTIONS "${cmake_args}")

# run the tests
ctest_test()

# submit the results
ctest_submit()
