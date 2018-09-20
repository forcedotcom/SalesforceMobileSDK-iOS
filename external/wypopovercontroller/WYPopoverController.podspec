Pod::Spec.new do |s|
  s.name         = 'WYPopoverController'
  s.version      = '0.3.8'
  s.summary      = 'An iOS Popover for iPhone and iPad. Very customizable.'
  s.description  = <<-DESC
                    WYPopoverController is for the presentation of content in popover on iPhone / iPad devices. Very customizable.
                   DESC
  s.homepage     = 'https://github.com/sammcewan/WYPopoverController'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'Nicolas CHENG' => 'nicolas.cheng.dev@gmail.com', 'Sam McEwan' => 'me@sammcewan.co.nz' }

  s.source       = { :git => 'https://github.com/sammcewan/WYPopoverController.git', :tag => '0.3.8' }

  s.source_files = 'WYPopoverController/*.{h,m}'
  s.requires_arc = true

  s.ios.deployment_target = '6.0'
  s.ios.frameworks = 'QuartzCore', 'UIKit', 'CoreGraphics'
end
