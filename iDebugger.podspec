#
# Be sure to run `pod lib lint iDebugger.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'iDebugger'
  s.version          = `cat .version`.strip
  s.summary          = 'A debugger for iOS.'
  s.description      = <<-DESC
A handy menu entry for debugging iOS apps easily.
                       DESC

  s.homepage         = 'https://github.com/xingheng/iDebugger'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Will Han' => 'xingheng907@hotmail.com' }
  s.source           = { :git => 'https://github.com/xingheng/iDebugger.git', :tag => s.version.to_s }
  s.social_media_url = 'https://x.com/xingheng907'

  s.ios.deployment_target = '13.0'
  s.frameworks = 'UIKit'
  s.default_subspec = 'All'

  s.subspec 'Core' do |ss|
    ss.source_files = 'Sources/iDebugger/*.{h,m}'
    ss.public_header_files = 'Sources/iDebugger/Debugger.h'
  end

  s.subspec 'FLEX' do |ss|
    ss.dependency 'FLEX'
  end

  s.subspec 'All' do |ss|
    ss.dependency 'iDebugger/Core'
    ss.dependency 'iDebugger/FLEX'
  end
end
