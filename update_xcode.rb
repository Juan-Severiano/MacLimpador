require 'xcodeproj'

project_path = 'MacLimpador.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first
main_group = project.main_group.find_subpath('MacLimpador', false)

# Remove old files
old_files = ['ContentView.swift', 'Item.swift']
old_files.each do |file_name|
  file_ref = main_group.files.find { |f| f.path == file_name }
  if file_ref
    target.source_build_phase.remove_file_reference(file_ref)
    file_ref.remove_from_project
  end
end

# Add new groups and files recursively
def add_files(group, dir_path, target)
  Dir.foreach(dir_path) do |entry|
    next if entry == '.' || entry == '..'
    full_path = File.join(dir_path, entry)
    if File.directory?(full_path)
      sub_group = group.children.find { |c| c.display_name == entry || c.path == entry } || group.new_group(entry, entry)
      add_files(sub_group, full_path, target)
    elsif full_path.end_with?('.swift')
      file_ref = group.files.find { |f| f.path == entry } || group.new_file(entry)
      target.source_build_phase.add_file_reference(file_ref, true)
    end
  end
end

['Models', 'ViewModels', 'Views', 'Services'].each do |dir|
  full_dir = File.join('MacLimpador', dir)
  if Dir.exist?(full_dir)
    sub_group = main_group.children.find { |c| c.display_name == dir || c.path == dir } || main_group.new_group(dir, dir)
    add_files(sub_group, full_dir, target)
  end
end

project.save
puts "Xcode project updated successfully."