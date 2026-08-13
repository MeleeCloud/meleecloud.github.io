#!/usr/bin/env ruby

require "yaml"

root = File.expand_path("../..", __dir__)
catalog_path = File.join(root, "_data", "library.yml")
order_path = File.join(root, "library-order.txt")

abort "Could not find #{catalog_path}." unless File.exist?(catalog_path)
abort "Could not find #{order_path}." unless File.exist?(order_path)

# Load library.yml normally.
catalog = YAML.safe_load_file(
  catalog_path,
  permitted_classes: [],
  aliases: false
)

entries = catalog.fetch("entries")

unless entries.is_a?(Array)
  abort "#{catalog_path} must contain an 'entries' list."
end

catalog_ids = entries.map do |entry|
  entry.fetch("entry_id").to_s
end

# Make sure library.yml does not contain duplicate IDs.
duplicate_catalog_ids = catalog_ids.tally
  .select { |_entry_id, count| count > 1 }
  .keys

unless duplicate_catalog_ids.empty?
  abort(
    "Duplicate entry_id values in library.yml: " \
    "#{duplicate_catalog_ids.join(', ')}"
  )
end

# Read the requested website order.
ordered_ids = File.readlines(order_path, chomp: true)
  .map(&:strip)
  .reject { |line| line.empty? || line.start_with?("#") }

# Make sure library-order.txt does not contain duplicate IDs.
duplicate_order_ids = ordered_ids.tally
  .select { |_entry_id, count| count > 1 }
  .keys

unless duplicate_order_ids.empty?
  abort(
    "Duplicate entry_id values in library-order.txt: " \
    "#{duplicate_order_ids.join(', ')}"
  )
end

# Reject IDs that do not exist in library.yml.
unknown_ids = ordered_ids - catalog_ids

unless unknown_ids.empty?
  abort(
    "These entries are in library-order.txt but not library.yml: " \
    "#{unknown_ids.join(', ')}"
  )
end

# Add new entries to the bottom of the website order.
missing_ids = catalog_ids - ordered_ids

unless missing_ids.empty?
  ordered_ids.concat(missing_ids)

  order_contents = File.read(order_path)

  File.open(order_path, "a") do |file|
    unless order_contents.empty? || order_contents.end_with?("\n")
      file.puts
    end

    missing_ids.each do |entry_id|
      file.puts entry_id
    end
  end

  puts "Added new entries to the bottom of library-order.txt:"

  missing_ids.each do |entry_id|
    puts "  - #{entry_id}"
  end
end

# Create the numeric order lookup.
order_by_id = {}

ordered_ids.each_with_index do |entry_id, index|
  order_by_id[entry_id] = (index + 1) * 10
end

# Update or create every order value.
entries.each do |entry|
  entry_id = entry.fetch("entry_id").to_s
  entry["order"] = order_by_id.fetch(entry_id)
end

# Keep the actual library.yml entries alphabetized by title.
entries.sort_by! do |entry|
  [
    entry.fetch("title").to_s.downcase,
    entry.fetch("entry_id").to_s
  ]
end

catalog["entries"] = entries

# Let Ruby generate valid YAML instead of manually moving text blocks.
updated_contents = YAML.dump(catalog)

# Confirm the generated result is valid before writing it.
begin
  YAML.safe_load(
    updated_contents,
    permitted_classes: [],
    aliases: false
  )
rescue Psych::SyntaxError => error
  abort "Refusing to write invalid library.yml: #{error.message}"
end

File.write(catalog_path, updated_contents)

puts "Updated #{ordered_ids.length} library order values."
puts "Sorted #{entries.length} library entries alphabetically."
