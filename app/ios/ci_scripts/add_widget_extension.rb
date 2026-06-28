require 'xcodeproj'

project_path = File.expand_path('../Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)

if project.targets.any? { |t| t.name == 'CampusLifeWidgetExtension' }
  puts 'CampusLifeWidgetExtension target already exists, skipping.'
  exit 0
end

runner_target = project.targets.find { |t| t.name == 'Runner' }
raise 'Runner target not found' unless runner_target

app_group_id = 'group.com.campuslife.app'
bundle_id = 'com.campuslife.app.CampusLifeWidget'

widget_group = project.main_group.new_group('CampusLifeWidget', 'CampusLifeWidget')
swift_files = ['CampusLifeWidget.swift', 'CampusLifeWidgetBundle.swift']
info_plist_ref = widget_group.new_reference('Info.plist')
entitlements_ref = widget_group.new_reference('CampusLifeWidget.entitlements')
source_refs = swift_files.map { |f| widget_group.new_reference(f) }

widget_target = project.new_target(
  :app_extension,
  'CampusLifeWidgetExtension',
  :ios,
  '16.0',
  project.products_group,
  :swift
)

source_refs.each { |ref| widget_target.source_build_phase.add_file_reference(ref) }

frameworks_group = project.frameworks_group
['WidgetKit.framework', 'SwiftUI.framework'].each do |fw|
  file_ref = frameworks_group.new_file("System/Library/Frameworks/#{fw}", :sdk_root)
  widget_target.frameworks_build_phase.add_file_reference(file_ref)
end

widget_target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_FILE'] = 'CampusLifeWidget/Info.plist'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'CampusLifeWidget/CampusLifeWidget.entitlements'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
end

runner_target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

runner_target.add_dependency(widget_target)

embed_phase = runner_target.copy_files_build_phases.find { |p| p.name == 'Embed Foundation Extensions' }
embed_phase ||= runner_target.new_copy_files_build_phase('Embed Foundation Extensions')
embed_phase.dst_subfolder_spec = '13'
embed_phase.symbol_dst_subfolder_spec = :plug_ins

embed_build_file = embed_phase.add_file_reference(widget_target.product_reference)
embed_build_file.settings = { 'ATTRIBUTES' => ['RemoveHeaderOnCopy'] }

# Flutter's own script phases (Embed Pods Frameworks, Thin Binary, etc.) don't
# declare input/output paths, which makes Xcode's new build system unable to
# order them relative to the extension embed phase above and report a cycle.
# Excluding them from dependency analysis (the same as unchecking "Based on
# dependency analysis" in Xcode) breaks the cycle.
runner_target.build_phases.each do |phase|
  next unless phase.respond_to?(:input_paths)
  next unless phase.input_paths.empty? && phase.output_paths.empty?

  phase.always_out_of_date = true if phase.respond_to?(:always_out_of_date=)
end

project.save

puts 'Added CampusLifeWidgetExtension target.'
