# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

cmake_minimum_required(VERSION 3.22)
project(tests LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

#===============================================================================
# setup CMake variables / options exposed to the user
set(SB_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/..")
set(SB_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}")
include(variables)

#===============================================================================
# enable testing
include(CTest)

# include some common utilities / macros
include(utils)

# include validation tests
include(validation_tests)

# include azfinsim tests
include(azfinsim_tests)

# include secured batch tests
if (SB_SUPPORTS_JUMPBOX)
    include(secured_batch_tests)
endif()
