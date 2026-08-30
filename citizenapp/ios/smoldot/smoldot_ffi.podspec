#
# CitizenApp 热端原生静态库(smoldot 轻节点 + citizen-signer sr25519 签名 聊天)。
#
# 由 scripts/build-smoldot-native.sh ios 交叉编译产出 libsmoldot.a,并从产物实抽
# exported_symbols.txt;本 podspec 逐符号生成 -Wl,-u,<符号>,清单绝不手维护——
# 手写必漂移,漏一个符号 = Release 被 -dead_strip 静默剔除(Debug 正常、Release 崩)。
#
# 为什么用静态库而不是 dylib:裸 .dylib 需要嵌入 App 并单独代码签名,且 App Store
# 要求动态库必须包在 .framework 里。use_frameworks! 默认生成动态 Framework，
# 因此本 Pod 必须显式声明 static_framework，让 Rust 归档只在 Runner 最终链接一次。
# `-force_load` 保证 `#[no_mangle]` 的 FFI 符号不被链接器当未引用剔除,
# Dart 侧因此可用 DynamicLibrary.process() 直接取到,与冷端(ios/signer)同一套做法。
#
# 符号检查要查对文件(查错了会误判成"没链接进去"):
#   Debug   → Runner.app/Runner.debug.dylib (Runner 只是 ~70KB 启动壳,
#                                            新版 Xcode 的 debug 构建把代码放
#                                            进 debug dylib)
#   Release → Runner.app/Runner
#   命令:llvm-nm -g <binary> | grep -cE 'smoldot_|citizen_'   应等于清单行数
#
require 'pathname'

native_dir = ENV['PROGRAM_CONSOLE_NATIVE_IOS_DIR'] || File.dirname(__FILE__)
library_path = File.expand_path('libsmoldot.a', native_dir)
symbols_path = File.expand_path('exported_symbols.txt', native_dir)
# CocoaPods 1.17 禁止 vendored_libraries 使用绝对文件模式。中央产物仍留在
# ProgramConsole 工作目录，只在 podspec 解析时转换为相对本文件的路径，不复制回源码树。
library_pattern = Pathname.new(library_path).relative_path_from(Pathname.new(__dir__)).to_s
unless File.exist?(symbols_path)
  raise "缺少 #{symbols_path},先运行 scripts/build-smoldot-native.sh ios 生成静态库与符号清单"
end
ffi_symbols = File.readlines(symbols_path).map(&:strip).reject(&:empty?)
raise "exported_symbols.txt 为空,静态库构建异常" if ffi_symbols.empty?
ffi_symbol_pattern = /\A_(?:smoldot_|citizen_sr25519_|account_crypto_|chat_sdk_)[A-Za-z0-9_]*\z/
invalid_symbols = ffi_symbols.reject { |symbol| ffi_symbol_pattern.match?(symbol) }
unless invalid_symbols.empty?
  raise "exported_symbols.txt 含非公开 FFI 符号: #{invalid_symbols.first}"
end
link_flags = "$(inherited) -Wl,-force_load,#{library_path} " +
             ffi_symbols.map { |sym| "-Wl,-u,#{sym}" }.join(' ')

Pod::Spec.new do |s|
  s.name             = 'smoldot_ffi'
  s.version          = '1.0.0'
  s.summary          = 'CitizenApp 热端原生静态库(smoldot + sr25519)'
  s.description      = <<-DESC
CitizenApp 热端原生库:smoldot 轻节点、sr25519 原生签名(与 CitizenWallet 冷端
共用 shared/citizen-signer 同一份源码)、OpenMLS 端到端加密聊天。
                       DESC
  s.homepage         = 'https://github.com/ChineseFederation/GMB'
  s.license          = { :type => 'Apache-2.0' }
  s.author           = { 'voyager_rhett' => 'chinanation@icloud.com' }
  # Podfile 的 :path 决定本机实际来源；这里仅提供 CocoaPods 要求的合法来源元数据。
  s.source           = { :git => 'https://github.com/ChineseFederation/GMB.git' }
  s.platform         = :ios, '16.0'
  s.static_framework = true

  # CocoaPods 要求至少有一个源文件;用一个空的占位 .m,真正的实现全在 .a 里。
  s.source_files     = 'placeholder.m'
  s.vendored_libraries = library_pattern

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 x86_64',
  }
  # 静态 Pod 目标不执行 Rust 最终链接；以下参数只进入 Runner，避免 Pods 动态
  # Framework 提前解析 compiler_builtins，同时保证最终 Mach-O 保留全部 FFI。
  # 两件事缺一不可,否则运行时 DynamicLibrary.process().lookup 找不到符号:
  # 1) -force_load:整库加载。App 侧没有任何 ObjC/Swift 代码引用这些 Rust 符号,
  #    普通链接会把整个 .a 当无用直接跳过。
  # 2) -u(force undefined):把 FFI 符号声明为"必需"。**Release 开启 -dead_strip**,
  #    即使 force_load 进来了,没被引用的符号仍会被剔除——表现为 Debug 正常、
  #    Release 静默失效。-u 让链接器必须保留它们。
  # 必须写成 `-Wl,-u,<符号>` 而不是 `-u <符号>`:CocoaPods 会把重复的 `-u` 前缀
  # 去重合并成 `-u a b c d`,后面的被链接器当成文件名报 No such file or directory。
  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => link_flags,
  }
end
