require 'json'

class Place
#strings: id, formatted address
#Points: location
#collection of AddressComponents: address_components
attr_accessor :id, :formatted_address, :location, :address_components


#initialize Place that can set the attributes from a hash with keys _id, address_components,
#formatted_address and geometry.geolocation. 
#use .to_s to convert a BSON::ObjectId to a string and BSON::ObjectId.from_string(s) to convert
#it back
def initialize(params={})
	#byebug
	params.symbolize_keys!
	@id=params[:_id].to_s
	@formatted_address=params[:formatted_address]
	#locations are point classes, create from hash passed in
	@location=Point.new(params[:geometry])
	@address_components=[]
	#address component is an array of hashes that should be created into AddressComponents
	params[:address_components].each {|r| @address_components.push(AddressComponent.new(r))}
	#o=nil
end

# class method that returns a Mongo DB client from Mongoid referencing
# the default database from the config/mongoid.yml file
def self.mongo_client
	Mongoid::Clients.default
end

# class method that returns a reference to places collection
def self.collection
	self.mongo_client['places'] #use mongo_client class method
end

# bulk load JSON document with places info into the places collection
# accepts type IO w JSON string of data and reads data from input paramter, parses JSON string
# into ruby hash objects of places and inserts the array of hash objects into
# places collection
def self.load_all inputJSON
	#mongoimport --drop --db test --collection places places.json
	file=File.read(inputJSON)
	parsed_response=JSON.parse(file)
	self.collection.insert_many(parsed_response)
end

#************Query methods start here**********
#find within the places collection, address components that contain that short name
#note that instance variable address_components contains a collection of AddressComponents
def self.find_by_short_name sname
	self.collection.find({"address_components.short_name":sname})
end

#pass in Mongo::Collection::View and create new place out of each, return collection
def self.to_places(value)
	results=[]
	#iterate over view passed in
	value.each do |v|
		p=Place.new(v)
		results.push(p)
	end

	return results
end

end