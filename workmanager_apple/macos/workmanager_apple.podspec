#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'workmanager_apple'
  s.version          = '0.0.1'
  s.summary          = 'Flutter Workmanager for macOS'
  s.description      = <<-DESC
macOS implementation of the Flutter Workmanager plugin, allowing you to schedule background work
while the app is running using NSBackgroundActivityScheduler.
                       DESC
  s.homepage         = 'https://github.com/fluttercommunity/flutter_workmanager'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Flutter Community' => 'authors@fluttercommunity.dev' }
  s.source           = { :path => '.' }
  s.source_files = 'workmanager_apple/Sources/workmanager_apple/**/*.swift'
  s.dependency 'FlutterMacOS'

  s.osx.deployment_target = '10.15'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
