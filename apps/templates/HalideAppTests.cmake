# This file contains several pairs of helper functions for constructing very
# simple app project builds for generators and tests on various platforms.
#
# These functions are used in two steps, first an app target is created with
# halide_add_*_app and then Halide generators are associated with it using
# halide_add_*_generator_to_app (* may be ios, osx, etc.)
#
# All of the pairs of functions have the same interface:
#
# halide_add_*_app(TARGET <target>
#                  TEST_SOURCES <file> ...
#                  TEST_FUNCTIONS <name> ...
#                  TEST_RESOURCES <file> ...
#                  )
#   TARGET is the name of the test app target
#   TEST_SOURCES list the source files of the Halide generator tests. Other
#   source files containing the app itself will be automatically added to the
#   target.
#   TEST_FUNCTIONS list of C symbol names of "bool name(void)" functions for the
#   test to call. These will be added to the export list for the app.
#   TEST_RESOURCES list of files to include in the app Resources bundle
#
# halide_add_*_generator_to_app(TARGET <target>
#                               GENERATOR_TARGET <gen_target>
#                               GENERATOR_NAME <name>
#                               GENERATED_FUNCTION <name>
#                               GENERATOR_SOURCES <file> ...
#                               GENERATOR_ARGS <arg> ...
#                               )
#   TARGET is the name of the test app target (same as above)
#   GENERATOR_TARGET is the name of the generator executable target. The
#   generator executable is run during build.
#   GENERATOR_NAME is the C++ class name of the Halide::Generator derived object
#   GENERATED_FUNCTION is the name of the C function to be generated by Halide
#   GENERATOR_SOURCES are the source files compiled into the generator
#   executable
#   GENERATOR_ARGS are extra arguments passed to the generator executable during
#   build for example, "-e html target=host-opengl"

include(CMakeParseArguments)

include("${CMAKE_CURRENT_SOURCE_DIR}/../../../HalideGenerator.cmake")

# TODO: Need a more automatic way to refer to the halide library and header
set(HALIDE_LIB_PATH "" CACHE PATH "Full path of the file libHalide.a")
set(HALIDE_INCLUDE_PATH "" CACHE PATH "Path to the directory containing Halide.h")

