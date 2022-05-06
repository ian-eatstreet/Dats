#Version Age Tracker Script
require "gems"

gemfile = ARGV[0]

# read a gemfile and show output
messages = []
counter = 0
IO.foreach(gemfile.to_s) do |line|
  if line.match?(/\w+ \(\d/)
    gem, version = line.split(" ")
    # strip parentheses from version number
    version = version.slice(1..-2)
    next if gem == "StreetAddress"
    gem_info = Gems.versions(gem)
    # store gem info in hash
    active_version_info = gem_info.select { |v| v["number"] == version }[0]
    latest_version_info = gem_info[0]
    active_version_number = active_version_info["number"]
    latest_version_number = latest_version_info["number"]
    #todo: possible use regex for grabbing date?
    active_build_date = active_version_info["built_at"].slice(0, 10)
    latest_build_date = latest_version_info["built_at"].slice(0, 10)
    #todo:  seperate behaviour into methods
    # add logic for handling non rubygems gems
    # sort gems into catergories based on age
    messages << "#{gem} current version #{active_version_number}, built at #{active_build_date}: latest version #{latest_version_number}, built at #{latest_build_date}"
    counter += 1
    puts counter
  end
end
File.write("crusty_gems.txt", messages.join("\n"))
