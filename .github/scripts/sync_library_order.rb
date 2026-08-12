#!/usr/bin/env ruby

require "yaml"

root = File.expand_path("../..", __dir__)
catalog_path = File.join(root, "_data", "library.yml")
order_path = File.join(root, "library-order.txt")

unless File.exist?(catalog_path)
  abort "Could not find #{catalog_path}."
end

unless File.exist?(order_path)
  abort "Could not find #{order_path}."
end

def load_catalog(path)
  YAML.safe_load_file(
    path,
    permitted_classes: [],
    aliases: false
  )
end

catalog = load_catalog(catalog_path)
entries = catalog.fetch("entries")

unless entries.is_a?(Array)
  abort "#{catalog_path} must contain an 'entries' list."
end

catalog_ids = entries.map do |entry|
  entry.fetch("entry_id").to_s
end

ordered_ids = File.readlines(order_path, chomp: true)
  .map(&:strip)
  .reject { |line| line.empty? || line.start_with?("#") }

duplicates = ordered_ids.tally
  .select { |_entry_id, count| count > 1 }
  .keys

unless duplicates.empty?
  abort(
    "Duplicate entry_id values in library-order.txt: " \
    "#{duplicates.join(', ')}"
  )
end

unknown_ids = ordered_ids - catalog_ids

unless unknown_ids.empty?
  abort(
    "These entry_id values are in library-order.txt but not library.yml: " \
    "#{unknown_ids.join(', ')}"
  )
end

# Add newly created entries to the bottom of library-order.txt.
missing_ids = catalog_ids - ordered_ids

unless missing_ids.empty?
  ordered_ids.concat(missing_ids)

  existing_order_contents = File.read(order_path)

  File.open(order_path, "a") do |file|
    file.puts unless existing_order_contents.empty? ||
                     existing_order_contents.end_with?("\n")

    missing_ids.each do |entry_id|
      file.puts entry_id
    end
  end

  puts "Added new entries to the bottom of library-order.txt:"
  missing_ids.each { |entry_id| puts "  - #{entry_id}" }
end

contents = File.read(catalog_path)

# Update each order number from library-order.txt.
ordered_ids.each_with_index do |entry_id, index|
  new_order = (index + 1) * 10

  entry_pattern = /
    (
      ^-[\t ]+title:.*?\r?\n
      (?:
        (?!^-[\t ]+title:)
        .
      )*?
      ^[\t ]*entry_id:[\t ]*#{Regexp.escape(entry_id)}[\t ]*\r?\n
      (?:
        (?!^-[\t ]+title:)
        .
      )*?
    )
    (^ [\t ]* order: [\t ]*) \d+ ([\t ]* $)
  /mx

  unless contents.match?(entry_pattern)
    abort(
      "Could not find an order field for '#{entry_id}' " \
      "in #{catalog_path}."
    )
  end

  contents.sub!(entry_pattern) do
    "#{Regexp.last_match(1)}" \
    "#{Regexp.last_match(2)}" \
    "#{new_order}" \
    "#{Regexp.last_match(3)}"
  end
end

# Find and alphabetize the original YAML entry blocks.
entries_header = contents.index(/^entries:\s*\r?\n/)

unless entries_header
  abort "Could not find the entries section in #{catalog_path}."
end

header_match = contents.match(/^entries:\s*\r?\n/, entries_header)
header_end = header_match.end(0)

before_entries = contents[0...header_end]
entries_text = contents[header_end..]

entry_starts = []

entries_text.to_enum(:scan, /^-[\t ]+title:/).each do
  entry_starts << Regexp.last_match.begin(0)
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

entry_blocks.sort_by! do |block|
  parsed = YAML.safe_load(
    "entries:\n#{block}",
    permitted_classes: [],
    aliases: false
  )

  title = parsed.fetch("entries").first.fetch("title").to_s
  title.downcase
end

contents = before_entries +
  leading_space +
  entry_blocks.join

File.write(catalog_path, contents)

puts "Updated #{ordered_ids.length} library order values."
puts "Sorted #{entry_blocks.length} library.yml entries alphabetically by title."
