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
	#byebug
	if !params[:geometry].key?(:geolocation)
		@location=Point.new(params[:geometry])
	else #created if because tes was pasing in :geometry:geolocation
		@location=Point.new(params[:geometry][:geolocation])
	end	
	
	@address_components=[]
	#byebug
	#address component is an array of hashes that should be created into AddressComponents
	params[:address_components].each {|r| @address_components.push(AddressComponent.new(r))} if params[:address_components]
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
	#byebug
	#iterate over view passed in
	value.each do |v|
		p=Place.new(v)
		results.push(p)
	end

	return results
end

#class method returns instance of Place for supplied id
def self.find s_id
	bson_id=BSON::ObjectId.from_string(s_id)
	found = self.collection.find(:_id=>bson_id).first
	return found.nil? ? nil : Place.new(found)
end

#return all records given an offset and limit
def self.all (offset=nil, limit=nil)
	ret = self.collection.find() if (offset.nil? && limit.nil?)
	ret = self.collection.find().skip(offset) if (!offset.nil? && limit.nil?)
	ret = self.collection.find().limit(limit) if (offset.nil? && !limit.nil?)
	ret = self.collection.find().skip(offset).limit(limit) if (!offset.nil? && !limit.nil?)

	#create new Place out of each
	places=[]
    ret.each do |doc|
      places << Place.new(doc)
    end
    return places
end 

# remove the document associated with this instance form the DB
def destroy
	#Rails.logger.debug {"destroying #{self}"}
	#byebug
	bson_id=BSON::ObjectId.from_string(@id)
	self.class.collection.find(:_id=>bson_id).delete_one
end 

#************Aggregation Query methods start here**********

#retuns collection of hash documents with address_components and their associated
def self.get_address_components(sort={:_id=>1}, offset=0, limit=nil)
	if limit.nil?
	result = self.collection.find.aggregate([
									{:$unwind=>"$address_components"},
									{:$project=>{:address_components=>1,:formatted_address=>1, "geometry.geolocation"=>1}},
									{:$sort=>sort},
									{:$skip=>offset}
									])
	else #because if limit is nil, can't keep in query
	result = self.collection.find.aggregate([
									{:$unwind=>"$address_components"},
									{:$project=>{:address_components=>1,:formatted_address=>1, "geometry.geolocation"=>1}},
									{:$sort=>sort},
									{:$skip=>offset},
									{:$limit=>limit}
									])
	end
	return result
end


#class method that returns a disctinct collection of country names (long_names_
def self.get_country_names
	#byebug
	result=self.collection.find.aggregate([
									{:$project=>{"address_components.long_name"=>1,"address_components.types"=>1, :_id=>0}},
									{:$unwind=>"$address_components"},
									{:$match=>{"address_components.types"=>"country"}},
									{:$group=>{:_id=>"$address_components.long_name"}}
										])
	#byebug
	result.to_a.map{|h| h[:_id]}

end


#return id of each document that the palces collection that has address_component.short_name of type country
#and matches provided parameter
def self.find_ids_by_country_code country_code
	#have i dont the part about tagged with a country type?
	self.collection.find.aggregate([
									{:$match=>{"address_components.short_name":country_code}},
									{:$project=>{:id=>1}},
									]).map { |doc| doc[:_id].to_s }

end

#create 2dsphere index for geospatial analysis
def self.create_indexes
	self.collection.indexes.create_one({"geometry.geolocation"=>"2dsphere"})
end

#remove 2dsphere index, in rails c, Place.collection.indexes.map {|r| r[:name]}
def self.remove_indexes
	self.collection.indexes.drop_one("geometry.geolocation_2dsphere")
end

#returns the places that are closest to the provided point
def self.near(point, max_meters=nil)
	if !max_meters.nil?
		self.collection.find(
			"geometry.geolocation"=>{:$near=>{:$geometry=>point.to_hash, :$maxDistance=>max_meters}}
		)
	else
		self.collection.find(
			"geometry.geolocation"=>{:$near=>{:$geometry=>point.to_hash}}
		)
	end
end


#instance method that wraps the class method of the same name
def near(max_meters=nil)
	#byebug
	if !max_meters.nil?
		result=self.class.collection.find(
			"geometry.geolocation"=>{:$near=>{:$geometry=>@location.to_hash, :$maxDistance=>max_meters}}
		)
	else
		result=self.class.collection.find(
			"geometry.geolocation"=>{:$near=>{:$geometry=>@location.to_hash}}
		)
	end
	#byebug
	return self.class.to_places(result) if result
end


end