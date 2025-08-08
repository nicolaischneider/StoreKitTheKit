Pod::Spec.new do |s|
    s.name             = 'StoreKitTheKit'
    s.version          = '1.5.2'
    s.summary          = 'A Swift package for simplified StoreKit integration'
    s.description      = <<-DESC
                            A lightweight StoreKit 2 wrapper for Swift, simplifying in-app purchases with fast integration, seamless offline support, and intelligent connection management. Ideal for non-consumable IAPs.
                            DESC
    s.homepage         = 'https://github.com/nicolaischneider/StoreKitTheKit'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 'Nicolai Schneider' => 'nicolaischneiderdev@gmail.com' }
    s.source           = { :git => 'https://github.com/nicolaischneider/StoreKitTheKit.git', :tag => s.version.to_s }

    s.ios.deployment_target = '15.0'
    s.osx.deployment_target = '12.0'
    s.tvos.deployment_target = '15.0'

    s.swift_version = '6.1'

    s.source_files = 'Sources/StoreKitTheKit/**/*.swift'
end