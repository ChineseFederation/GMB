Pod::Spec.new do |spec|
  spec.name = 'chat_sdk_ffi'
  spec.version = '1.0.0'
  spec.summary = 'ChatSDK OpenMLS native engine'
  spec.description = 'The independently built ChatSDK OpenMLS static library.'
  spec.homepage = 'https://github.com/gmb-project/gmb'
  spec.license = { :type => 'AGPL-3.0-only' }
  spec.author = { 'GMB' => 'devnull@example.invalid' }
  spec.source = { :path => '.' }
  spec.platform = :ios, '15.0'
  spec.source_files = 'placeholder.m'
  spec.public_header_files = '../include/chat_sdk.h'
  spec.vendored_libraries = 'libchat_sdk.a'
  spec.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/../include"'
  }
end
