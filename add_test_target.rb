require 'xcodeproj'

PROJECT_PATH = File.join(__dir__, 'Tempo.xcodeproj')
project = Xcodeproj::Project.open(PROJECT_PATH)

# Don't add if already exists
if project.targets.any? { |t| t.name == 'TempoTests' }
  puts "TempoTests target already exists, skipping."
  exit 0
end

main_target = project.targets.find { |t| t.name == 'Tempo' }
raise "Main target not found" unless main_target

# Add unit test target
test_target = project.new_target(:unit_test_bundle, 'TempoTests', :ios, '17.0')

# Set bundle identifier and test host
test_target.build_configurations.each do |config|
  config.build_settings['BUNDLE_IDENTIFIER']          = 'com.ashishkattamuri.Tempo.Tests'
  config.build_settings['TEST_HOST']                  = "$(BUILT_PRODUCTS_DIR)/Tempo.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Tempo"
  config.build_settings['BUNDLE_LOADER']              = '$(TEST_HOST)'
  config.build_settings['SWIFT_VERSION']              = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  config.build_settings['PRODUCT_NAME']               = '$(TARGET_NAME)'
end

# Create TempoTests group if not present
tests_group = project['TempoTests'] || project.new_group('TempoTests', 'TempoTests')

# Add all test Swift files
test_files = Dir[File.join(__dir__, 'TempoTests', '*.swift')]
test_files.each do |file_path|
  file_name = File.basename(file_path)
  unless tests_group.files.any? { |f| f.path == file_name }
    file_ref = tests_group.new_file(file_path)
    test_target.source_build_phase.add_file_reference(file_ref)
    puts "Added #{file_name}"
  end
end

# Link test target to main target
test_target.add_dependency(main_target)

project.save
puts "Done. TempoTests target created with #{test_files.count} files."
