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

ordered_ids = File.readlines(order_path, chomp: true)
  .map(&:strip)
  .reject { |line| line.empty? || line.start_with?("#") }

duplicates = ordered_ids.tally
  .select { |_entry_id, count| count > 1 }
  .keys

unless duplicates.empty?
  abort "Duplicate entry_id values in library-order.txt: #{duplicates.join(', ')}"
end

unknown_ids = ordered_ids - catalog_ids

unless unknown_ids.empty?
  abort(
    "These entry_id values are in library-order.txt but not library.yml: " \
    "#{unknown_ids.join(', ')}"
  )
end

# Automatically put newly created entries at the bottom.
missing_ids = catalog_ids - ordered_ids

unless missing_ids.empty?
  ordered_ids.concat(missing_ids)

  File.open(order_path, "a") do |file|
    file.puts unless File.read(order_path).end_with?("\n")
    missing_ids.each { |entry_id| file.puts entry_id }
  end

  puts "Added new entries to the bottom of library-order.txt:"
  missing_ids.each { |entry_id| puts "  - #{entry_id}" }
end

contents = File.read(catalog_path)

ordered_ids.each_with_index do |entry_id, index|
  new_order = (index + 1) * 10

  pattern = /
    (^ [\t ]* entry_id: [\t ]* #{Regexp.escape(entry_id)} [\t ]* \r?\n)
    (
      (?:
        (?! ^[\t ]*-[\t ]+title: )
        .
      )*?
    )
    (^ [\t ]* order: [\t ]*) \d+ ([\t ]* $)
  /mx

  unless contents.match?(pattern)
    abort "Could not find an order field for '#{entry_id}' in #{catalog_path}."
  end

  contents.sub!(pattern) do
    "#{Regexp.last_match(1)}" \
    "#{Regexp.last_match(2)}" \
    "#{Regexp.last_match(3)}" \
    "#{new_order}" \
    "#{Regexp.last_match(4)}"
  end
end

File.write(catalog_path, contents)

puts "Updated #{ordered_ids.length} library order values."
