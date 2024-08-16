Pod::Spec.new do |s|
  s.name             = 'ZTNav'
  s.version          = '0.1.0'
  s.summary          = 'ZTNav is a lightweight and flexible navigation management system for iOS applications that abstracts away direct URL handling.'

  s.description      = <<-DESC
                        ZTNav is a lightweight and flexible navigation management system for iOS applications that abstracts away direct URL handling. It provides a way to manage navigation between view controllers and logic handlers using a unified schema. By using custom URL schemes and middleware, `ZTNav` can streamline navigation flows without the native code directly interacting with web URLs.
                        DESC

  s.homepage         = 'https://github.com/willonboy/ZTNav'
  s.license          = { :type => 'MPL-2.0', :file => 'LICENSE' }
  s.author           = { 'trojan zhang' => 'willonboy@qq.com' }
  s.source           = { :git => 'https://github.com/willonboy/ZTNav.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.source_files = 'Sources/**/*.{swift,h,m}'
  s.exclude_files = 'Sources/Exclude'

  s.platforms = { :ios => '13.0' }

  s.swift_version = '5.0'

end
