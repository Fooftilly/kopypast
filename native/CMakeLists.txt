# SPDX-License-Identifier: GPL-3.0-or-later
cmake_minimum_required(VERSION 3.21)
project(KopypastFileIO LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
find_package(Qt6 6.5 REQUIRED COMPONENTS Core Qml)
qt_standard_project_setup()
qt_add_library(kopypastfileio SHARED)
qt_add_qml_module(kopypastfileio
    URI io.github.fooftilly.kopypast.fileio
    VERSION 1.0
    OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml/io/github/fooftilly/kopypast/fileio"
    SOURCES backupfile.h backupfile.cpp
)
target_link_libraries(kopypastfileio PRIVATE Qt6::Core Qt6::Qml)

include(CTest)
if(BUILD_TESTING)
    find_package(Qt6 REQUIRED COMPONENTS Test)
    qt_add_executable(tst_backupfile tst_backupfile.cpp)
    target_link_libraries(tst_backupfile PRIVATE kopypastfileio Qt6::Test Qt6::Qml)
    add_dependencies(tst_backupfile kopypastfileioplugin)
    add_test(NAME backupfile COMMAND tst_backupfile)
    set_tests_properties(backupfile PROPERTIES
        ENVIRONMENT "KOPYPAST_TEST_QML_PATH=${CMAKE_BINARY_DIR}/qml")
endif()
