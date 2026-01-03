#!/usr/bin/env ruby
# rgss_pack.rb
# Purpose: Pack custom RGSS scripts (plain .rb sources) into RPG Maker XP Scripts.rxdata (RGSS1),
# enforcing deterministic ordering (before Main).
#
# Usage:
#   ruby TOOLS/rgss_pack.rb --scripts_dir <path_to_RM_ACT1/DATA/DEV/RGSS> --project_dir <path_to_RMXP_BASE>
#
require 'json'
require 'zlib'
require 'digest'

def abort_msg(msg)
  $stderr.puts(msg)
  exit(1)
end

def arg_value(args, key)
  idx = args.index(key)
  return nil if idx.nil?
  args[idx + 1]
end

args = ARGV.dup
scripts_dir = arg_value(args, '--scripts_dir')
project_dir = arg_value(args, '--project_dir')
manifest_path = arg_value(args, '--manifest')

abort_msg("Missing --scripts_dir") if scripts_dir.nil? || scripts_dir.strip.empty?
abort_msg("Missing --project_dir") if project_dir.nil? || project_dir.strip.empty?

scripts_dir = File.expand_path(scripts_dir)
project_dir = File.expand_path(project_dir)
manifest_path = manifest_path ? File.expand_path(manifest_path) : File.join(scripts_dir, 'RGSS_PACK_MANIFEST.json')

abort_msg("scripts_dir not found: #{scripts_dir}") unless Dir.exist?(scripts_dir)
abort_msg("project_dir not found: #{project_dir}") unless Dir.exist?(project_dir)
abort_msg("manifest not found: #{manifest_path}") unless File.exist?(manifest_path)

scripts_rxdata = File.join(project_dir, 'Data', 'Scripts.rxdata')
abort_msg("Scripts.rxdata not found: #{scripts_rxdata}") unless File.exist?(scripts_rxdata)

manifest = JSON.parse(File.read(manifest_path))
scripts_list = manifest['scripts'] || []
abort_msg("manifest has no scripts[]") if scripts_list.empty?

arr = Marshal.load(File.binread(scripts_rxdata))
abort_msg("Unexpected Scripts.rxdata format") unless arr.is_a?(Array)

# Build deterministic order from manifest
scripts_list = scripts_list.sort_by { |s| s['order'].to_i }

# Map existing IDs by name (preserve IDs when possible)
existing_id_by_name = {}
arr.each { |e| existing_id_by_name[e[1]] = e[0].to_i }

# Remove any existing entries for scripts we're about to pack (so we can reinsert in order)
to_pack_names = scripts_list.map { |s| s['name'] || File.basename((s['file'] || ''), '.rb') }.uniq
removed = []
arr.reject! do |e|
  if to_pack_names.include?(e[1])
    removed << e[1]
    true
  else
    false
  end
end

# Find insertion point (before Main)
name_to_idx = {}
arr.each_with_index { |e, i| name_to_idx[e[1]] = i }
main_idx = name_to_idx['Main'] || arr.length
max_id = (arr.map { |e| e[0].to_i }.max || 0)
# Also consider preserved ids
preserved_max = (existing_id_by_name.values.max || 0)
max_id = [max_id, preserved_max].max

changes = []

# Insert packed scripts in order before Main
scripts_list.each do |s|
  file = s['file'] || "#{s['name']}.rb"
  name = s['name'] || File.basename(file, '.rb')
  path = File.join(scripts_dir, file)
  abort_msg("Missing script file: #{path}") unless File.exist?(path)

  src = File.binread(path)
  sha = Digest::SHA256.hexdigest(src)
  expected = (s['sha256'] || '').downcase
  if !expected.empty? && sha != expected
    abort_msg("SHA mismatch for #{file}\n expected=#{expected}\n actual  =#{sha}")
  end

  packed = Zlib::Deflate.deflate(src)

  id = existing_id_by_name[name]
  if id.nil?
    max_id += 1
    id = max_id
    changes << { 'action' => 'insert', 'name' => name, 'file' => file, 'sha256' => sha }
  else
    # if it existed, it's effectively "move+update"
    changes << { 'action' => 'move_update', 'name' => name, 'file' => file, 'sha256' => sha }
  end

  arr.insert(main_idx, [id, name, packed])
  main_idx += 1
end

File.binwrite(scripts_rxdata, Marshal.dump(arr))

report = {
  'rm_rgss_pack_spec' => 1,
  'packed_into' => scripts_rxdata,
  'project_dir' => project_dir,
  'scripts_dir' => scripts_dir,
  'manifest' => manifest_path,
  'removed' => removed,
  'changes' => changes,
  'script_count' => arr.size
}

report_path = File.join(File.dirname(__FILE__), 'rgss_pack_report.json')
File.write(report_path, JSON.pretty_generate(report))
puts "OK: Packed #{changes.size} script(s) into Scripts.rxdata (ordered)"
puts "Report: #{report_path}"
