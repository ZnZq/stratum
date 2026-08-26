#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>

#include "resource.h"

namespace {

/// Window attribute that enables dark mode window decorations.
///
/// Redefined in case the developer's machine has a Windows SDK older than
/// version 10.0.22000.0.
/// See: https://docs.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

/// Registry key for app theme preference.
///
/// A value of 0 indicates apps should use dark mode. A non-zero or missing
/// value indicates apps should use light mode.
constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
  L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] = L"AppsUseLightTheme";

// The number of Win32Window objects that currently exist.
static int g_active_window_count = 0;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

// Scale helper to convert logical scaler values to physical using passed in
// scale factor
// Below this a phone layout has nothing left to lay out. Stated as a width
// because that is the dimension a portrait layout runs out of first.
constexpr int kMinClientWidth = 320;

// Where the last window position is kept. The registry avoids having to pick a
// writable directory and behaves the same whether the game is installed or run
// straight out of the build folder.
constexpr wchar_t kSettingsKey[] = L"Software\\Stratum\\Window";

bool ReadSetting(const wchar_t* name, LONG* value) {
  DWORD data = 0;
  DWORD size = sizeof(data);
  const LSTATUS status =
      RegGetValueW(HKEY_CURRENT_USER, kSettingsKey, name, RRF_RT_REG_DWORD,
                   nullptr, &data, &size);
  if (status != ERROR_SUCCESS) {
    return false;
  }
  *value = static_cast<LONG>(data);
  return true;
}

void WriteSetting(HKEY key, const wchar_t* name, LONG value) {
  const DWORD data = static_cast<DWORD>(value);
  RegSetValueExW(key, name, 0, REG_DWORD,
                 reinterpret_cast<const BYTE*>(&data), sizeof(data));
}

int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

// Dynamically loads the |EnableNonClientDpiScaling| from the User32 module.
// This API is only needed for PerMonitor V1 awareness mode.
void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }
  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }
  FreeLibrary(user32_module);
}

}  // namespace

// Manages the Win32Window's window class registration.
class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  // Returns the singleton registrar instance.
  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  // Returns the name of the window class, registering the class if it hasn't
  // previously been registered.
  const wchar_t* GetWindowClass();

  // Unregisters the window class. Should only be called if there are no
  // instances of the window.
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;

  static WindowClassRegistrar* instance_;

  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    window_class.hbrBackground = 0;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

SIZE Win32Window::FrameSize(UINT dpi) {
  RECT frame = {0, 0, 0, 0};
  AdjustWindowRectExForDpi(&frame, WS_OVERLAPPEDWINDOW, FALSE, 0, dpi);
  return {frame.right - frame.left, frame.bottom - frame.top};
}

Win32Window::Size Win32Window::PreferredClientSize(double height_share) {
  HMONITOR monitor = MonitorFromPoint({0, 0}, MONITOR_DEFAULTTOPRIMARY);
  MONITORINFO info = {};
  info.cbSize = sizeof(info);
  if (!GetMonitorInfo(monitor, &info)) {
    return Size(1280, 720);
  }

  const UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  const double scale_factor = dpi / 96.0;
  const LONG work_height = info.rcWork.bottom - info.rcWork.top;
  const LONG work_width = info.rcWork.right - info.rcWork.left;
  const SIZE frame = FrameSize(dpi);

  // The share applies to the whole window, frame included, since that is what
  // the player sees taking up the screen.
  double height = work_height * height_share - frame.cy;
  double width = height * kAspectWidth / kAspectHeight;

  // A wide window on a tall monitor can still overflow sideways.
  const double max_width = work_width - frame.cx;
  if (width > max_width) {
    width = max_width;
    height = width * kAspectHeight / kAspectWidth;
  }

  return Size(static_cast<unsigned int>(width / scale_factor),
              static_cast<unsigned int>(height / scale_factor));
}

Win32Window::Point Win32Window::CentredOrigin(const Size& size) {
  HMONITOR monitor = MonitorFromPoint({0, 0}, MONITOR_DEFAULTTOPRIMARY);
  MONITORINFO info = {};
  info.cbSize = sizeof(info);
  if (!GetMonitorInfo(monitor, &info)) {
    return Point(40, 40);
  }

  const UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  const double scale_factor = dpi / 96.0;
  const SIZE frame = FrameSize(dpi);
  const LONG width = Scale(size.width, scale_factor) + frame.cx;
  const LONG height = Scale(size.height, scale_factor) + frame.cy;

  const LONG left =
      info.rcWork.left + (info.rcWork.right - info.rcWork.left - width) / 2;
  const LONG top =
      info.rcWork.top + (info.rcWork.bottom - info.rcWork.top - height) / 2;

  // Create scales the origin too, so hand it back in logical pixels.
  return Point(static_cast<unsigned int>(left < 0 ? 0 : left / scale_factor),
               static_cast<unsigned int>(top < 0 ? 0 : top / scale_factor));
}

