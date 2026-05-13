#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Adds the MuesliRecordingLiveActivity Widget Extension target to
# src/mobile/Muesli.xcodeproj. Run once after pulling the branch.
#
# Usage:
#   GEM_HOME=$HOME/.gem/ruby/2.6.0 ruby scripts/add-live-activity-target.rb
#
# Idempotent: if the target already exists, the script is a no-op.

$LOAD_PATH.unshift(*Dir.glob("#{ENV.fetch('HOME')}/.gem/ruby/*/gems/*/lib"))
require 'xcodeproj'

PROJECT_PATH = File.expand_path('../src/mobile/Muesli.xcodeproj', __dir__)
TARGET_NAME = 'MuesliRecordingLiveActivity'
EXT_DIR_REL = "#{TARGET_NAME}/"
EXT_DIR_ABS = File.expand_path("../src/mobile/#{TARGET_NAME}", __dir__)
SHARED_ATTRS_FILE = 'Muesli/LiveActivity/RecordingActivityAttributes.swift'
SHARED_ATTRS_NAME = 'RecordingActivityAttributes.swift'

abort "Project not found at #{PROJECT_PATH}" unless Dir.exist?(PROJECT_PATH)

project = Xcodeproj::Project.open(PROJECT_PATH)
app_target = project.targets.find { |t| t.name == 'Muesli' }
abort "Main 'Muesli' target not found" unless app_target

if project.targets.any? { |t| t.name == TARGET_NAME }
  puts "Target #{TARGET_NAME} already exists; nothing to do."
  exit 0
end

# Build settings derived from the main app target — keep deployment, bundle
# identifier prefix, and Swift version consistent.
app_release_config = app_target.build_configurations.find { |c| c.name == 'Release' }
app_debug_config = app_target.build_configurations.find { |c| c.name == 'Debug' }
deployment = app_release_config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] || '16.2'
swift_version = app_release_config.build_settings['SWIFT_VERSION'] || '5.0'
bundle_prefix = (app_release_config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] || 'dev.koderex.Muesli').dup
dev_team = app_release_config.build_settings['DEVELOPMENT_TEAM']

# Create the extension target.
ext_target = project.new_target(
  :app_extension,
  TARGET_NAME,
  :ios,
  deployment,
  project.products_group,
  :swift
)

# Pin product type so SwiftUI Live Activities recognize it.
ext_target.product_type = 'com.apple.product-type.app-extension'

# Group for the extension's sources.
ext_group = project.main_group.find_subpath(TARGET_NAME, true)
ext_group.set_source_tree('<group>')
ext_group.set_path(TARGET_NAME)

# Add the two Swift sources owned by the extension.
%w[MuesliRecordingLiveActivityBundle.swift RecordingActivityWidget.swift].each do |fname|
  abspath = File.join(EXT_DIR_ABS, fname)
  abort "Missing extension source: #{abspath}" unless File.exist?(abspath)
  file_ref = ext_group.new_file(fname)
  ext_target.add_file_references([file_ref])
end

# Share the ActivityAttributes type with the main app by also building it
# into the extension. The main app uses a filesystem-synchronized root
# group, so the shared file isn't in the pbxproj as a regular PBXFileReference.
# Add a separate reference pointing at the same path on disk.
shared_group = ext_group
shared_ref = shared_group.find_file_by_path('SharedRecordingActivityAttributes.swift')
unless shared_ref
  shared_ref = shared_group.new_reference(
    File.expand_path('../src/mobile/Muesli/LiveActivity/RecordingActivityAttributes.swift', __dir__)
  )
  shared_ref.name = 'RecordingActivityAttributes.swift'
end
ext_target.add_file_references([shared_ref])

# Info.plist for the extension.
info_plist_rel = "#{TARGET_NAME}/Info.plist"
info_plist_ref = ext_group.find_file_by_path('Info.plist') || ext_group.new_file('Info.plist')

# Set build settings on each configuration.
ext_target.build_configurations.each do |config|
  bs = config.build_settings
  bs['PRODUCT_NAME'] = '$(TARGET_NAME)'
  bs['PRODUCT_BUNDLE_IDENTIFIER'] = "#{bundle_prefix}.#{TARGET_NAME}"
  bs['INFOPLIST_FILE'] = info_plist_rel
  bs['IPHONEOS_DEPLOYMENT_TARGET'] = deployment
  bs['SWIFT_VERSION'] = swift_version
  bs['SKIP_INSTALL'] = 'YES'
  bs['CODE_SIGN_STYLE'] = 'Automatic'
  bs['DEVELOPMENT_TEAM'] = dev_team if dev_team
  bs['GENERATE_INFOPLIST_FILE'] = 'NO'
  bs['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  bs['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
  bs['CURRENT_PROJECT_VERSION'] = '1'
  bs['MARKETING_VERSION'] = '1.0'
  bs['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  bs['ASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME'] = 'WidgetBackground'
end

# Make the app target depend on the extension and embed it.
app_target.add_dependency(ext_target)

embed_phase = app_target.copy_files_build_phases.find do |p|
  p.symbol_dst_subfolder_spec == :plug_ins
end
embed_phase ||= app_target.new_copy_files_build_phase('Embed App Extensions').tap do |p|
  p.symbol_dst_subfolder_spec = :plug_ins
  p.dst_path = ''
end
already_embedded = embed_phase.files_references.any? { |r| r&.path&.include?(TARGET_NAME) }
unless already_embedded
  build_file = embed_phase.add_file_reference(ext_target.product_reference)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

# Make sure the main app declares Live Activity support and the audio
# background mode so recording survives backgrounding.
app_target.build_configurations.each do |config|
  bs = config.build_settings
  bs['INFOPLIST_KEY_NSSupportsLiveActivities'] = 'YES'
  modes = bs['INFOPLIST_KEY_UIBackgroundModes']
  current = case modes
            when Array then modes.dup
            when String then [modes]
            else []
            end
  current << 'audio' unless current.include?('audio')
  bs['INFOPLIST_KEY_UIBackgroundModes'] = current
end

project.save
puts "Added Widget Extension target '#{TARGET_NAME}'. Re-open Xcode if it's running."
