if(CMAKE_Fortran_COMPILER_ID STREQUAL Intel)
  if(WIN32)
    add_compile_options(/arch:native)
    string(APPEND CMAKE_Fortran_FLAGS " /warn:declarations /heap-arrays")
  else()
    add_compile_options(-march=native)
    string(APPEND CMAKE_Fortran_FLAGS " -warn declarations")
    string(APPEND CMAKE_Fortran_FLAGS_DEBUG " -check all -fpe0 -warn -traceback -debug extended")
  endif()
elseif(CMAKE_Fortran_COMPILER_ID STREQUAL GNU)
  if(CMAKE_Fortran_COMPILER_VERSION VERSION_GREATER_EQUAL 8)
    string(APPEND CMAKE_Fortran_FLAGS " -std=f2018")
  endif()

  string(APPEND CMAKE_Fortran_FLAGS " -fimplicit-none -Werror=array-bounds")
  string(APPEND CMAKE_Fortran_FLAGS_DEBUG " -ffpe-trap=zero,overflow,underflow")
  # mtune=native for better cross-platform
  add_compile_options(-mtune=native -Wall -Wextra)
endif()

if(PROJECT_SOURCE_DIR STREQUAL CMAKE_SOURCE_DIR)
  include(CheckIPOSupported)
  check_ipo_supported(RESULT lto_supported)
  if(lto_supported)
    set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)
  endif()
endif()

include(CheckFortranSourceCompiles)
check_fortran_source_compiles("call random_init(.false., .false.); end" f18random SRC_EXT f90)
