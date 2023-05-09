cmake_minimum_required(VERSION 3.22)
project(tests LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

set(SB_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/..")
set(SB_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}/..")

# variables
set(SB_CONFIG DEFAULT CACHE STRING "The configuration to use for testing")
set(SB_RESOURCE_GROUP_NAME "" CACHE STRING "The name of the deployment resource group")
set(SB_SUBSCRIPTION_ID "" CACHE STRING "The subscription ID to use for testing")
option(SB_TESTING_SKIP_POOL_DOWNSIZE "Skip pool downsize in automated testing" OFF)

# locate available example configurations
file(GLOB available_configs LIST_DIRECTORIES true
     RELATIVE "${SB_SOURCE_DIR}/examples"
     CONFIGURE_DEPENDS "${SB_SOURCE_DIR}/examples/*")
set_property(CACHE SB_CONFIG PROPERTY STRINGS "DEFAULT" ${available_configs})

if (NOT SB_RESOURCE_GROUP_NAME)
    message(FATAL_ERROR "SB_RESOURCE_GROUP_NAME must be set")
endif()

if (NOT SB_SUBSCRIPTION_ID)
    message(FATAL_ERROR "SB_SUBSCRIPTION_ID must be set")
endif()

# enable testing
include(CTest)

# include validation tests
include(validation_tests)

# include azfinsim tests
include(azfinsim_tests)
