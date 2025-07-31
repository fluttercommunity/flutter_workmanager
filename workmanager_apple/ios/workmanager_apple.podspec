#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'workmanager_apple'
  s.version          = '0.0.1'
  s.summary          = 'Flutter Workmanager'
  s.description      = <<-DESC
Flutter Android Workmanager
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'

  s.ios.deployment_target = '14.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
  s.resource_bundles = { 'flutter_workmanager_privacy' => ['Resources/PrivacyInfo.xcprivacy'] }
end

