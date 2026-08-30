require 'pathname'

native_dir = ENV['PROGRAM_CONSOLE_NATIVE_IOS_DIR'] || File.dirname(__FILE__)
library_path = File.expand_path('libsmoldot.a', native_dir)
symbols_path = File.expand_path('exported_symbols.txt', native_dir)
library_pattern = Pathname.new(library_path).relative_path_from(Pathname.new(__dir__)).to_s

unless File.exist?(library_path)
  raise "缺少 #{library_path}，请先由编程控制台生成 CitizenSDK iOS 原生产物"
end
unless File.exist?(symbols_path)
  raise "缺少 #{symbols_path}，请先由编程控制台生成 CitizenSDK iOS 符号清单"
end
ffi_symbols = File.readlines(symbols_path).map(&:strip).reject(&:empty?)
raise 'exported_symbols.txt 为空，CitizenSDK 原生产物异常' if ffi_symbols.empty?

Pod::Spec.new do |s|
  s.name             = 'citizen_sdk'
  s.version          = '1.0.0'
  s.summary          = 'Citizenchain light client, wallet, signing and transaction SDK'
  s.description      = <<-DESC
CitizenSDK supplies the Citizenchain light client, rootless hot wallet,
sr25519 signing and on-chain transaction capabilities for Flutter products.
                       DESC
  s.homepage         = 'https://github.com/ChineseFederation/GMB'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Chinese Federation' => 'chinanation@icloud.com' }
  s.source           = {
    :git => 'https://github.com/ChineseFederation/GMB.git',
    :tag => "citizensdk-v#{s.version}",
  }
  s.platform         = :ios, '16.0'
  s.swift_versions   = ['5.0']
  s.source_files     = 'Classes/**/*.swift'
  s.dependency 'Flutter'
  s.vendored_libraries = library_pattern

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 x86_64',
  }
  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => "-force_load #{library_path} " +
                       ffi_symbols.map { |symbol| "-Wl,-u,#{symbol}" }.join(' '),
  }

  s.test_spec 'Tests' do |tests|
    tests.source_files = 'Tests/**/*.swift'
  end
end
