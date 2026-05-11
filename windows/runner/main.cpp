#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Size size(1200, 740);
  RECT work_area = {0, 0, ::GetSystemMetrics(SM_CXSCREEN),
                    ::GetSystemMetrics(SM_CYSCREEN)};
  ::SystemParametersInfo(SPI_GETWORKAREA, 0, &work_area, 0);
  const int work_width = work_area.right - work_area.left;
  const int work_height = work_area.bottom - work_area.top;
  const int origin_x = work_area.left +
      (work_width > static_cast<int>(size.width)
           ? (work_width - static_cast<int>(size.width)) / 2
           : 0);
  const int origin_y = work_area.top +
      (work_height > static_cast<int>(size.height)
           ? (work_height - static_cast<int>(size.height)) / 2
           : 0);
  Win32Window::Point origin(static_cast<unsigned int>(origin_x),
                            static_cast<unsigned int>(origin_y));
  if (!window.Create(L"PassStore", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
