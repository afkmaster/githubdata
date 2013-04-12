require 'open-uri'
require 'zlib'
require 'yajl'
require 'pp'
require 'date'
require 'octokit'
require 'geocoder'

def check_user(username)
  client = Octokit::Client.new(:login => "afkmaster", :password => "omfgwtfbbq5")
  begin
    check = client.user(username)
  rescue
    return false
  end
  return true
end

def find_users()
  require 'yajl'
  require 'zlib'
  require 'open-uri'
  client = Octokit::Client.new(:login => "afkmaster", :password => "omfgwtfbbq5")
  gz = open('http://data.githubarchive.org/2013-04-08-23.json.gz')
  js = Zlib::GzipReader.new(gz).read

  locations = ""
  push_event_count = 0
  link_count = 0
  userLocations = []
  Yajl::Parser.parse(js) do |event|
    if link_count == 5
      break
    end

    if event["type"] != "PushEvent"
      # puts "|"
      next
    else
      push_event_count += 1
      # puts "."
    end

    actor = event["actor_attributes"]["login"]

    repository = event["repository"]
    owner = repository["owner"]

    if actor == owner
      next
    end

    actor_location = event["actor_attributes"]["location"]

    if actor_location.nil? || actor_location == ""
      next
    end
    
    begin
      owner_location = client.user(owner).location

      if owner_location.nil? || owner_location == ""
        next
      end

      if actor_location.downcase == owner_location.downcase
        next
      end

      # File.open("location.txt", "a") do |f|
      #   f.write("#{actor_location}:#{owner_location}\n")
      # end
      # locations << ":#{actor_location}|#{owner_location}"
      # print "ACTOR LOCATION, ", actor_location, " ------- OWNER LOCATION, ", owner_location, "\n\n"
      userLocations << [actor_location, owner_location]
      link_count += 1
    rescue
      puts "error"
    end
  end
  return userLocations
end

def find_locations(array)
  #creates [name, Hash{lat => #, lng => #}]
  nameAndCoordinates = []
  array.each do |location|
    # location.strip!
    # print "THE LOCATION ---- ", location, "\n\n"
    search = Geocoder.search("#{location}")
    search.each do |place|
      begin
        type = place.data["address_components"][0]["types"][0]
        if type == "locality"
          name = place.data["address_components"][0]["long_name"]
          coordinates = place.geometry["location"]
          nameAndCoordinates << [name, coordinates]
          break
        else
          next
        end
      rescue
        puts "ERROR ERROR ERROR ERROR ERROR"
      end
    end
  end
  return nameAndCoordinates
end

def create_locations()
  # File.open("cities.txt", "w")
  # File.open("coordinates.txt", "w")
  userLocations = find_users()
  fixedLocations = []
  # print "THE STUIPD ACTUAL FUCKING USER LOCATION: ", userLocations, "\n\n\n"
  userLocations.each do |line|
    # print "USER LOCATIONS IN CREATE: ", line, "\n\n\n"
    # puts "USER LOCATIONS IN CREATE: #{line} \n\n\n"
    pusher = line[0]
    owner = line[1]
    pusher = pusher.split(", ")
    owner = owner.split(", ")
    # print "PUSHER: ", pusher, "\n"
    # print "OWNER: ", owner, "\n\n"
    pusher_coordinates = find_locations(pusher)
    owner_coordinates = find_locations(owner)
    pusher_coordinates.each do |x|
      owner_coordinates.each do |y|
        if x[0].downcase == y[0].downcase
          next
        else
          fixedLocations << [x, y]
          # File.open("cities.txt", "a") do |f|
          #   f.write("#{x[0]}, #{y[0]}\n")
          # end
          # File.open("coordinates.txt", "a") do |f|
          #   #from:to
          #   #lat,lng:lat,lng
          #   f.write("#{x[1]["lat"]},#{x[1]["lng"]}:#{y[1]["lat"]},#{y[1]["lng"]}\n")
          # end
        end
      end
    end
  end
  return fixedLocations
end

def convert_coordinates()
  # file = File.open("coordinates.txt", "r")
  cities = Hash.new
  cityCoord = Hash.new
  coordinates = Hash.new
  locations = create_locations()
  locations.each do |line|
    from = line[0]
    from_name = from[0]
    from_latitude = from[1]["lat"]
    from_longitude = from[1]["lng"]
    from_coordinates = {"lat" => from_latitude, "lng" => from_longitude}
    to = line[1]
    to_name = to[0]
    to_latitude = to[1]["lat"]
    to_longitude = to[1]["lng"]
    to_coordinates = {"lat" => to_latitude, "lng" => to_longitude}
    # print "FROM LOCATION: ", from, " TO LOCATION: ", to, "\n\n"
    # print "FROM LOCATION NAME: ", from_name, " TO LOCATION NAME: ", to_name, "\n\n"

    if city_coord[from_name].nil? 
      city_coord[from_name] = from_coordinates
      print "CITY COORD HASH: ", city_coord, "\n\n"
    end

    if city_coord[to_name].nil?
      city_coord[to_name] = to_coordinates
      print "CITY COORD HASH: ", city_coord, "\n\n"
    end

    if cities[from_name].nil?
      cities[from_name] = 1
    else
      cities[from_name] = cities[from_name] + 1
    end
    if cities[to_name].nil?
      cities[to_name] = 1
    else
      cities[to_name] = cities[to_name] + 1
    end
    fromAndToCoordinates = [from_coordinates, to_coordinates]
    if coordinates[fromAndToCoordinates].nil?
      coordinates[fromAndToCoordinates] = 1
    else
      coordinates[fromAndToCoordinates] = coordinates[fromAndToCoordinates] + 1
    end
  end
  print "CITY JSON: ", cities.to_json, "\n"
  print "CITY COORD JSON ", cityCoord.to_json, "\n"
  print "COORDINATES JSON ", coordinates.to_json, "\n"
  return cities.to_json, cityCoord.to_json, coordinates.to_json
  # return cities, city_coord, coordinates
end