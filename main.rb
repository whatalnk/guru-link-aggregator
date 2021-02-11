require "json"
require "net/http"
require "uri"
require "time"

DRY_RUN = true

class GuruLinkAggregator
  attr_reader :max_id, :created_at
  @@base_uri = "https://mstdn.guru/api/v1"
  def initialize(resourse)
    @uri = URI.parse("#{@@base_uri}#{resourse}")
    @params = {:local => true, :limit => 40}
  end

  def aggregate
    @uri.query = URI.encode_www_form(@params)
    res = Net::HTTP.get_response(@uri)
    body = JSON.parse(res.body)
    data = self.extract_link(body)
    @max_id = data.min_by { |x| x[:created_at] }.fetch(:id)
    @min_id, @created_at = data.max_by { |x| x[:created_at] }.fetch_values(:id, :created_at)
    @params.update({:max_id => @max_id})
    return data
  end

  def extract_link(body)
    data = body.map { |x|
      {
        :id => x.dig("id"),
        :created_at => Time.parse(x.dig("created_at")),
        :url => x.dig("card", "url"),
        :title => x.dig("card", "title")
      }
    }

    return data
  end
end

def load_meta(file_name)
  meta = Hash

  File.open(file_name, "r") do |f|
    meta = JSON.load(f)

    if meta["created_at"].empty?
      meta["created_at"] = nil
    else
      meta["created_at"] = Time.parse(meta["created_at"])
    end
  end

  return meta
end

if $0 == __FILE__
  ENV["TZ"] = "Asia/Tokyo"

  meta = load_meta("META.json")
  guru = GuruLinkAggregator.new("/timelines/public")
  data = Hash.new { |hash, key| hash[key] = Array.new }

  if meta["created_at"].nil?
    d = guru.aggregate

    d.reject { |x| x[:url].nil? }.each do |e|
      date_jst = e[:created_at].getlocal.strftime("%Y%m%d")
      data[date_jst] << e
    end
  else

    flg = true
    while flg
      d = guru.aggregate

      d.each do |e|
        if e[:id] == meta["id"] || e[:created_at] <= meta["created_at"]
          flg = false
          next
        end

        unless e[:url].nil?

          date_jst = e[:created_at].getlocal.strftime("%Y%m%d")
          data[date_jst] << e
        end
      end
    end
  end

  p(data)

  unless DRY_RUN
    data.each do |k, v|
      file_path = "data/#{k}.json"

      if File.exist?(file_path)
        File.open(file_path, "r+") do |f|
          prev = JSON.load(f)
          f.seek(0)
          JSON.dump(prev + v, f)
        end
      else

        File.open(file_path, "w") do |f|
          JSON.dump(v, f)
        end
      end
    end

    meta["id"] = guru.min_id
    meta["created_at"] = guru.created_at

    File.open("META.json", "w") do |f|
      JSON.dump(meta, f)
    end
  end
end