bool Win32Window::RestorePlacement(Point* origin,
                                   Size* size,
                                   bool* maximized) {
  LONG left = 0;
  LONG top = 0;
  LONG width = 0;
  LONG height = 0;
  LONG was_maximized = 0;
  if (!ReadSetting(L"Left", &left) || !ReadSetting(L"Top", &top) ||
      !ReadSetting(L"Width", &width) || !ReadSetting(L"Height", &height)) {
    return false;
  }
  ReadSetting(L"Maximized", &was_maximized);

  RECT stored = {left, top, left + width, top + height};

  // A monitor that is gone -- an unplugged second screen -- would strand the
  // window off the desktop where it cannot be dragged back.
  if (MonitorFromRect(&stored, MONITOR_DEFAULTTONULL) == nullptr) {
    return false;
  }

  const UINT dpi = FlutterDesktopGetDpiForMonitor(
      MonitorFromRect(&stored, MONITOR_DEFAULTTONEAREST));
  const double scale_factor = dpi / 96.0;
  const SIZE frame = FrameSize(dpi);

  LONG client_width = width - frame.cx;
  if (client_width < Scale(kMinClientWidth, scale_factor)) {
    return false;
  }
  // The stored height is re-derived rather than trusted: a value written by an
  // older build, or by hand, must not be able to break the locked aspect.
  const LONG client_height = client_width * kAspectHeight / kAspectWidth;

  *origin = Point(static_cast<unsigned int>(left < 0 ? 0 : left / scale_factor),
                  static_cast<unsigned int>(top < 0 ? 0 : top / scale_factor));
  *size = Size(static_cast<unsigned int>(client_width / scale_factor),
               static_cast<unsigned int>(client_height / scale_factor));
  *maximized = was_maximized != 0;
  return true;
}

void Win32Window::SetShowMaximized(bool maximized) {
  show_maximized_ = maximized;
}

void Win32Window::SavePlacement() {
  if (window_handle_ == nullptr) {
    return;
  }

  WINDOWPLACEMENT placement = {};
  placement.length = sizeof(placement);
  if (!GetWindowPlacement(window_handle_, &placement)) {
    return;
  }

  HKEY key = nullptr;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, kSettingsKey, 0, nullptr, 0, KEY_WRITE,
                      nullptr, &key, nullptr) != ERROR_SUCCESS) {
    return;
  }

  // rcNormalPosition is the restored rect even while the window is maximized,
  // so un-maximizing after a restart lands where the player last had it.
  const RECT& rect = placement.rcNormalPosition;
  WriteSetting(key, L"Left", rect.left);
  WriteSetting(key, L"Top", rect.top);
  WriteSetting(key, L"Width", rect.right - rect.left);
  WriteSetting(key, L"Height", rect.bottom - rect.top);
  WriteSetting(key, L"Maximized",
               placement.showCmd == SW_SHOWMAXIMIZED ? 1 : 0);
  RegCloseKey(key);
}

