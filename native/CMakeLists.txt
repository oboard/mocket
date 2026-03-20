cmake_minimum_required(VERSION 3.5.0)
set(CMAKE_EXPORT_COMPILE_COMMANDS on)
project(native.mbt VERSION 0.1.0 LANGUAGES C)

set(MOON_HOME $ENV{MOON_HOME})

include_directories(${MOON_HOME}/include)

add_library(${PROJECT_NAME} STATIC ./src/ptr.c)