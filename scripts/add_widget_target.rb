#!/usr/bin/env ruby
# Приводит проект MillionersBot к состоянию с виджетом QuickAddWidgetExtension.
# Виджет — одна кнопка «+ Трата» с deep-link millionersbot://add (без App Group).
# Идемпотентно: создаёт таргет, если его нет, и вычищает устаревшую машинерию
# (App Group / общий файл / AppIntent), если осталась от прошлой версии.
# Запуск:
#   GEM_HOME=$(ruby -e 'puts Gem.user_dir') ruby scripts/add_widget_target.rb
require 'xcodeproj'

PROJECT       = File.expand_path('MillionersBot.xcodeproj', Dir.pwd)
APP_TARGET    = 'MillionersBot'
WIDGET        = 'QuickAddWidgetExtension'
WIDGET_BUNDLE = 'com.danila.MillionersBot.QuickAddWidget'
TEAM          = 'KP54874C49'
WIDGET_SOURCES = %w[QuickAddWidgetBundle.swift QuickAddWidget.swift].freeze

project = Xcodeproj::Project.open(PROJECT)
main    = project.main_group
app     = project.targets.find { |t| t.name == APP_TARGET } or abort 'app target not found'

# --- Регистрация URL-схемы приложения (deep-link millionersbot://add) ---
# GENERATE_INFOPLIST_FILE=YES остаётся: сгенерированные ключи мержатся в этот файл.
app.build_configurations.each do |c|
  c.build_settings['INFOPLIST_FILE'] = 'Config/MillionersBot-Info.plist'
  c.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
end

# --- Вычистка устаревшего: App Group entitlements ---
(app.build_configurations + (project.targets.find { |t| t.name == WIDGET }&.build_configurations || [])).each do |c|
  c.build_settings.delete('CODE_SIGN_ENTITLEMENTS')
end

# --- Вычистка устаревшего: общий файл SharedQuickAdd.swift и группа Shared ---
project.files.select { |f| f.path == 'SharedQuickAdd.swift' }.each do |ref|
  ref.build_files.to_a.each { |bf| bf.remove_from_project }
  ref.remove_from_project
end
if (sg = project['Shared'])
  sg.remove_from_project
end

# --- Создать таргет виджета при отсутствии ---
widget = project.targets.find { |t| t.name == WIDGET }
unless widget
  widget = project.new_target(:app_extension, WIDGET, :ios, '26.2')
  app.add_dependency(widget)
  embed = app.new_copy_files_build_phase('Embed Foundation Extensions')
  embed.symbol_dst_subfolder_spec = :plug_ins
  embed.dst_path = ''
  bf = embed.add_file_reference(widget.product_reference, true)
  bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

# --- Настройки сборки виджета ---
widget.build_configurations.each do |c|
  bs = c.build_settings
  bs['PRODUCT_BUNDLE_IDENTIFIER'] = WIDGET_BUNDLE
  bs['PRODUCT_NAME'] = '$(TARGET_NAME)'
  bs['INFOPLIST_FILE'] = 'QuickAddWidget/Info.plist'
  bs['GENERATE_INFOPLIST_FILE'] = 'NO'
  bs['CODE_SIGN_STYLE'] = 'Automatic'
  bs['DEVELOPMENT_TEAM'] = TEAM
  bs['IPHONEOS_DEPLOYMENT_TARGET'] = '26.2'
  bs['SWIFT_VERSION'] = '5.0'
  bs['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
  bs['SWIFT_DEFAULT_ACTOR_ISOLATION'] = 'MainActor'
  bs['TARGETED_DEVICE_FAMILY'] = '1,2'
  bs['MARKETING_VERSION'] = '1.0'
  bs['CURRENT_PROJECT_VERSION'] = '1'
  bs['SKIP_INSTALL'] = 'YES'
  bs['ENABLE_PREVIEWS'] = 'YES'
  bs['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
end
if (dbg = widget.build_configurations.find { |c| c.name == 'Debug' })
  dbg.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG $(inherited)'
end

# --- Файлы виджета: только Bundle + Widget (убрать устаревший AddPendingExpenseIntent) ---
wgroup = project['QuickAddWidget'] || main.new_group('QuickAddWidget', 'QuickAddWidget')
widget.source_build_phase.files.to_a.each do |bf|
  name = bf.file_ref&.path
  bf.remove_from_project unless WIDGET_SOURCES.include?(name)
end
project.files.select { |f| f.path == 'AddPendingExpenseIntent.swift' }.each(&:remove_from_project)
WIDGET_SOURCES.each do |name|
  ref = wgroup.files.find { |f| f.path == name } || wgroup.new_reference(name)
  unless widget.source_build_phase.files_references.include?(ref)
    widget.add_file_references([ref])
  end
end
%w[Info.plist].each do |name|
  wgroup.new_reference(name) unless wgroup.files.any? { |f| f.path == name }
end

project.save
puts "Ensured target #{WIDGET} (#{WIDGET_BUNDLE}), deep-link widget, no App Group."