bool Win32Window::Create(const std::wstring& title,
                         const Point& origin,
                         const Size& size) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  const POINT target_point = {static_cast<LONG>(origin.x),
                              static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = dpi / 96.0;

  // `size` describes the area Flutter draws into, not the outer window.
  // CreateWindow takes the outer rect, so without this the title bar and
  // borders would eat into the client area and the locked aspect would be off
  // by the height of the caption from the very first frame.
  const SIZE frame = FrameSize(dpi);
  const int window_width = Scale(size.width, scale_factor) + frame.cx;
  const int window_height = Scale(size.height, scale_factor) + frame.cy;

  HWND window = CreateWindow(
      window_class, title.c_str(), WS_OVERLAPPEDWINDOW,
      Scale(origin.x, scale_factor), Scale(origin.y, scale_factor),
      window_width, window_height,
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  UpdateTheme(window);

  return OnCreate();
}

bool Win32Window::Show() {
  return ShowWindow(window_handle_,
                    show_maximized_ ? SW_SHOWMAXIMIZED : SW_SHOWNORMAL);
}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT
Win32Window::MessageHandler(HWND hwnd,
                            UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_SIZING: {
      // Windows hands over the window rect it is about to apply; correcting it
      // here is what keeps the ratio locked through a drag rather than
      // snapping back afterwards.
      RECT* rect = reinterpret_cast<RECT*>(lparam);
      const SIZE frame = FrameSize(GetDpiForWindow(hwnd));

      LONG client_width = (rect->right - rect->left) - frame.cx;
      LONG client_height = (rect->bottom - rect->top) - frame.cy;

      // The edge under the cursor is the one the player is steering; the other
      // dimension follows it.
      const bool vertical_drag = wparam == WMSZ_TOP || wparam == WMSZ_BOTTOM;
      if (vertical_drag) {
        client_width = client_height * kAspectWidth / kAspectHeight;
      } else {
        client_height = client_width * kAspectHeight / kAspectWidth;
      }

      const LONG width = client_width + frame.cx;
      const LONG height = client_height + frame.cy;

      const bool anchored_right = wparam == WMSZ_LEFT ||
                                  wparam == WMSZ_TOPLEFT ||
                                  wparam == WMSZ_BOTTOMLEFT;
      const bool anchored_bottom = wparam == WMSZ_TOP ||
                                   wparam == WMSZ_TOPLEFT ||
                                   wparam == WMSZ_TOPRIGHT;

      if (anchored_right) {
        rect->left = rect->right - width;
      } else {
        rect->right = rect->left + width;
      }
      if (anchored_bottom) {
        rect->top = rect->bottom - height;
      } else {
        rect->bottom = rect->top + height;
      }
      return TRUE;
    }

    case WM_GETMINMAXINFO: {
      // Maximizing never sends WM_SIZING, so without this the one gesture a
      // player is most likely to try would be the one that breaks the ratio.
      auto* info = reinterpret_cast<MINMAXINFO*>(lparam);
      const UINT dpi = GetDpiForWindow(hwnd);
      const SIZE frame = FrameSize(dpi);

      MONITORINFO monitor = {};
      monitor.cbSize = sizeof(monitor);
      if (GetMonitorInfo(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST),
                         &monitor)) {
        const LONG work_width = monitor.rcWork.right - monitor.rcWork.left;
        const LONG work_height = monitor.rcWork.bottom - monitor.rcWork.top;

        LONG client_width = work_width - frame.cx;
        LONG client_height = client_width * kAspectHeight / kAspectWidth;
        if (client_height > work_height - frame.cy) {
          client_height = work_height - frame.cy;
          client_width = client_height * kAspectWidth / kAspectHeight;
        }

        info->ptMaxSize.x = client_width + frame.cx;
        info->ptMaxSize.y = client_height + frame.cy;
        info->ptMaxPosition.x =
            monitor.rcWork.left + (work_width - info->ptMaxSize.x) / 2;
        info->ptMaxPosition.y =
            monitor.rcWork.top + (work_height - info->ptMaxSize.y) / 2;
      }

      const LONG min_client_width = Scale(kMinClientWidth, dpi / 96.0);
      info->ptMinTrackSize.x = min_client_width + frame.cx;
      info->ptMinTrackSize.y =
          min_client_width * kAspectHeight / kAspectWidth + frame.cy;
      return 0;
    }

    case WM_CLOSE:
      SavePlacement();
      break;

    case WM_DESTROY:
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_DPICHANGED: {
      auto newRectSize = reinterpret_cast<RECT*>(lparam);
      LONG newWidth = newRectSize->right - newRectSize->left;
      LONG newHeight = newRectSize->bottom - newRectSize->top;

      SetWindowPos(hwnd, nullptr, newRectSize->left, newRectSize->top, newWidth,
                   newHeight, SWP_NOZORDER | SWP_NOACTIVATE);

      return 0;
    }
    case WM_SIZE: {
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        // Size and position the child window.
        MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      return 0;
    }

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;

    case WM_DWMCOLORIZATIONCOLORCHANGED:
      UpdateTheme(hwnd);
      return 0;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::Destroy() {
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  RECT frame = GetClientArea();

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, true);

  SetFocus(child_content_);
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() {
  // No-op; provided for subclasses.
  return true;
}

void Win32Window::OnDestroy() {
  // No-op; provided for subclasses.
}

void Win32Window::UpdateTheme(HWND const window) {
  DWORD light_mode;
  DWORD light_mode_size = sizeof(light_mode);
  LSTATUS result = RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                               kGetPreferredBrightnessRegValue,
                               RRF_RT_REG_DWORD, nullptr, &light_mode,
                               &light_mode_size);

  if (result == ERROR_SUCCESS) {
    BOOL enable_dark_mode = light_mode == 0;
    DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                          &enable_dark_mode, sizeof(enable_dark_mode));
  }
}
