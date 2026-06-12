#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'workmanager_apple'
  s.version          = '0.0.1'
  s.summary          = 'Flutter Workmanager for iOS'
  s.description      = <<-DESC
iOS implementation of the Flutter Workmanager plugin, allowing you to schedule background work.
                       DESC
  s.homepage         = 'https://github.com/fluttercommunity/flutter_workmanager'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Flutter Community' => 'authors@fluttercommunity.dev' }
  s.source           = { :path => '.' }
  s.source_files = 'workmanager_apple/Sources/workmanager_apple/**/*.swift'
  s.dependency 'Flutter'

  s.ios.deployment_target = '14.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
  s.resource_bundles = { 'flutter_workmanager_privacy' => ['workmanager_apple/Sources/workmanager_apple/PrivacyInfo.xcprivacy'] }
end
