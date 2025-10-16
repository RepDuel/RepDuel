# Local build customizations for the Linux runner and plugins.
# Keep ../linux/CMakeLists.txt aligned with the stock Flutter template and only
# apply project-specific tweaks here.

if(TARGET ${BINARY_NAME})
  target_compile_options(${BINARY_NAME} PRIVATE -Wall -Werror)
  target_compile_options(${BINARY_NAME} PRIVATE "$<$<NOT:$<CONFIG:Debug>>:-O2>")
endif()

foreach(plugin ${FLUTTER_PLUGIN_LIST})
  if(TARGET ${plugin}_plugin)
    target_compile_options(${plugin}_plugin PRIVATE -Wall)
    target_compile_options(${plugin}_plugin PRIVATE "$<$<NOT:$<CONFIG:Debug>>:-O2>")
  endif()
endforeach()

foreach(ffi_plugin ${FLUTTER_FFI_PLUGIN_LIST})
  if(TARGET ${ffi_plugin}_plugin)
    target_compile_options(${ffi_plugin}_plugin PRIVATE -Wall)
    target_compile_options(${ffi_plugin}_plugin PRIVATE "$<$<NOT:$<CONFIG:Debug>>:-O2>")
  endif()
endforeach()
