#-------------------------------------------------------------------------------
# These variables are core deployment variables
set(SB_SUBSCRIPTION_ID "" CACHE STRING "The subscription ID to use for testing")
set(SB_RESOURCE_GROUP_NAME "" CACHE STRING "The name of the deployment resource group")
set(SB_CONFIG "" CACHE STRING "The configuration to use for testing")

#-------------------------------------------------------------------------------
# These options are used to provide us information about the deployment / environment
option(SB_SUPPORTS_DOCKERHUB "Set to ON if Docker is supported in the environment" OFF)
option(SB_SUPPORTS_ACR "Set to ON if Azure Container Registry is deployed in the environment" OFF)
option(SB_SUPPORTS_NETWORK_ACCESS "Set to ON if Batch service (and others) is (are) accessible from current network" OFF)
option(SB_SUPPORTS_JUMPBOX "Set to ON if jumpbox is deployed in the environment" OFF)
option(SB_SUPPORTS_AZFINSIM "Set to ON if AzFinSim is supported in the environment" OFF)
option(SB_SUPPORTS_AZFINSIM_PREINSTALLED_PACKAGES "Set to ON if AzFinSim package mode is supported in the environment" OFF)

#-------------------------------------------------------------------------------
# Variables needed for secured batch testing (if SB_JUMPBOX_SUPPORTED is ON)
set(SB_JUMPBOX_RESOURCE_GROUP_NAME "" CACHE STRING "The name of the jumpbox resource group")
set(SB_JUMPBOX_NAME "" CACHE STRING "The name of the jumpbox")

#-------------------------------------------------------------------------------
# A debugging option to speed up local testing / development
option(SB_TESTING_SKIP_POOL_DOWNSIZE "Skip pool downsize in automated testing" OFF)

#-------------------------------------------------------------------------------
# locate available example configurations
file(GLOB available_configs LIST_DIRECTORIES true
     RELATIVE "${SB_SOURCE_DIR}/examples"
     CONFIGURE_DEPENDS "${SB_SOURCE_DIR}/examples/*")
set_property(CACHE SB_CONFIG PROPERTY STRINGS ${available_configs})

#-------------------------------------------------------------------------------
# Add some basic validation
#-------------------------------------------------------------------------------

if (NOT SB_SUBSCRIPTION_ID)
    message(FATAL_ERROR "SB_SUBSCRIPTION_ID must be set")
endif()

if (NOT SB_RESOURCE_GROUP_NAME)
    message(FATAL_ERROR "SB_RESOURCE_GROUP_NAME must be set")
endif()

if (SB_SUPPORTS_JUMPBOX)
    if (NOT SB_JUMPBOX_RESOURCE_GROUP_NAME)
        message(FATAL_ERROR "SB_JUMPBOX_RESOURCE_GROUP_NAME must be set")
    endif()

    if (NOT SB_JUMPBOX_NAME)
        message(FATAL_ERROR "SB_JUMPBOX_NAME must be set")
    endif()
endif()
