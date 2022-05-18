#Version Age Tracker Script
require "gems"
require "date"

gemfile = ARGV[0]
lockfile = ARGV[1]

# read a gemfile and show output
messages = []
gemfile_contents = []
ancient = {}
crusty = {}
stale = {}
fresh = {}
counter = 0

IO.foreach(gemfile.to_s) do |line|
  if line.strip.match(/^gem/)
    #delete in two steps so it can catch both characters
    gem_name = line.split(" ")[1].delete("'")
    gemfile_contents << gem_name.delete(",")
  end
end

# have this just grab all data for gems actually present in Gemfile
# drop each gem with info into a bucket (hash) - breakout into method
# parse output for each bucket
IO.foreach(lockfile.to_s) do |line|
  if line.match?(/\w+ \(\d/)
    gem, version = line.split(" ")
    # strip parentheses from version number
    version = version.slice(1..-2)
    next unless gemfile_contents.include?(gem)

    begin
      gem_info = Gems.versions(gem)
      active_version_info = gem_info.select { |v| v["number"] == version }[0]
      latest_version_info = gem_info[0]
      active_version_number = active_version_info["number"]
      latest_version_number = latest_version_info["number"]
    rescue NoMethodError
      # messages << "#{gem} not hosted on rubygems.org"
      next
    rescue Gems::NotFound
      # messages << "#{gem} not hosted on rubygems.org"
      next
    else
      # store gem info in hash
      #todo: possible use regex for grabbing date?
      active_build_date = active_version_info["built_at"]
      latest_build_date = latest_version_info["built_at"]

      age = Date.parse(latest_build_date) - Date.parse(active_build_date)

      #create contants for time spans
      if age.to_i == 0
        fresh[gem] = active_version_number
      elsif age.to_i > 0 && age.to_i < 730
        stale[gem] = { "Active version" => active_version_number, "Newest version" => latest_version_number }
      elsif age.to_i >= 730 && age.to_i < 1460
        crusty[gem] = { "Active version" => active_version_number, "Newest version" => latest_version_number }
      elsif age.to_i >= 1460
        ancient[gem] = { "Active version" => active_version_number, "Newest version" => latest_version_number }
      end

      #todo:  seperate behaviour into methods
      # sort gems into catergories based on age
      #
      # messages << "#{gem} current version #{active_version_number}, built at #{active_build_date}: latest version #{latest_version_number}, built at #{latest_build_date}"
    end
  end
end
puts "fresh"
puts fresh
puts "stale"
puts stale
puts "crusty"
puts crusty
puts "ancient"
puts ancient

File.write("crusty_gems.txt", messages.join("
"), mode: "w")
