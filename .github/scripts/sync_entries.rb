#!/usr/bin/env ruby

require "fileutils"
require "yaml"

root = File.expand_path("../..", __dir__)
catalog_path = File.join(root, "_data", "library.yml")
template_path = File.join(root, "templates", "entry-template.md")
entries_dir = File.join(root, "_entries")

catalog = YAML.safe_load_file(
  catalog_path,
  permitted_classes: [],
  aliases: false
)

records = catalog.fetch("entries")

unless records.is_a?(Array)
  abort "#{catalog_path} must contain an 'entries' list."
end

template = File.read(template_path)
placeholder = "entry_id: entry-title"

unless template.include?(placeholder)
  abort "#{template_path} must contain '#{placeholder}'."
end

ids = records.map do |record|
  entry_id = record.fetch("entry_id").to_s

  unless entry_id.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/)
    abort(
      "Invalid entry_id '#{entry_id}'. " \
      "Use lowercase letters, numbers, and hyphens."
    )
  end

  entry_id
end

duplicates = ids.tally
  .select { |_entry_id, count| count > 1 }
  .keys

unless duplicates.empty?
  abort "Duplicate entry_id values: #{duplicates.join(', ')}"
end

FileUtils.mkdir_p(entries_dir)
created = []

ids.each do |entry_id|
  destination = File.join(entries_dir, "#{entry_id}.md")

  if File.exist?(destination)
    relative_path = destination.delete_prefix("#{root}/")
    puts "Keeping existing #{relative_path}"
    next
  end

  contents = template.sub(
    placeholder,
    "entry_id: #{entry_id}"
  )

  File.write(destination, contents)

  relative_path = destination.delete_prefix("#{root}/")
  created << relative_path
  puts "Created #{relative_path}"
end

puts "No entry files needed." if created.empty?
