#!/usr/bin/env ruby

require "yaml"

root = File.expand_path("../..", __dir__)
catalog_path = File.join(root, "_data", "library.yml")
order_path = File.join(root, "library-order.txt")

abort "Could not find #{catalog_path}." unless File.exist?(catalog_path)
abort "Could not find #{order_path}." unless File.exist?(order_path)

contents = File.read(catalog_path)

catalog = YAML.safe_load(
  contents,
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

duplicate_catalog_ids = catalog_ids.tally
  .select { |_entry_id, count| count > 1 }
  .keys

unless duplicate_catalog_ids.empty?
  abort(
    "Duplicate entry_id values in library.yml: " \
    "#{duplicate_catalog_ids.join(', ')}"
  )
end

ordered_ids = File.readlines(order_path, chomp: true)
  .map(&:strip)
  .reject { |line| line.empty? || line.start_with?("#") }

duplicate_order_ids = ordered_ids.tally
  .select { |_entry_id, count| count > 1 }
  .keys

unless duplicate_order_ids.empty?
  abort(
    "Duplicate entry_id values in library-order.txt: " \
    "#{duplicate_order_ids.join(', ')}"
  )
end

unknown_ids = ordered_ids - catalog_ids

unless unknown_ids.empty?
  abort(
    "These entries are in library-order.txt but not library.yml: " \
    "#{unknown_ids.join(', ')}"
  )
end

# Put newly added library entries at the bottom of the display order.
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

# Separate the entries section from anything above it.
header_match = contents.match(/^entries:\s*\r?\n/)

unless header_match
  abort "Could not find the entries section in #{catalog_path}."
end

before_entries = contents[0...header_match.end(0)]
entries_text = contents[header_match.end(0)..]

entry_starts = []

entries_text.to_enum(:scan, /^-[ \t]+title:/).each do
  entry_starts << Regexp.last_match.begin(0)
end

if entry_starts.empty?
  abort "Could not find any entry blocks in #{catalog_path}."
end

if entry_starts.length != entries.length
  abort(
    "Found #{entry_starts.length} entry blocks in the file, " \
    "but YAML contains #{entries.length} entries."
  )
end

leading_space = entries_text[0...entry_starts.first]
entry_blocks = []

entry_starts.each_with_index do |start_position, index|
  end_position = entry_starts[index + 1] || entries_text.length
  entry_blocks << entries_text[start_position...end_position]
end

order_by_id = {}

ordered_ids.each_with_index do |entry_id, index|
  order_by_id[entry_id] = (index + 1) * 10
end

# Update existing order fields and create them when missing.
# Build title information from the library.yml data already parsed above.
title_by_id = entries.to_h do |entry|
  [
    entry.fetch("entry_id").to_s,
    entry.fetch("title").to_s
  ]
end

# Update existing order fields and create them when missing.
entry_blocks.map! do |block|
  entry_id_match = block.match(
    /^[ \t]*entry_id:[ \t]*["']?([^"'#\r\n]+?)["']?[ \t]*(?:#.*)?$/
  )

  unless entry_id_match
    abort "Could not find an entry_id inside one of the library entry blocks."
  end

  entry_id = entry_id_match[1].strip

  unless order_by_id.key?(entry_id)
    abort "No library order was generated for '#{entry_id}'."
  end

  new_order = order_by_id.fetch(entry_id)

  if block.match?(/^[ \t]*order:/)
    block.sub!(
      /^[ \t]*order:[^\r\n]*/,
      "order: #{new_order}"
    )
  else
    entry_id_line = /^[ \t]*entry_id:[^\r\n]*(?:\r?\n|$)/

    block.sub!(entry_id_line) do |line|
      newline = line.end_with?("\r\n") ? "\r\n" : "\n"
      "#{line}order: #{new_order}#{newline}"
    end

    puts "Created missing order field for #{entry_id}."
  end

  block
end

# Alphabetize the physical entry blocks using the titles that were
# successfully loaded from the complete library.yml file.
entry_blocks.sort_by! do |block|
  entry_id_match = block.match(
    /^[ \t]*entry_id:[ \t]*["']?([^"'#\r\n]+?)["']?[ \t]*(?:#.*)?$/
  )

  unless entry_id_match
    abort "Could not find an entry_id while alphabetizing library.yml."
  end

  entry_id = entry_id_match[1].strip
  title = title_by_id.fetch(entry_id)

  [
    title.downcase.gsub(/\A(?:a|an|the)\s+/, ""),
    title.downcase,
    entry_id
  ]
end

# Ensure every entry block is separated by exactly one blank line.
normalized_blocks = entry_blocks.map do |block|
  block.rstrip
end

updated_contents =
  before_entries.rstrip +
  "\n\n" +
  normalized_blocks.join("\n\n") +
  "\n"

# Verify the finished file before overwriting library.yml.
begin
  YAML.safe_load(
    updated_contents,
    permitted_classes: [],
    aliases: false
  )
rescue Psych::SyntaxError => error
  abort(
    "Refusing to write invalid library.yml: " \
    "#{error.message}"
  )
end

File.write(catalog_path, updated_contents)

puts "Updated #{ordered_ids.length} library order values."
puts "Sorted #{entry_blocks.length} library entries alphabetically."
