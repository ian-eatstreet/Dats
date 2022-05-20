#Version Age Tracker Script
require "gems"
require "date"

class Dats
  TWO_YEARS = 730
  FOUR_YEARS = 1460
  attr_accessor :gemfile_contents, :ancient, :crusty, :stale, :fresh, :not_found, :gem_info, :date

  def initialize(gemfile, lockfile)
    @gemfile = gemfile
    @lockfile = lockfile
    @gemfile_contents = []
    @ancient = []
    @crusty = []
    @stale = []
    @fresh = []
    @not_found = []
    @gem_info = {}
    @date = Date.today.strftime("%Y-%m-%d")
  end

  def run
    yank_gemfile_names
    get_gem_info
    output_to_file
  end

  def yank_gemfile_names
    IO.foreach(@gemfile.to_s) do |line|
      if line.strip.match(/^gem/)
        #delete in two steps so it can catch both characters
        gem_name = line.split(" ")[1].delete("'")
        @gemfile_contents << gem_name.delete(",")
      end
    end
  end

  def get_gem_info
    IO.foreach(@lockfile.to_s) do |line|
      if line.match?(/\w+ \(\d/)
        gem_name, version = line.split(" ")
        # strip parentheses from version number
        version = version.slice(1..-2)
        next if gem_name == "sidekiq-pro" || gem_name == "StreetAddress"
        next unless gemfile_contents.include?(gem_name)

        begin
          rubygems_json = Gems.versions(gem_name)
          @gem_info[gem_name] = {}
          @gem_info[gem_name][:active_version_info] = rubygems_json.select { |v| v["number"] == version }[0]
          @gem_info[gem_name][:latest_version_info] = rubygems_json[0]
        rescue NoMethodError
          @not_found << gem_name
          next
        rescue Gems::NotFound
          @not_found << gem_name
          next
        else
          @gem_info[gem_name][:active_version_number] = @gem_info[gem_name][:active_version_info]["number"]
          @gem_info[gem_name][:latest_version_number] = @gem_info[gem_name][:latest_version_info]["number"]
          @gem_info[gem_name][:active_build_date] = @gem_info[gem_name][:active_version_info]["built_at"]
          @gem_info[gem_name][:latest_build_date] = @gem_info[gem_name][:latest_version_info]["built_at"]
        end
        categorize_gem_age(gem_name)
      end
    end
  end

  def categorize_gem_age(gem_name)
    age = Date.parse(@gem_info[gem_name][:latest_build_date]) - Date.parse(@gem_info[gem_name][:active_build_date])

    if age.to_i.zero?
      fresh << gem_name
    elsif age.to_i.positive? && age.to_i < TWO_YEARS
      stale << gem_name
    elsif age.to_i >= TWO_YEARS && age.to_i < FOUR_YEARS
      crusty << gem_name
    elsif age.to_i >= FOUR_YEARS
      ancient << gem_name
    end
  end

  def output_to_file
    messages = ["#{Date.today.strftime("%Y-%m-%d")}"]
    write_gem_info = lambda do |var|
      var.each do |gem_name|
        messages << "#{gem_name} - Using: #{@gem_info[gem_name][:active_version_number]}, Latest: #{@gem_info[gem_name][:latest_version_number]}"
      end
    end

    unless @ancient.empty?
      messages << "\n4 years old or greater\n"
      write_gem_info.call(@ancient)
    end

    unless @crusty.empty?
      messages << "\nBetween 2 and 4 years old\n"
      write_gem_info.call(@crusty)
    end

    unless @stale.empty?
      messages << "\n2 years old or less\n"
      write_gem_info.call(@stale)
    end

    unless @fresh.empty?
      messages << "\nUp to date gems:\n"
      @fresh.each do |gem_name|
        messages << "#{gem_name}"
      end
    end

    unless @not_found.empty?
      messages << "\nNot hosted on RubyGems\n"
      @not_found.each do |gem_name|
        messages << "#{gem_name}"
      end
    end
    File.write("crusty_gems.txt", messages.join("\n"), mode: "w")
  end
end

dat = Dats.new(ARGV[0], ARGV[1])
dat.run
