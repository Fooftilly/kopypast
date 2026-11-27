# SPDX-License-Identifier: GPL-3.0-or-later
cmake_minimum_required(VERSION 3.21)
project(KopypastPersistenceBenchmark LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
find_package(Qt6 REQUIRED COMPONENTS Core)
find_package(KF6Config REQUIRED)
add_executable(persistence persistence.cpp)
target_link_libraries(persistence PRIVATE Qt6::Core KF6::ConfigCore)
