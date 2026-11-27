# SPDX-License-Identifier: GPL-3.0-or-later
cmake_minimum_required(VERSION 3.21)
project(KopypastFileIO LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml)
qt_standard_project_setup()
qt_add_library(kopypastfileio SHARED)
qt_add_qml_module(kopypastfileio
    URI io.github.fooftilly.kopypast.fileio
    VERSION 1.0
    OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml/io/github/fooftilly/kopypast/fileio"
    SOURCES backupfile.h backupfile.cpp sharedlibrary.h sharedlibrary.cpp clipboard.h clipboard.cpp
)
target_link_libraries(kopypastfileio PRIVATE Qt6::Core Qt6::Gui Qt6::Qml)

include(GNUInstallDirs)
set(KOPYPAST_QML_INSTALL_DIR "${CMAKE_INSTALL_LIBDIR}/qt6/qml" CACHE STRING "Qt QML module installation root")
set(module_dir "${KOPYPAST_QML_INSTALL_DIR}/io/github/fooftilly/kopypast/fileio")
set_target_properties(kopypastfileioplugin PROPERTIES INSTALL_RPATH "$ORIGIN")
install(TARGETS kopypastfileio kopypastfileioplugin LIBRARY DESTINATION "${module_dir}")
install(FILES
    "${CMAKE_BINARY_DIR}/qml/io/github/fooftilly/kopypast/fileio/qmldir"
    "${CMAKE_BINARY_DIR}/qml/io/github/fooftilly/kopypast/fileio/kopypastfileio.qmltypes"
    DESTINATION "${module_dir}")

include(CTest)
if(BUILD_TESTING)
    find_package(Qt6 REQUIRED COMPONENTS Test)
    qt_add_executable(tst_backupfile tst_backupfile.cpp)
    target_link_libraries(tst_backupfile PRIVATE kopypastfileio Qt6::Test Qt6::Qml)
    add_dependencies(tst_backupfile kopypastfileioplugin)
    qt_add_executable(tst_sharedlibrary tst_sharedlibrary.cpp)
    target_link_libraries(tst_sharedlibrary PRIVATE kopypastfileio Qt6::Test Qt6::Qml)
    add_dependencies(tst_sharedlibrary kopypastfileioplugin)
    add_test(NAME sharedlibrary COMMAND tst_sharedlibrary)
    set_tests_properties(sharedlibrary PROPERTIES
        ENVIRONMENT "KOPYPAST_TEST_QML_PATH=${CMAKE_BINARY_DIR}/qml")
    qt_add_executable(tst_clipboard tst_clipboard.cpp)
    target_link_libraries(tst_clipboard PRIVATE kopypastfileio Qt6::Gui Qt6::Test Qt6::Qml)
    add_dependencies(tst_clipboard kopypastfileioplugin)
    add_test(NAME clipboard COMMAND tst_clipboard)
    set_tests_properties(clipboard PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen;KOPYPAST_TEST_QML_PATH=${CMAKE_BINARY_DIR}/qml")
    add_test(NAME backupfile COMMAND tst_backupfile)
    set_tests_properties(backupfile PROPERTIES
        ENVIRONMENT "KOPYPAST_TEST_QML_PATH=${CMAKE_BINARY_DIR}/qml")
endif()
