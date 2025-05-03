Pod::Spec.new do |s|
    s.name             = 'StoreKitTheKit'
    s.version          = '1.1.0'
    s.summary          = 'A Swift package for simplified StoreKit integration'
    s.description      = <<-DESC
                            StoreKitTheKit is a Swift library that provides a simplified interface for working with StoreKit.
                            It makes implementing in-app purchases and subscriptions more straightforward for iOS, macOS, and tvOS applications.
                            DESC
    s.homepage         = 'https://github.com/nicolaischneider/StoreKitTheKit'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 'Nicolai Schneider' => '' }
    s.source           = { :git => 'https://github.com/nicolaischneider/StoreKitTheKit.git', :tag => s.version.to_s }

    s.ios.deployment_target = '15.0'
    s.osx.deployment_target = '12.0'
    s.tvos.deployment_target = '15.0'

    s.swift_version = '6.1'

    s.source_files = 'Sources/StoreKitTheKit/**/*.swift'
end