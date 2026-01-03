#!/usr/bin/env ruby
# rgss_verify.rb
# Purpose: Verify that Scripts.rxdata contains required packed scripts with expected sha256 (from RGSS_PACK_MANIFEST.json).
#
# Usage:
#   ruby TOOLS/rgss_verify.rb --scripts_dir <path_to_RM_ACT1/DATA/DEV/RGSS> --project_dir <path_to_RMXP_BASE>
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

abort_msg("manifest not found: #{manifest_path}") unless File.exist?(manifest_path)

scripts_rxdata = File.join(project_dir, 'Data', 'Scripts.rxdata')
abort_msg("Scripts.rxdata not found: #{scripts_rxdata}") unless File.exist?(scripts_rxdata)

manifest = JSON.parse(File.read(manifest_path))
scripts_list = manifest['scripts'] || []
abort_msg("manifest has no scripts[]") if scripts_list.empty?

arr = Marshal.load(File.binread(scripts_rxdata))
name_to_entry = {}
arr.each { |e| name_to_entry[e[1]] = e }

fails = []
ok = []

scripts_list.each do |s|
  next unless (s['required'].nil? || s['required'] == true || s['required'].to_s.upcase == 'Y')
  name = s['name']
  expected = (s['sha256'] || '').downcase
  entry = name_to_entry[name]
  if entry.nil?
    fails << { 'name' => name, 'reason' => 'missing' }
    next
  end
  begin
    src = Zlib::Inflate.inflate(entry[2])
  rescue => ex
    fails << { 'name' => name, 'reason' => "inflate_error: #{ex.class}" }
    next
  end
  sha = Digest::SHA256.hexdigest(src)
  if !expected.empty? && sha != expected
    fails << { 'name' => name, 'reason' => 'sha_mismatch', 'expected' => expected, 'actual' => sha }
  else
    ok << { 'name' => name, 'sha256' => sha }
  end
end

result = {
  'rm_rgss_pack_spec' => 1,
  'scripts_rxdata' => scripts_rxdata,
  'manifest' => manifest_path,
  'ok' => ok,
  'fails' => fails
}

out_path = File.join(File.dirname(__FILE__), 'rgss_verify_report.json')
File.write(out_path, JSON.pretty_generate(result))
if fails.empty?
  puts "OK: all required scripts verified"
  puts "Report: #{out_path}"
  exit(0)
else
  $stderr.puts("FAIL: #{fails.size} script(s) failed verification")
  $stderr.puts("Report: #{out_path}")
  exit(2)
end
