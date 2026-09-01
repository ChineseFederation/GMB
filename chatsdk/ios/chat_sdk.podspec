framework_path = File.expand_path('ChatSDK.xcframework', __dir__)
unless Dir.exist?(framework_path)
  raise "缺少 #{framework_path}，先运行 scripts/build-native.sh ios"
end

Pod::Spec.new do |spec|
  spec.name = 'chat_sdk'
  spec.version = '1.0.0'
  spec.summary = 'ChatSDK OpenMLS native engine'
  spec.description = 'The independently built ChatSDK OpenMLS dynamic framework.'
  spec.homepage = 'https://github.com/gmb-project/gmb'
  spec.license = { :type => 'AGPL-3.0-only' }
  spec.author = { 'GMB' => 'devnull@example.invalid' }
  spec.source = { :path => '.' }
  spec.platform = :ios, '16.0'
  # TataConsole stages the central build into its disposable source snapshot.
  # CocoaPods requires this path to stay inside the binary Pod root.
  spec.vendored_frameworks = 'ChatSDK.xcframework'
end
