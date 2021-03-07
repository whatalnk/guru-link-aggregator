require "json"
require "net/http"
require "uri"
require "time"
require "logger"

DATA_DIR = "public/data"

# oldest id in json - 1
MIN_ID = "105713179384244011"

# latest id in json
MAX_ID = "105843975149639250"

@logger = Logger.new(STDOUT)

def get_timeline(id)
  uri = URI.parse("https://mstdn.guru/api/v1/timelines/public")
  params = {:local => true, :limit => 40, :min_id => id}
  uri.query = URI.encode_www_form(params)
  res = Net::HTTP.get_response(uri)
  body = JSON.parse(res.body)
  return body
end

def extract_bot_entries
  curr = MIN_ID
  ret = []
  flag = false
  @logger.info("Start: extract_bot_entries")
  cnt = 0
  while true
    body = get_timeline(curr)
    cnt += 1
    data = body.map { |x|
      {
        "id" => x.fetch("id"),
        "created_at" => Time.parse(x.fetch("created_at")),
        "bot" => x.dig("account", "bot")
      }
    }

    data.each do |x|
      ret << x.fetch("id") if x.fetch("bot")
      flag = true if x.fetch("id") == MAX_ID
    end

    if cnt % 20 == 0
      @logger.info("#{data[0].fetch("created_at")}, Bot entries: #{ret.length}")
    end

    break if flag
    curr = data.max_by { |x| x["created_at"] }.fetch("id")

    if cnt % 250 == 0
      sleep(310)
    end
  end

  @logger.info("End: extract_bot_entries")
  return ret
end

if __FILE__ == $0
  id_reject = extract_bot_entries

  File.open("id_reject.txt", "w") do |f|
    f.puts(id_reject)
  end

  Dir.each_child(DATA_DIR) do |fn|
    file_path = File.join(DATA_DIR, fn)

    File.open(file_path, "r") do |f|
      @org = JSON.load(f)
      @logger.info("#{fn}: #{@org.length} entries")
    end

    filtered = @org.reject { |x| id_reject.include?(x.fetch("id")) }

    File.open(file_path, "w") do |f|
      f.write(JSON.pretty_generate(filtered))
      @logger.info("#{fn}: Removed #{@org.length - filtered.length} entries")
    end
  end
end
