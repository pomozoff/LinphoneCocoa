Pod::Spec.new do |s|
  s.name         = "LinphoneCocoa"
  s.version      = "0.0.1"
  s.summary      = "A static library with cocoa interface to use linphone lib."

  s.description  = <<-DESC
                   This framework is a proxy to linphone lib API with convenient
                   Cocoa interface.
                   DESC

  s.homepage     = "https://github.com/pomozoff/LinphoneCocoa"
  s.license      = "MIT (example)"
  s.author             = { "Anton Pomozov" => "pomozoff@gmail.com" }
  s.platform     = :ios
  s.platform     = :ios, "6.0"
  s.source       = { :git => "https://github.com/pomozoff/LinphoneCocoa.git", :tag => "0.0.1" }
  s.source_files  = "Classes", "Classes/**/*.{h,m}"
  # s.exclude_files = "Classes/Exclude"
  s.public_header_files = "Classes/**/*.h"
  # s.resource  = "icon.png"
  # s.resources = "Resources/*.png"
  # s.framework  = "SomeFramework"
  # s.frameworks = "SomeFramework", "AnotherFramework"
  # s.library   = "iconv"
  # s.libraries = "iconv", "xml2"
  s.requires_arc = true
  # s.xcconfig = { "HEADER_SEARCH_PATHS" => "$(SDKROOT)/usr/include/libxml2" }
  # s.dependency "JSONKit", "~> 1.4"

end
