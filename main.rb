require "json"
require "net/http"
require "uri"
require "time"

require_relative("util.rb")

DRY_RUN = false

class GuruLinkAggregator
  attr_reader :max_id, :min_id, :created_at, :count
  @@base_uri = "https://mstdn.guru/api/v1"
  def initialize(resourse)
    @uri = URI.parse("#{@@base_uri}#{resourse}")
    @params = {:local => true, :limit => 40}
    @count = 0
  end

  def aggregate
    @uri.query = URI.encode_www_form(@params)
    res = Net::HTTP.get_response(@uri)
    body = JSON.parse(res.body)
    # Remove bot
    body = body.reject { |x| x.dig("account", "bot") }
    data = self.extract_link(body)
    @max_id = data.min_by { |x| x["created_at"] }.fetch("id")

    if @count == 0
      @min_id, @created_at = data.max_by { |x| x["created_at"] }.fetch_values("id", "created_at")
    end

    @params.update({:max_id => @max_id})
    @count += 1
    return data
  end

  def extract_link(body)
    data = body.map { |x|
      {
        "id" => x.dig("id"),
        "created_at" => Time.parse(x.dig("created_at")),
        "url" => x.dig("card", "url"),
        "title" => x.dig("card", "title")
      }
    }

    return data
  end
end

def load_meta(file_name)
  meta = Hash

  File.open(file_name, "r") do |f|
    meta = JSON.load(f)
  end

  puts("Previous run: #{meta["created_at"]}")
  to_time = lambda { |x|
    if x.empty?
      nil
    else
      Time.parse(x)
    end
  }

  meta["created_at"] = to_time.call(meta["created_at"])

  return meta
end

def save_meta(file_name, meta)
  File.open(file_name, "w") do |f|
    f.write(JSON.pretty_generate(meta))
    puts("Current run: #{meta["created_at"]}")
  end
end

def save_data(file_base_name, data, pattern)
  file_path = "public/data/#{file_base_name}.json"

  filterd = remove_duplicate(data)
  filterd = remove_well_known_url(filterd, pattern)
  filterd = replace_null_title(filterd)
  filterd.sort_by! { |x| x["created_at"] }

  if File.exist?(file_path)
    File.open(file_path, "r+") do |f|
      prev = JSON.load(f)
      f.seek(0)
      f.write(JSON.pretty_generate(prev + filterd))
      puts("#{file_path}: #{filterd.length} new items")
    end
  else

    File.open(file_path, "w") do |f|
      f.write(JSON.pretty_generate(filterd))
      puts("#{file_path}: #{filterd.length} new items")
    end
  end
end

def load_well_known_pattern(filename)
  File.open(filename, "r") do |f|
    d = YAML.load(f)
    return d.map { |x| x["url"] }
  end
end

ENV["TZ"] = "Asia/Tokyo"

meta = load_meta("META.json")
well_known_pattern = load_well_known_pattern("well_known_url.yaml")

guru = GuruLinkAggregator.new("/timelines/public")
data = Hash.new { |hash, key| hash[key] = Array.new }

if meta["created_at"].nil?
  d = guru.aggregate

  d.reject { |x| x["url"].nil? }.each do |e|
    date_jst = e["created_at"].getlocal.strftime("%Y%m%d")
    data[date_jst] << e
  end
else

  flg = true
  while flg
    d = guru.aggregate

    d.each do |e|
      if e["id"] == meta["id"] || e["created_at"] <= meta["created_at"]
        flg = false
        next
      end

      unless e["url"].nil?

        date_jst = e["created_at"].getlocal.strftime("%Y%m%d")
        data[date_jst] << e
      end
    end
  end
end

unless DRY_RUN
  data.each do |k, v|
    save_data(k, v, well_known_pattern)
  end

  meta["id"] = guru.min_id
  meta["created_at"] = guru.created_at

  save_meta("META.json", meta)
end
