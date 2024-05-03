include("${CMAKE_CURRENT_LIST_DIR}/Configure_Default.cmake")

message(STATUS "Configuring Platform: Windows")

set_property(GLOBAL PROPERTY NS_CMAKE_PLATFORM_WINDOWS ON)
set_property(GLOBAL PROPERTY NS_CMAKE_PLATFORM_WINDOWS_DESKTOP ON)
set_property(GLOBAL PROPERTY NS_CMAKE_PLATFORM_SUPPORTS_VULKAN ON)
set_property(GLOBAL PROPERTY NS_CMAKE_PLATFORM_SUPPORTS_EDITOR ON)

if(CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION)
    set(NS_CMAKE_WINDOWS_SDK_VERSION ${CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION})
else()
    set(NS_CMAKE_WINDOWS_SDK_VERSION ${CMAKE_SYSTEM_VERSION})
    string(REGEX MATCHALL "\\." NUMBER_OF_DOTS "${NS_CMAKE_WINDOWS_SDK_VERSION}")
    list(LENGTH NUMBER_OF_DOTS NUMBER_OF_DOTS)

    if(NUMBER_OF_DOTS EQUAL 2)
        set(NS_CMAKE_WINDOWS_SDK_VERSION "${NS_CMAKE_WINDOWS_SDK_VERSION}.0")
    endif()
endif()

set_property(GLOBAL PROPERTY NS_CMAKE_WINDOWS_SDK_VERSION ${NS_CMAKE_WINDOWS_SDK_VERSION})

# #####################################
# ## General settings
# #####################################
set(NS_COMPILE_ENGINE_AS_DLL ON CACHE BOOL "Whether to compile the code as a shared libraries (DLL).")
mark_as_advanced(FORCE NS_COMPILE_ENGINE_AS_DLL)

macro(ns_platform_pull_properties)

	get_property(NS_CMAKE_PLATFORM_WINDOWS GLOBAL PROPERTY NS_CMAKE_PLATFORM_WINDOWS)
	get_property(NS_CMAKE_PLATFORM_WINDOWS_UWP GLOBAL PROPERTY NS_CMAKE_PLATFORM_WINDOWS_UWP)
	get_property(NS_CMAKE_PLATFORM_WINDOWS_DESKTOP GLOBAL PROPERTY NS_CMAKE_PLATFORM_WINDOWS_DESKTOP)
	get_property(NS_CMAKE_WINDOWS_SDK_VERSION GLOBAL PROPERTY NS_CMAKE_WINDOWS_SDK_VERSION)

endmacro()

macro (ns_platformhook_set_build_flags_clang)
    # Disable the warning that clang doesn't support pragma optimize.
    target_compile_options(${TARGET_NAME} PRIVATE -Wno-ignored-pragma-optimize -Wno-pragma-pack)
endmacro()

macro(ns_platform_detect_generator)
	string(FIND ${CMAKE_VERSION} "MSVC" VERSION_CONTAINS_MSVC)

	if(${VERSION_CONTAINS_MSVC} GREATER -1)
		message(STATUS "CMake was called from Visual Studio Open Folder workflow")
		set_property(GLOBAL PROPERTY NS_CMAKE_INSIDE_VS ON)
	endif()

    if(CMAKE_GENERATOR MATCHES "Visual Studio")
        # Visual Studio (All VS generators define MSVC)
        message(STATUS "Generator is MSVC (NS_CMAKE_GENERATOR_MSVC)")

        set_property(GLOBAL PROPERTY NS_CMAKE_GENERATOR_MSVC ON)
        set_property(GLOBAL PROPERTY NS_CMAKE_GENERATOR_PREFIX "Vs")
        set_property(GLOBAL PROPERTY NS_CMAKE_GENERATOR_CONFIGURATION $<CONFIGURATION>)
    elseif(CMAKE_GENERATOR MATCHES "Ninja") # Ninja makefiles. Only makefile format supported by Visual Studio Open Folder
        message(STATUS "Buildsystem is Ninja (NS_CMAKE_GENERATOR_NINJA)")

        set_property(GLOBAL PROPERTY NS_CMAKE_GENERATOR_NINJA ON)
        set_property(GLOBAL PROPERTY NS_CMAKE_GENERATOR_PREFIX "Ninja")
        set_property(GLOBAL PROPERTY NS_CMAKE_GENERATOR_CONFIGURATION ${CMAKE_BUILD_TYPE})
    else()
        message(FATAL_ERROR "Generator '${CMAKE_GENERATOR}' is not supported on Windows! Please extend ns_platform_detect_generator()")
    endif()
