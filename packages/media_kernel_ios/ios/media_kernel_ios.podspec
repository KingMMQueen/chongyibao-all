Pod::Spec.new do |s|
  s.name             = 'media_kernel_ios'
  s.version          = '0.1.0'
  s.summary          = 'iOS 播放内核（AVPlayer + FlutterTexture）'
  s.description      = <<-DESC
与 Android / HarmonyOS 共用 app.chongyibao/player 通道的 iOS 原生实现。
                       DESC
  s.homepage         = 'https://example.com/chongyibao'
  s.license          = { :type => 'MIT', :text => 'Copyright chongyibao' }
  s.author           = { 'chongyibao' => 'dev@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '12.0'
  s.swift_version    = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
