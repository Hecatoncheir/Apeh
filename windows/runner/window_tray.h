#ifndef RUNNER_WINDOW_TRAY_H_
#define RUNNER_WINDOW_TRAY_H_

#include <windows.h>
#include <flutter/method_channel.h>

#include <optional>
#include <string>

class WindowTray {
 public:
  WindowTray(HWND window, flutter::BinaryMessenger* messenger);
  ~WindowTray();

  std::optional<LRESULT> HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);

 private:
  bool AddIcon();
  void RemoveIcon();
  void RestoreWindow();
  void ShowMenu(POINT point);

  HWND window_;
  const UINT taskbar_created_;
  bool enabled_ = false;
  bool hidden_ = false;
  std::wstring open_label_;
  std::wstring quit_label_;
  flutter::MethodChannel<flutter::EncodableValue> channel_;
};

#endif  // RUNNER_WINDOW_TRAY_H_