endmacro()

macro(ns_platformhook_find_vulkan)
    if(NS_CMAKE_ARCHITECTURE_64BIT)
        if((NS_VULKAN_DIR STREQUAL "NS_VULKAN_DIR-NOTFOUND") OR(NS_VULKAN_DIR STREQUAL ""))
            # set(CMAKE_FIND_DEBUG_MODE TRUE)
            unset(NS_VULKAN_DIR CACHE)
            unset(NsVulkan_DIR CACHE)
            find_path(NS_VULKAN_DIR Config/vk_layer_settings.txt
                PATHS
                ${NS_VULKAN_DIR}
                $ENV{VULKAN_SDK}
                REQUIRED
            )

            # set(CMAKE_FIND_DEBUG_MODE FALSE)
        endif()
    else()
        message(FATAL_ERROR "TODO: Vulkan is not yet supported on this platform and/or architecture.")
    endif()

    include(FindPackageHandleStandardArgs)
    find_package_handle_standard_args(NsVulkan DEFAULT_MSG NS_VULKAN_DIR)

    if(NSVULKAN_FOUND)
        if(NS_CMAKE_ARCHITECTURE_64BIT)
            add_library(NsVulkan::Loader STATIC IMPORTED)
            set_target_properties(NsVulkan::Loader PROPERTIES IMPORTED_LOCATION "${NS_VULKAN_DIR}/Lib/vulkan-1.lib")
            set_target_properties(NsVulkan::Loader PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${NS_VULKAN_DIR}/Include")

            add_library(NsVulkan::DXC SHARED IMPORTED)
            set_target_properties(NsVulkan::DXC PROPERTIES IMPORTED_LOCATION "${NS_VULKAN_DIR}/Bin/dxcompiler.dll")
            set_target_properties(NsVulkan::DXC PROPERTIES IMPORTED_IMPLIB "${NS_VULKAN_DIR}/Lib/dxcompiler.lib")
            set_target_properties(NsVulkan::DXC PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${NS_VULKAN_DIR}/Include")
        else()
            message(FATAL_ERROR "TODO: Vulkan is not yet supported on this platform and/or architecture.")
        endif()
    endif()    
endmacro()

macro(ns_platformhook_find_qt)
	if(NS_CMAKE_COMPILER_CLANG)
		# The qt6 interface compile options contain msvc specific flags which don't exist for clang.
		set_target_properties(Qt6::Platform PROPERTIES INTERFACE_COMPILE_OPTIONS "")
		
		# Qt6 link options include '-NXCOMPAT' which does not exist on clang.
		get_target_property(QtLinkOptions Qt6::PlatformCommonInternal INTERFACE_LINK_OPTIONS)
		string(REPLACE "-NXCOMPAT;" "" QtLinkOptions "${QtLinkOptions}")
		set_target_properties(Qt6::PlatformCommonInternal PROPERTIES INTERFACE_LINK_OPTIONS ${QtLinkOptions})
	endif()
endmacro()


macro(ns_platformhook_download_qt)

	# Currently only implemented for x64
	if(NS_CMAKE_ARCHITECTURE_64BIT)
		# Upgrade from Qt5 to Qt6 if the NS_QT_DIR points to a previously automatically downloaded Qt5 package.
		if("${NS_QT_DIR}" MATCHES ".*Qt-5\\.13\\.0-vs141-x64")
			set(NS_QT_DIR "NS_QT_DIR-NOTFOUND" CACHE PATH "Directory of the Qt installation" FORCE)
		endif()
	
		if(NS_CMAKE_ARCHITECTURE_64BIT)
			set(NS_SDK_VERSION "${NS_CONFIG_QT_WINX64_VERSION}")
			set(NS_SDK_URL "${NS_CONFIG_QT_WINX64_URL}")
		endif()

		if((NS_QT_DIR STREQUAL "NS_QT_DIR-NOTFOUND") OR(NS_QT_DIR STREQUAL ""))
			ns_download_and_extract("${NS_SDK_URL}" "${CMAKE_BINARY_DIR}" "${NS_SDK_VERSION}")

			set(NS_QT_DIR "${CMAKE_BINARY_DIR}/${NS_SDK_VERSION}" CACHE PATH "Directory of the Qt installation" FORCE)
		endif()
	endif()

endmacro()