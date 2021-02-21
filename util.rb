require "json"
require "yaml"

def remove_duplicate(data)
  return data.uniq { |x| x["url"] }
end

def remove_well_known_url(data, pattern)
  return data.reject { |x| pattern.include?(x["url"]) }
end

def replace_null_title(data)
  f = lambda { |x|
    if x["title"].nil? || x["title"].empty?
      x["title"] = x["url"]
    end

    return x
  }

  data.map { |e| f.call(e) }
end

if __FILE__ == $0
  DATA_DIR = "public/data"

  File.open("well_known_url.yaml", "r") do |f|
    d = YAML.load(f)
    @well_known_pattern = d.map { |x| x["url"] }
  end

  Dir.each_child(DATA_DIR) do |fn|
    file_path = File.join(DATA_DIR, fn)

    File.open(file_path, "r") do |f|
      @org = JSON.load(f)
    end

    File.open(file_path, "w") do |f|
      filterd = remove_duplicate(@org)
      filterd = remove_well_known_url(filterd, @well_known_pattern)
      filterd = replace_null_title(filterd)
      f.write(JSON.pretty_generate(filterd))
      puts("#{file_path}: remove #{@org.length - filterd.length} items")
    end
  end
end
