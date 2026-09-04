#ifndef CITIZENSDK_WINDOWS_FLUTTER_ENVIRONMENT_HPP
#define CITIZENSDK_WINDOWS_FLUTTER_ENVIRONMENT_HPP

#include <windows.h>

#include <filesystem>
#include <memory>
#include <string>

#include "citizen_sdk/citizen_sdk_config.hpp"

namespace citizen_sdk::flutter {

// 原生装配输入，不是 channel 参数。应用身份只来自已批准的编译声明。
struct NativeEnvironmentInputs final {
  std::filesystem::path executable;
  std::filesystem::path user_data;
  std::string application_id;
};

struct OpenEnvironment final {
  Config config;
  // 仅保持 HWND 销毁观察者，不延长操作系统窗口寿命；Host 再次验证并接管观察。
  std::shared_ptr<void> ui_parent_lease;
};

class FlutterEnvironment final {
 public:
  explicit FlutterEnvironment(HWND view);
  ~FlutterEnvironment();
  FlutterEnvironment(const FlutterEnvironment &) = delete;
  FlutterEnvironment &operator=(const FlutterEnvironment &) = delete;

  OpenEnvironment open() const;
  // 私有原生夹具入口，复用同一窗口/路径检查；正式注册只调用无参数 open()。
  OpenEnvironment open(const NativeEnvironmentInputs &inputs) const;
  void detach() noexcept;
  static Config resolve(const NativeEnvironmentInputs &inputs);

 private:
  struct State;
  std::shared_ptr<State> state_;
};

}  // namespace citizen_sdk::flutter
#endif
