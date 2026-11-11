#include "window_tray.h"

#include <shellapi.h>
#include <windowsx.h>
#include <flutter/standard_method_codec.h>

#include "resource.h"

namespace {
constexpr UINT kTrayMessage = WM_APP + 1;
constexpr UINT kTrayIcon = 1;
constexpr UINT kOpen = 1;
constexpr UINT kQuit = 2;

std::wstring ReadLabel(const flutter::EncodableMap& args, const char* key) {
  const auto it = args.find(flutter::EncodableValue(key));
  if (it == args.end()) return {};
  const auto* text = std::get_if<std::string>(&it->second);
  if (!text || text->empty()) return {};
  const int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                       text->c_str(), -1, nullptr, 0);
  if (size == 0) return {};
  std::wstring label(size, L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text->c_str(), -1,
                      label.data(), size);
  label.pop_back();
  return label;
}

NOTIFYICONDATAW IconData(HWND window) {
  NOTIFYICONDATAW data{};
  data.cbSize = sizeof(data);
  data.hWnd = window;
  data.uID = kTrayIcon;
  return data;
}
}  // namespace

WindowTray::WindowTray(HWND window, flutter::BinaryMessenger* messenger)
    : window_(window),
      taskbar_created_(RegisterWindowMessageW(L"TaskbarCreated")),
      channel_(messenger, "apeh/windows_tray",
               &flutter::StandardMethodCodec::GetInstance()) {
  channel_.SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() != "configure") {
      result->NotImplemented();
      return;
    }
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!args) {
      result->Error("arguments");
      return;
    }
    const auto option = args->find(flutter::EncodableValue("enabled"));
    const auto* enabled =
        option == args->end() ? nullptr : std::get_if<bool>(&option->second);
    if (!enabled) {
      result->Error("arguments");
      return;
    }
    open_label_ = ReadLabel(*args, "open");
    quit_label_ = ReadLabel(*args, "quit");
    enabled_ = *enabled;
    if (!enabled_ && hidden_) RestoreWindow();
    result->Success();
  });
}

WindowTray::~WindowTray() {
  channel_.SetMethodCallHandler(nullptr);
  RemoveIcon();
}

bool WindowTray::AddIcon() {
  auto icon = IconData(window_);
  icon.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP | NIF_SHOWTIP;
  icon.uCallbackMessage = kTrayMessage;
  icon.hIcon = static_cast<HICON>(
      LoadImageW(GetModuleHandleW(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON),
                 IMAGE_ICON, 0, 0, LR_SHARED | LR_DEFAULTSIZE));
  if (!icon.hIcon) return false;
  wcscpy_s(icon.szTip, L"Apeh");
  if (!Shell_NotifyIconW(NIM_ADD, &icon)) return false;
  icon.uVersion = NOTIFYICON_VERSION_4;
  if (Shell_NotifyIconW(NIM_SETVERSION, &icon)) return true;
  RemoveIcon();
  return false;
}

void WindowTray::RemoveIcon() {
  auto icon = IconData(window_);
  Shell_NotifyIconW(NIM_DELETE, &icon);
}

void WindowTray::RestoreWindow() {
  RemoveIcon();
  hidden_ = false;
  ShowWindow(window_, IsIconic(window_) ? SW_RESTORE : SW_SHOW);
  SetForegroundWindow(window_);
}

void WindowTray::ShowMenu(POINT point) {
  const auto menu = CreatePopupMenu();
  if (!menu) return;
  AppendMenuW(menu, MF_STRING, kOpen, open_label_.c_str());
  AppendMenuW(menu, MF_STRING, kQuit, quit_label_.c_str());
  SetForegroundWindow(window_);
  const auto action = TrackPopupMenu(
      menu, TPM_RETURNCMD | TPM_RIGHTBUTTON | TPM_NONOTIFY,
      point.x, point.y, 0, window_, nullptr);
  DestroyMenu(menu);
  PostMessageW(window_, WM_NULL, 0, 0);
  if (action == kOpen) RestoreWindow();
  if (action == kQuit) {
    enabled_ = false;
    PostMessageW(window_, WM_CLOSE, 0, 0);
  }
  if (action == 0) {
    auto icon = IconData(window_);
    Shell_NotifyIconW(NIM_SETFOCUS, &icon);
  }
}

std::optional<LRESULT> WindowTray::HandleMessage(UINT message, WPARAM wparam,
                                                 LPARAM lparam) {
  if (message == kTrayMessage) {
    if (!hidden_) return 0;
    switch (LOWORD(lparam)) {
      case WM_LBUTTONUP:
      case NIN_SELECT:
      case NIN_KEYSELECT:
        RestoreWindow();
        break;
      case WM_CONTEXTMENU:
        ShowMenu({GET_X_LPARAM(wparam), GET_Y_LPARAM(wparam)});
        break;
    }
    return 0;
  }
  if (taskbar_created_ != 0 && message == taskbar_created_ && hidden_) {
    if (!AddIcon()) RestoreWindow();
    return 0;
  }
  const bool minimizing =
      message == WM_SYSCOMMAND && (wparam & 0xfff0) == SC_MINIMIZE;
  if (!enabled_ || (message != WM_CLOSE && !minimizing)) return std::nullopt;
  if (hidden_) return 0;
  // Fall back to the normal window action if Windows cannot add the icon.
  if (!AddIcon()) return std::nullopt;
  hidden_ = true;
  ShowWindow(window_, SW_HIDE);
  return 0;
}
