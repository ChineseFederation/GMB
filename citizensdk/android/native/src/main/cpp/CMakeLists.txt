cmake_minimum_required(VERSION 3.22.1)
project(citizensdk_jni LANGUAGES CXX)

if(NOT ANDROID_ABI STREQUAL "arm64-v8a")
  message(FATAL_ERROR "CitizenSDK Android 1.0.0 supports only arm64-v8a")
endif()
if(NOT DEFINED CITIZENSDK_CORE_DIR)
  message(FATAL_ERROR "CITIZENSDK_CORE_DIR is required")
endif()
set(CITIZENSDK_CORE_LIBRARY "${CITIZENSDK_CORE_DIR}/libcitizensdk.so")
if(NOT EXISTS "${CITIZENSDK_CORE_LIBRARY}")
  message(FATAL_ERROR "The staged libcitizensdk.so is missing")
endif()

add_library(citizensdk_core SHARED IMPORTED GLOBAL)
set_target_properties(citizensdk_core PROPERTIES
  IMPORTED_LOCATION "${CITIZENSDK_CORE_LIBRARY}"
)

add_library(citizensdk_jni SHARED
  citizensdk_host_bridge.cpp
  citizensdk_jni.cpp
)
target_compile_features(citizensdk_jni PRIVATE cxx_std_17)
target_compile_options(citizensdk_jni PRIVATE
  -Wall -Wextra -Werror -fvisibility=hidden -fvisibility-inlines-hidden
)
target_include_directories(citizensdk_jni PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../include"
)
target_link_libraries(citizensdk_jni PRIVATE citizensdk_core android log)

set(CITIZENSDK_JNI_VERSION_SCRIPT
    "${CMAKE_CURRENT_BINARY_DIR}/citizensdk-jni.exports.map")
file(GENERATE OUTPUT "${CITIZENSDK_JNI_VERSION_SCRIPT}" CONTENT
"CITIZENSDK_JNI_1.0 {
  global:
    JNI_OnLoad;
  local:
    *;
};
")
target_link_options(citizensdk_jni PRIVATE
  "-Wl,--version-script=${CITIZENSDK_JNI_VERSION_SCRIPT}"
  "-Wl,--exclude-libs,ALL"
  "-Wl,--no-undefined"
)

# Only the versioned JNI registration/lifecycle symbol is visible. The 70
# citizensdk_* exports remain owned solely by the imported Core library.
set_target_properties(citizensdk_jni PROPERTIES
  CXX_VISIBILITY_PRESET hidden
  VISIBILITY_INLINES_HIDDEN YES
)
