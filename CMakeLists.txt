cmake_minimum_required(VERSION 3.7)

project(libgencmp)
set(LIBGENCMP_NAME gencmp)

if(NOT DEFINED GENCMPCLIENT_VERSION)
  set(GENCMPCLIENT_VERSION_MAJOR 2)
  set(GENCMPCLIENT_VERSION_MINOR 0)
  set(GENCMPCLIENT_VERSION ${GENCMPCLIENT_VERSION_MAJOR}.${GENCMPCLIENT_VERSION_MINOR})
endif()
message(STATUS "generic CMP client version " ${GENCMPCLIENT_VERSION})

# set(CMAKE_VERBOSE_MAKEFILE ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON) # needed for sonarCloud scanner

set(CMAKE_INSTALL_PREFIX "/usr") # must be set before include(GNUInstallDirs)
include(GNUInstallDirs)

if(NOT("$ENV{OPENSSL_DIR}" STREQUAL ""))
  message(STATUS "using OpenSSL from " $ENV{OPENSSL_DIR})
  if(DEFINED ENV{OPENSSL_LIB})
    set(OPENSSL_LIB $ENV{OPENSSL_LIB})
  else()
    set(OPENSSL_LIB $ENV{OPENSSL_DIR})
  endif()
  set(OpenSSL_INCLUDE_DIRS $ENV{OPENSSL_DIR}/include)
  set(OPENSSL_LIBRARIES ${OPENSSL_LIB}/libssl${CMAKE_SHARED_LIBRARY_SUFFIX}
                        ${OPENSSL_LIB}/libcrypto${CMAKE_SHARED_LIBRARY_SUFFIX})
  add_definitions(-isystem ${OpenSSL_INCLUDE_DIRS})
  if($ENV{OPENSSL_DIR} MATCHES "3\\.0")
    set(OPENSSL_VERSION 3.0)
  elseif($ENV{OPENSSL_DIR} MATCHES "3\\.1")
    set(OPENSSL_VERSION 3.1)
  elseif($ENV{OPENSSL_DIR} MATCHES "3\\.2")
    set(OPENSSL_VERSION 3.2)
  elseif($ENV{OPENSSL_DIR} MATCHES "3\\.")
    set(OPENSSL_VERSION 3)
  elseif($ENV{OPENSSL_DIR} MATCHES "1\\.1\\.1")
    set(OPENSSL_VERSION 1.1.1)
  elseif($ENV{OPENSSL_DIR} MATCHES "prepare")
    set(OPENSSL_VERSION 3.2)
  else()
    set(OPENSSL_VERSION 1.1.1)
  endif()
  message(STATUS "assuming OpenSSL version " ${OPENSSL_VERSION})
else()
  find_package(OpenSSL REQUIRED)
  message(STATUS "using OpenSSL package, with version " ${OPENSSL_VERSION})
  add_definitions(-isystem /usr/include)
endif()

if(DEFINED ENV{USE_LIBCMP} OR "${OPENSSL_VERSION}" LESS "3")
  set(USE_LIBCMP 1)
endif()

set(SRC_DIR ${PROJECT_SOURCE_DIR}/src)
set(INC_DIR ${PROJECT_SOURCE_DIR}/include)
if(DEFINED USE_LIBCMP)
  set(CMPOSSL_INC_DIR ${PROJECT_SOURCE_DIR}/cmpossl/include)
endif()

include_directories(
  ${INC_DIR}
  ${PROJECT_SOURCE_DIR}/libsecutils/include
)
if(DEFINED USE_LIBCMP)
  include_directories(
    ${CMPOSSL_INC_DIR}
    ${CMPOSSL_INC_DIR}/cmp
    ${CMAKE_SYSROOT}/usr/include/cmp
    # does not work for OpenSSL 3.0+:
    # add_definitions(-isystem ${CMPOSSL_INC_DIR}/cmp)
    # add_definitions(-isystem ${CMAKE_SYSROOT}/usr/include/cmp)
    )
