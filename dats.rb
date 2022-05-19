#Version Age Tracker Script
require "gems"
require "date"
require "pry"

class Dats
  attr_accessor :messages, :gemfile_contents, :ancient, :crusty, :stale, :fresh, :not_found, :gem_info, :date

  def initialize(gemfile, lockfile)
    @gemfile = gemfile
    @lockfile = lockfile
    @messages = []
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
    # binding.pry
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
        next if gem_name == "sidekiq-pro" || gem_name == "StreetAddress"
        version = version.slice(1..-2)
        next unless gemfile_contents.include?(gem_name)

        begin
          rubygems_json = Gems.versions(gem_name)
          # binding.pry
          @gem_info[gem_name] = {}
          @gem_info[gem_name][:active_version_info] = rubygems_json.select { |v| v["number"] == version }[0]
          @gem_info[gem_name][:latest_version_info] = rubygems_json[0]
          # binding.pry
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
        # binding.pry
        categorize_gem_age(gem_name)
      end
    end
  end

  def categorize_gem_age(gem_name)
    age = Date.parse(@gem_info[gem_name][:latest_build_date]) - Date.parse(@gem_info[gem_name][:active_build_date])

    #create contants for time spans
    if age.to_i == 0
      fresh << gem_name
    elsif age.to_i > 0 && age.to_i < 730
      stale << gem_name
    elsif age.to_i >= 730 && age.to_i < 1460
      crusty << gem_name
    elsif age.to_i >= 1460
      ancient << gem_name
    end
  end

  def output_to_file
    unless @fresh.empty?
      puts "Up to date gems:"
      @fresh.each do |gem_name|
        puts "#{gem_name}"
      end
    end

    unless @stale.empty?
      puts "2 years old or less"
      @stale.each do |gem_name|
        # binding.pry
        puts "#{gem_name} - Using: #{@gem_info[gem_name][:active_version_number]}, Latest: #{@gem_info[gem_name][:latest_version_number]}"
      end
    end
    unless @crusty.empty?
      puts "Between 2 and 4 years old"
      @crusty.each do |gem_name|
        puts "#{gem_name} - Using: #{@gem_info[gem_name][:active_version_number]}, Latest: #{@gem_info[gem_name][:latest_version_number]}"
      end
    end

    unless @ancient.empty?
      puts "4 years old or greater"
      @stale.each do |gem_name|
        puts "#{gem_name} - Using: #{@gem_info[gem_name][:active_version_number]}, Latest: #{@gem_info[gem_name][:latest_version_number]}"
      end
    end

    unless @not_found.empty?
      puts "Not hosted on RubyGems"
      @not_found.each do |gem_name|
        puts "#{gem_name}"
      end
    end
  end
end

# gemfile = ARGV[0]
# lockfile = ARGV[1]

# File.write("crusty_gems.txt", messages.join(" "), mode: "w")

dat = Dats.new(ARGV[0], ARGV[1])
dat.run
