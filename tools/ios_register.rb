# يسجّل Runner.entitlements (Sign in with Apple) داخل مشروع Xcode. يُشغَّل في CI على macOS.
require 'xcodeproj'
proj = Xcodeproj::Project.open('ios/Runner.xcodeproj')
target = proj.targets.find { |t| t.name == 'Runner' }
group = proj.main_group['Runner']
group.new_file('Runner.entitlements') unless group.files.any? { |f| f.path == 'Runner.entitlements' }
target.build_configurations.each do |c|
  c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
  c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
end
proj.save
puts 'xcode project registered'
