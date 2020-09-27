flutter build apk
cp build/app/outputs/apk/release/app-release.apk buildOutput/
flutter build ios
cd ios
xcodebuild -workspace Runner.xcworkspace -scheme Runner -sdk iphoneos -configuration Release archive -archivePath $PWD/build/Runner.xcarchive
xcodebuild -exportArchive -archivePath $PWD/build/Runner.xcarchive -exportOptionsPlist exportOptions.plist -exportPath $PWD/build/Runner.ipa
cd ..
cp ios/build/Runner.ipa/Runner.ipa buildOutput/