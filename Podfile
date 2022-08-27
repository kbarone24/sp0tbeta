platform :ios, '14.0'

target 'Spot' do
project 'Spot.xcodeproj'

use_frameworks!
  pod 'Firebase/Database'
  pod 'Firebase/Auth'
  pod 'Firebase/Firestore'
  pod 'Firebase/Storage'
  pod 'Firebase/Analytics'
  pod 'RSKImageCropper'
  pod 'IQKeyboardManagerSwift'
  pod 'Firebase/Messaging'
  pod 'Geofirestore', :git => 'https://github.com/imperiumlabs/GeoFirestore-iOS.git'
  pod 'Firebase/Performance'
  pod 'Mixpanel-swift'
  pod 'FirebaseFirestoreSwift'
  pod 'Firebase/Crashlytics'
  pod 'FirebaseUI/Storage'
  pod 'JPSVolumeButtonHandler'
  pod 'Firebase/Functions'
  pod 'SnapKit'
  pod 'R.swift'

  target 'SpotTests' do
    inherit! :search_paths
    # Pods for testing
  end

  post_install do |installer|
  	installer.pods_project.build_configurations.each do |config|
    	config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
  	end
    end	

end