### See the documentation for this function at the top of this file
function(halide_add_osx_app)

  # Parse arguments
  set(options )
  set(oneValueArgs TARGET)
  set(multiValueArgs TEST_SOURCES TEST_FUNCTIONS TEST_RESOURCES)
  cmake_parse_arguments(args "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN} )

  # Set the string for the bundle identifier in ccmake. The value passed here will
  # work for testing, change "com.yourcompany." if desired.
  set(HALIDE_BUNDLE_IDENTIFIER "com.yourcompany.\${PRODUCT_NAME:rfc1034identifier}" CACHE STRING "Set the build identifier for your company")

  # To add files to a Copy to Bundle Resources build phase, the files must be
  # passed to add_executable and to the RESOURCE property in set_target_properties
  set(resources
    index.html
    ${args_TEST_RESOURCES}
    )

  add_executable(${args_TARGET} MACOSX_BUNDLE
    ../SimpleAppAPI.h
    main.m
    AppDelegate.h
    AppDelegate.mm
    AppProtocol.h
    AppProtocol.mm
    ${args_TEST_SOURCES}
    ${resources}
    )

  # Determine an output directory
  file(TO_NATIVE_PATH "${CMAKE_CURRENT_BINARY_DIR}/scratch_${args_TARGET}/" out_dir)
  file(MAKE_DIRECTORY "${out_dir}")

  # Generate a header file declaring the test symbols
  foreach(test_function ${args_TEST_FUNCTIONS})
    set(test_symbols_declare "${test_symbols_declare} extern \"C\" int ${test_function}(void); ")
    set(test_symbols_table "${test_symbols_table} ${test_function}, ")
    set(test_names_table "${test_names_table} \"${test_function}\", ")
  endforeach(test_function)
  configure_file(test_symbols.h.template ${out_dir}/test_symbols.h)

  # Other frameworks passed on the link line
  set(frameworks "-framework CoreGraphics -framework Foundation -framework Cocoa -framework WebKit -framework OpenGL -framework AGL")

  set_target_properties(${args_TARGET} PROPERTIES
    MACOSX_BUNDLE_EXECUTABLE_NAME "\${EXECUTABLE_NAME}"
    MACOSX_BUNDLE_BUNDLE_NAME "\${PRODUCT_NAME}"
    MACOSX_BUNDLE_GUI_IDENTIFIER "${HALIDE_BUNDLE_IDENTIFIER}"
    MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in
    RESOURCE "${resources}"

    # The XCODE_ATTTRIBUTE_* variable feature sets an Xcode build setting based on
    # the suffix of the variable name. Here we set some default values of OS X app
    # development
    XCODE_ATTRIBUTE_DEBUG_INFORMATION_FORMAT "dwarf-with-dsym"
    XCODE_ATTRIBUTE_INFOPLIST_PREPROCESS YES
    XCODE_ATTRIBUTE_VALID_ARCHS "i386 x86_64"
    XCODE_ATTRIBUTE_SUPPORTED_PLATFORMS "macosx"
    XCODE_ATTRIBUTE_CLANG_CXX_LANGUAGE_STANDARD c++0x
    XCODE_ATTRIBUTE_GCC_ENABLE_CPP_RTTI NO

    # Must use DWARF-only due to https://github.com/halide/Halide/issues/626
    XCODE_ATTRIBUTE_DEBUG_INFORMATION_FORMAT dwarf

    LINK_FLAGS "${frameworks}"
    )

  target_include_directories(${args_TARGET} PUBLIC
    ${HALIDE_INCLUDE_PATH}
    ${out_dir}
    "${CMAKE_CURRENT_SOURCE_DIR}/.."
    "${CMAKE_CURRENT_SOURCE_DIR}/../../support"
    )

endfunction(halide_add_osx_app)

### See the documentation for this function at the top of this file
function(halide_add_osx_generator_to_app)

  # Parse arguments
  set(options )
  set(oneValueArgs TARGET GENERATOR_TARGET GENERATOR_NAME GENERATED_FUNCTION)
  set(multiValueArgs GENERATOR_SOURCES GENERATOR_ARGS)
  cmake_parse_arguments(args "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN} )

  # Add a Halide Generator to the test app target
  if(NOT TARGET ${args_GENERATOR_TARGET})
    add_executable(${args_GENERATOR_TARGET}
      ${args_GENERATOR_SOURCES}
      generator_main.cpp
      )

    target_link_libraries(${args_GENERATOR_TARGET}
      ${HALIDE_LIB_PATH} z
      )

    target_include_directories(${args_GENERATOR_TARGET} PUBLIC
      ${HALIDE_INCLUDE_PATH}
      )

    set_target_properties(${args_GENERATOR_TARGET} PROPERTIES
      # Halide::Generator requires C++11
      XCODE_ATTRIBUTE_CLANG_CXX_LANGUAGE_STANDARD c++0x
      XCODE_ATTRIBUTE_GCC_ENABLE_CPP_RTTI NO
      )
  endif()

  # Add a build step to call the generator
  halide_add_generator_dependency(
    TARGET ${args_TARGET}
    GENERATOR_TARGET ${args_GENERATOR_TARGET}
    GENERATOR_NAME ${args_GENERATOR_NAME}
    GENERATED_FUNCTION ${args_GENERATED_FUNCTION}
    GENERATOR_ARGS ${args_GENERATOR_ARGS}
    )

endfunction(halide_add_osx_generator_to_app)

### See the documentation for this function at the top of this file
function(halide_add_ios_app)

  # Parse arguments
  set(options )
  set(oneValueArgs TARGET)
  set(multiValueArgs TEST_SOURCES TEST_FUNCTIONS TEST_RESOURCES)
  cmake_parse_arguments(args "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN} )

  # Set the string for the bundle identifier in ccmake. The value passed here will
  # work for testing, change "com.yourcompany." if desired.
  set(HALIDE_IOS_BUNDLE_IDENTIFIER "com.yourcompany.\${PRODUCT_NAME:rfc1034identifier}" CACHE STRING "Set the build identifier for your company")

  # Set the developer identiy in ccmake if the default for your build machine is
  # not sufficient.
  set(HALIDE_IOS_CODE_SIGNING_IDENTITY "iPhone Developer" CACHE STRING "Set the developer identity")

  set(CMAKE_OSX_SYSROOT "iphoneos")
  set(CMAKE_OSX_ARCHITECTURES "$(ARCHS_STANDARD)")
  set(CMAKE_XCODE_EFFECTIVE_PLATFORMS "-iphoneos;-iphonesimulator")

  # To add files to a Copy to Bundle Resources build phase, the files must be
  # passed to add_executable and to the RESOURCE property in set_target_properties
  set(RESOURCES
    index.html
    ${args_TEST_RESOURCES}
    )

  add_executable(${args_TARGET} MACOSX_BUNDLE
    ../SimpleAppAPI.h
    AppDelegate.h
    AppDelegate.m
    AppProtocol.h
    AppProtocol.mm
    ${args_TEST_SOURCES}
    main.m
    ViewController.h
    ViewController.mm
    ${RESOURCES}
    )

  # Determine an output directory
  file(TO_NATIVE_PATH "${CMAKE_CURRENT_BINARY_DIR}/scratch_${args_TARGET}/" out_dir)
  file(MAKE_DIRECTORY "${out_dir}")

  # Generate a header file declaring the test symbols
  foreach(test_function ${args_TEST_FUNCTIONS})
    set(test_symbols_declare "${test_symbols_declare} extern \"C\" int ${test_function}(void); ")
    set(test_symbols_table "${test_symbols_table} ${test_function}, ")
    set(test_names_table "${test_names_table} \"${test_function}\", ")
  endforeach(test_function)
  configure_file(test_symbols.h.template ${out_dir}/test_symbols.h)

  # Other frameworks passed on the link line
  set(frameworks "-framework CoreGraphics -framework Foundation -framework UIKit -framework OpenGLES")

  set_target_properties(${args_TARGET} PROPERTIES
    MACOSX_BUNDLE_EXECUTABLE_NAME "\${EXECUTABLE_NAME}"
    MACOSX_BUNDLE_BUNDLE_NAME "\${PRODUCT_NAME}"
    MACOSX_BUNDLE_GUI_IDENTIFIER "${HALIDE_IOS_BUNDLE_IDENTIFIER}"
    MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in
    RESOURCE ${RESOURCES}

    # The XCODE_ATTTRIBUTE_* variable feature sets an Xcode build setting based on
    # the suffix of the variable name. Here we set some default values of iOS app
    # development
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "${HALIDE_IOS_CODE_SIGNING_IDENTITY}"
    XCODE_ATTRIBUTE_DEBUG_INFORMATION_FORMAT "dwarf"
    XCODE_ATTRIBUTE_INFOPLIST_PREPROCESS YES
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET 8.0
    XCODE_ATTRIBUTE_VALID_ARCHS "arm64 armv7 armv7s x86_64"
    XCODE_ATTRIBUTE_SUPPORTED_PLATFORMS "iphonesimulator iphoneos"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
    XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH YES

    LINK_FLAGS "${frameworks}"
    )

  target_include_directories(${args_TARGET} PUBLIC
    ${HALIDE_INCLUDE_PATH}
    ${out_dir}
    "${CMAKE_CURRENT_SOURCE_DIR}/.."
    "${CMAKE_CURRENT_SOURCE_DIR}/../../support"
    )

endfunction(halide_add_ios_app)

### See the documentation for this function at the top of this file
function(halide_add_ios_generator_to_app)

  # Parse arguments
  set(options )
  set(oneValueArgs TARGET GENERATOR_TARGET GENERATOR_NAME GENERATED_FUNCTION)
  set(multiValueArgs GENERATOR_SOURCES GENERATOR_ARGS)
  cmake_parse_arguments(args "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN} )

  # Add a Halide Generator to the test app project.
  if(NOT TARGET ${args_GENERATOR_TARGET})
    add_executable(${args_GENERATOR_TARGET}
      ${args_GENERATOR_SOURCES}
      generator_main.cpp
      )

    target_link_libraries(${args_GENERATOR_TARGET}
      ${HALIDE_LIB_PATH} z
      )

    target_include_directories(${args_GENERATOR_TARGET} PUBLIC
      ${HALIDE_INCLUDE_PATH}
      )

    # Use Xcode attributes to setup this target as a host command line tool even
    # though the other targets in the project are iOS apps.
    set_target_properties(${args_GENERATOR_TARGET} PROPERTIES
      XCODE_ATTRIBUTE_SDKROOT "macosx"
      XCODE_ATTRIBUTE_DEBUG_INFORMATION_FORMAT "dwarf"
      XCODE_ATTRIBUTE_INFOPLIST_PREPROCESS YES
      # The generator executable must be built for the same architectures as the
      # version of libHalide.a it is linked to.
      XCODE_ATTRIBUTE_VALID_ARCHS "x86_64"
      XCODE_ATTRIBUTE_SUPPORTED_PLATFORMS "macosx"
      XCODE_ATTRIBUTE_CLANG_CXX_LANGUAGE_STANDARD c++0x
      XCODE_ATTRIBUTE_GCC_ENABLE_CPP_RTTI NO
      )

  endif()

  # Add the generated function name to the export list for the app
  get_target_property(existing_link_flags ${args_TARGET} LINK_FLAGS)
  set_target_properties(${args_TARGET} PROPERTIES
    LINK_FLAGS "${existing_link_flags} -Xlinker -exported_symbol -Xlinker _${args_GENERATED_FUNCTION}"
    )

  halide_add_generator_dependency(
    TARGET ${args_TARGET}
    GENERATOR_TARGET ${args_GENERATOR_TARGET}
    GENERATOR_NAME ${args_GENERATOR_NAME}
    GENERATED_FUNCTION ${args_GENERATED_FUNCTION}
    GENERATOR_ARGS ${args_GENERATOR_ARGS}
    )

endfunction(halide_add_ios_generator_to_app)














