# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)
#clear databases

require 'pp'
Photo.mongo_client.database.fs.find.delete_many
Place.collection.find().delete_many

#create geolocation index, no operation if one already exists
Place.create_indexes

#load places
f=File.open("./db/places.json")
Place.load_all(f)

#load photos
Dir.glob("./db/image*.jpg") do |file| 
	photo=Photo.new
	photo.contents=file
	photo.save
end
#associate photos with closest location
Photo.mongo_client.database.fs.find.each do |p|
	#byebug
	photo=Photo.new(p.to_hash)
	#gets id of closest place to where picture was taken
	nearest_place_id=photo.find_nearest_place_id(1609.34)
	#location should be a point, before saving, need find_nearest_place_id returns an id,
	#but need to go get that place before putting to location;
	#place_instance=Place.find(nearest_place) #instance of Places closest to photo
	photo.place=nearest_place_id
	photo.save
end

#pp Place.all.reject {|pl| pl.photos.empty?}.map {|pl| pl.formatted_address}.sort