endif()

configure_file(${INC_DIR}/genericCMPClient_config.h.in ${INC_DIR}/genericCMPClient_config.h)

# help CPackDeb please dpkg-shlibdeps
if(${CMAKE_VERSION} VERSION_GREATER_EQUAL "3.20.0")
  set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS_PRIVATE_DIRS
    "../lib/${CMAKE_INSTALL_FULL_LIBDIR}")
else()
  set(CMAKE_INSTALL_RPATH # must be done before add_executable()
    "../lib/${CMAKE_INSTALL_FULL_LIBDIR}")
endif()

add_library(${LIBGENCMP_NAME} SHARED
  "${PROJECT_SOURCE_DIR}/.github/workflows/build.yml"
  ${SRC_DIR}/genericCMPClient.c
)

add_executable(cmpClient
  ${SRC_DIR}/cmpClient.c
)


target_link_libraries(cmpClient
  ${LIBGENCMP_NAME}
  secutils
)
if(DEFINED USE_LIBCMP)
  target_link_libraries(cmpClient
    cmp
  )
endif()
target_link_libraries(cmpClient
  ${OPENSSL_LIBRARIES}
)
if(DEFINED ENV{SECUTILS_USE_UTA})
  target_link_libraries(cmpClient
    uta
  )
endif()
if(DEFINED ENV{SECUTILS_NO_TLS})
  add_definitions(-DSECUTILS_NO_TLS=1)
endif()

if(CMAKE_BUILD_TYPE MATCHES Release OR DEFINED ENV{NDEBUG})
  message(STATUS "build mode: Release")
  add_definitions(-DNDEBUG=1 -O2)
else()
  message(STATUS "build mode: Debug")
  add_definitions(-g -O0)

  set(DEBUG_FLAGS "-fsanitize=address,undefined -fno-sanitize-recover=all") # must use quotes on MacOSX
  add_definitions(${DEBUG_FLAGS})
  link_libraries(${DEBUG_FLAGS})
  #set(CMAKE_SHARED_LINKER_FLAGS "-fsanitize=address,undefined -fno-sanitize-recover=all") # workarund for link_libraries() ignored on MacOSX

  if(NOT APPLE)
    set(COVERAGE_FLAGS --coverage -fprofile-arcs)
    add_definitions(${COVERAGE_FLAGS})
    link_libraries(${COVERAGE_FLAGS})
    target_link_libraries(${LIBGENCMP_NAME} ${COVERAGE_FLAGS})
  endif()
endif()

add_definitions(-DDEBUG_UNUSED)
add_definitions(-DPEDANTIC -pedantic)
add_definitions(-Wall -Wextra -Wmissing-prototypes -Wstrict-prototypes
  -Wswitch -Wsign-compare -Wshadow -Wformat -Wtype-limits -Wundef)

# set_property(TARGET ${LIBGENCMP_NAME} PROPERTY C_STANDARD 90)
# set_property(TARGET cmpClient PROPERTY C_STANDARD 90)

target_link_libraries(${LIBGENCMP_NAME} ${OPENSSL_LIBRARIES} secutils) # needed for clang/MacOSX
if(DEFINED USE_LIBCMP)
  target_link_libraries(${LIBGENCMP_NAME} cmp) # needed for clang/MacOSX
endif()

set(INC_PUBLIC_HDRS
  ${INC_DIR}/genericCMPClient.h
  ${INC_DIR}/genericCMPClient_config.h
)
set_target_properties(${LIBGENCMP_NAME} PROPERTIES
  VERSION ${GENCMPCLIENT_VERSION} SOVERSION ${GENCMPCLIENT_VERSION_MAJOR}
  PUBLIC_HEADER "${INC_PUBLIC_HDRS}"
)

