# Local build customizations for the Windows runner and plugins.
# Keep ../windows/CMakeLists.txt aligned with the stock Flutter template and
# apply project-specific tweaks here.

function(_frontend_apply_windows_overrides TARGET)
  target_compile_options(${TARGET} PRIVATE /W4 /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_options(${TARGET} PRIVATE "$<$<NOT:$<CONFIG:Debug>>:/O2>")
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

if(TARGET ${BINARY_NAME})
  _frontend_apply_windows_overrides(${BINARY_NAME})
  target_compile_options(${BINARY_NAME} PRIVATE /WX)
endif()

foreach(plugin ${FLUTTER_PLUGIN_LIST})
  if(TARGET ${plugin}_plugin)
    _frontend_apply_windows_overrides(${plugin}_plugin)
  endif()
endforeach()

foreach(ffi_plugin ${FLUTTER_FFI_PLUGIN_LIST})
  if(TARGET ${ffi_plugin}_plugin)
    _frontend_apply_windows_overrides(${ffi_plugin}_plugin)
  endif()
endforeach()