find_package(Git)
if(GIT_FOUND)
  set(GIT_DEPTH --depth 1) # used to speed up getting submodules
  # add --progress if the tool supports it
  execute_process(COMMAND ${CMAKE_COMMAND} -E env LC_ALL=C ${GIT_EXECUTABLE} --help submodule
    OUTPUT_VARIABLE _TMP_HELP
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if("${_TMP_HELP}" MATCHES "--progress")
    set(GIT_PROGRESS "--progress") # gives lengthy output in CI runs
  endif()
  if(DEFINED USE_LIBCMP)
    set(submodules libsecutils cmpossl)
  else()
    set(submodules libsecutils)
    endif()

  add_custom_target(update
    COMMAND echo "updating repo and submodules"
    COMMAND git submodule update ${GIT_PROGRESS} ${submodules}
    COMMAND git fetch
    COMMAND git rebase
    )
else()
  MESSAGE(WARNING "Cannot find git, so cannot add 'update' targets for submodules")
endif()

if(NOT TARGET build)
  add_custom_target(build COMMAND make all)
endif()


# installation and uninstall

if(DEFINED ENV{ROOTFS})
  set(CMAKE_INSTALL_PREFIX $ENV{ROOTFS} CACHE PATH "comment" FORCE)
endif()

# see also https://gitlab.kitware.com/cmake/cmake/-/issues/24929 and
# https://stackoverflow.com/questions/46490448/how-i-can-add-a-changelog-in-deb-with-cmake
add_custom_command(
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/debian/changelog"
    COMMAND gzip -cn9 "${CMAKE_CURRENT_SOURCE_DIR}/debian/changelog"
    > "${CMAKE_CURRENT_BINARY_DIR}/changelog.gz"
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/changelog.gz"
)
if(NOT TARGET changelog)
  add_custom_target(changelog ALL DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/changelog.gz")
endif()

install(FILES doc/Generic_CMP_client_API.pdf
  DESTINATION ${CMAKE_INSTALL_FULL_DOCDIR}-dev
  COMPONENT dev
  )

include(./Pod2Man)
POD2MAN("${CMAKE_CURRENT_SOURCE_DIR}/doc" cmpClient 1 "${CMAKE_INSTALL_FULL_MANDIR}" bin)

install(TARGETS ${LIBGENCMP_NAME}
  LIBRARY
    DESTINATION "${CMAKE_INSTALL_FULL_LIBDIR}"
    COMPONENT lib
  PUBLIC_HEADER
    DESTINATION "${CMAKE_INSTALL_FULL_INCLUDEDIR}"
    COMPONENT dev
)

install(TARGETS cmpClient
  RUNTIME
  DESTINATION "${CMAKE_INSTALL_FULL_BINDIR}"
  COMPONENT bin
)

if(NOT TARGET uninstall)
  add_custom_target(uninstall COMMAND xargs -I{} rm -vf $ENV{DESTDIR}{} <install_manifest.txt)
endif()


if(NOT DEFINED CPACK_PACKAGE_NAME)
# generate Debian packages using CPack, relying on installation defined above

SET(CPACK_PACKAGE_NAME ${PROJECT_NAME})
SET(CPACK_PACKAGE_HOMEPAGE_URL "https://github.com/siemens/gencmpclient")
SET(CPACK_RESOURCE_FILE_README "${CMAKE_SOURCE_DIR}/README.md")
SET(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_SOURCE_DIR}/LICENSE.txt")
SET(CPACK_PACKAGE_VENDOR "Siemens")
set(CPACK_PACKAGE_CONTACT "David von Oheimb <David.von.Oheimb@siemens.com>")
set(CPACK_PACKAGE_VERSION       ${GENCMPCLIENT_VERSION})
set(CPACK_PACKAGE_VERSION_MAJOR ${GENCMPCLIENT_VERSION_MAJOR})
set(CPACK_PACKAGE_VERSION_MINOR ${GENCMPCLIENT_VERSION_MINOR})
set(CPACK_STRIP_FILES ON)

set(CPACK_COMPONENT_LIB_DESCRIPTION "generic CMP client library
Generic CMP client library based on OpenSSL and otionally libcmp
With extended support for certficate status checking using CRLs and/or OCSP")
set(CPACK_COMPONENT_DEV_DESCRIPTION "libgencmp C headers and documentation
Development support for libgencmp and cmpclient")
set(CPACK_COMPONENT_BIN_DESCRIPTION "CMP client command-line interface
A CLI application for exploring the use of the generic CMP client library")

set(CPACK_GENERATOR "DEB")
set(CPACK_DEB_COMPONENT_INSTALL ON)
set(CPACK_DEBIAN_FILE_NAME DEB-DEFAULT)
set(CPACK_DEBIAN_LIB_PACKAGE_NAME "${PROJECT_NAME}")
set(CPACK_DEBIAN_BIN_PACKAGE_NAME "cmpclient")
set(CPACK_DEBIAN_DEV_PACKAGE_ARCHITECTURE "all")
set(CPACK_DEBIAN_LIB_PACKAGE_SECTION "libs")
set(CPACK_DEBIAN_DEV_PACKAGE_SECTION "devel")
set(CPACK_DEBIAN_BIN_PACKAGE_SECTION "utils")
set(CPACK_DEBIAN_PACKAGE_GENERATE_SHLIBS ON)
set(CPACK_DEBIAN_ENABLE_COMPONENT_DEPENDS ON)
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
# set(CPACK_DEBIAN_PACKAGE_DEBUG ON)
# see above assignments
# to CPACK_DEBIAN_PACKAGE_SHLIBDEPS_PRIVATE_DIRS or CMAKE_INSTALL_RPATH

if(FALSE) # for now, disable dependencies to libs of subprojectx because their .so files for some reason already get included in the package:
if(DEFINED USE_LIBCMP)
  set(CPACK_DEBIAN_PACKAGE_DEPENDS
    "libcmp (>= ${CPACK_PACKAGE_VERSION}), libsecutils (>= ${CPACK_PACKAGE_VERSION})")
else()
  set(CPACK_DEBIAN_PACKAGE_DEPENDS "libsecutils (>= ${CPACK_PACKAGE_VERSION})")
endif()
endif()

set(CPACK_DEBIAN_DEV_PACKAGE_DEPENDS "libgencmp (>= ${CPACK_PACKAGE_VERSION})")
set(CPACK_DEBIAN_DEV_PACKAGE_SUGGESTS "libcmp-dev (>= ${CPACK_PACKAGE_VERSION}), libsecutils-dev (>= ${CPACK_PACKAGE_VERSION}), libssl-dev")
# see also https://gitlab.kitware.com/cmake/cmake/-/issues/21834
# CPack Deb does not create postinst when installing to /usr/lib/x86_64-linux-gnu
set(CPACK_DEBIAN_LIB_PACKAGE_CONTROL_EXTRA "${CMAKE_CURRENT_SOURCE_DIR}/debian/extra/triggers")
set(CPACK_DEBIAN_LIB_PACKAGE_CONTROL_STRICT_PERMISSION TRUE)

set(CPACK_SOURCE_GENERATOR "TGZ")
#set(CPACK_SET_DESTDIR TRUE) # prevents package creation error when using cpack
set(CPACK_VERBATIM_VARIABLES YES)
set(CPACK_SOURCE_IGNORE_FILES
  ${CPACK_IGNORE_FILES}
  ~$
  /\\.git/
  \\.git$
  \\.deb$
  \\.gz$
  \\.so
  \\.dylib$
  /attic/
  /tmp/
  /Makefile$
  CMakeFiles/
  _CPack_Packages/
  \\.cmake$
  /CMakeCache.txt$
  /compile_commands.json$
  /install_manifest.*\\.txt$
  /changelog\.gz$
  /debian/tmp/
  \\.substvars$
  \\.log$
  /debian/\\.debhelper/
  /debian/files$
  /debian/debhelper-build-stamp
  /debian/${PROJECT_NAME}/
  /debian/${PROJECT_NAME}-dev/
  /debian/cmpclient/
  cmpClient$
  \\.1$
  \\.1\.gz$
  \\.crl$
  \\.der$
  \\.jar$
  \\.dsc$
  \\.build$
  \\.buildinfo$
  \\.changes$
  libsecutils/
  cmpossl/
  cmp-ra-component.*/
  LightweightCmpRa/
  SimpleLra/
  credentials/
  Mock/
  Insta/
  Simple/
  )

include(CPack)

# see also https://gitlab.kitware.com/cmake/cmake/-/issues/21832
# CPack Deb lacks a way to configure copyright files by component
foreach(component IN LISTS CPACK_COMPONENTS_ALL)
  if(${component} STREQUAL "lib" OR ${component} STREQUAL "bin")
    set(suffix "")
  else()
    set(suffix "-${component}")
  endif()
  install(FILES
    "${CMAKE_CURRENT_SOURCE_DIR}/debian/copyright"
    "${CMAKE_CURRENT_BINARY_DIR}/changelog.gz"
    DESTINATION "${CMAKE_INSTALL_FULL_DOCDIR}${suffix}"
    COMPONENT ${component}
    )
endforeach()

if(NOT TARGET deb)
  set (deb_pack_full_name
    "${CMAKE_CURRENT_BINARY_DIR}/${CPACK_PACKAGE_NAME}-dev_${CPACK_PACKAGE_VERSION}_all.deb")
  add_custom_command(
    OUTPUT "${deb_pack_full_name}"
    DEPENDS build
    COMMENT "Building packages possibly including doxygen run"
    COMMAND cpack # --config CPackConfig.cmake
    COMMAND cpack --config CPackSourceConfig.cmake
    )
  add_custom_target(deb DEPENDS ${deb_pack_full_name})
endif()

endif(NOT DEFINED CPACK_PACKAGE_NAME)

# submodules

macro(add_clean_target dir)
  add_custom_target(clean-${dir} COMMAND ${CMAKE_MAKE_PROGRAM} clean WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${dir})
endmacro(add_clean_target)

if(NOT YOCTO_BUILD)

  # find_package(secutils ${CPACK_PACKAGE_VERSION})
  if(NOT secutils_FOUND)
    if(NOT EXISTS libsecutils/CMakeLists.txt)
      if(GIT_FOUND)
        message(STATUS "fetching git submodule libsecutils")
        execute_process(COMMAND
          git submodule update ${GIT_PROGRESS} --init ${GIT_DEPTH} libsecutils
          WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
          RESULT_VARIABLE GIT_SUBMODULE_RESULT
          )
        if(NOT GIT_SUBMODULE_RESULT EQUAL "0")
          message(FATAL_ERROR "git failed with exit code ${GIT_SUBMODULE_RESULT}")
        endif()
      else()
        message(FATAL_ERROR "Git not found; please install git.")
      endif()
    endif()
    add_subdirectory(libsecutils)
    add_clean_target(libsecutils)
  endif()

  # find_package(cmp ${CPACK_PACKAGE_VERSION})
  if(DEFINED USE_LIBCMP AND NOT libcmp_FOUND)
    if(NOT EXISTS cmpossl/CMakeLists.txt)
      if(GIT_FOUND)
        message(STATUS "fetching git submodule cmpossl")
        execute_process(COMMAND
          git submodule update ${GIT_PROGRESS} --init ${GIT_DEPTH} cmpossl
          WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
          RESULT_VARIABLE GIT_SUBMODULE_RESULT
          )
        if(NOT GIT_SUBMODULE_RESULT EQUAL "0")
          message(FATAL_ERROR "git failed with exit code ${GIT_SUBMODULE_RESULT}")
        endif()
      else()
        message(FATAL_ERROR "Git not found; please install git.")
      endif()
    endif()
    add_subdirectory(cmpossl)
    add_clean_target(cmpossl)
  endif()

endif()
