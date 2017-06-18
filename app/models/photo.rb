class Photo

#id is string of the GridFS file _id attribute, location is a point for where photo was taken
attr_accessor :id, :location
#used to import and access the raw data of the photo. Data type varies depending on context.
attr_writer :contents

#retunrs a mongoDB Client from mongoid referenceing the default database from config/mongoid.yml
def self.mongo_client
	Mongoid::Clients.default
end

#take propoerties
def initialize(params={})
	Rails.logger.debug {"instantiating GridFsFile #{params}"}
	#byebug
    #info from gridFS
	if params[:_id]  #hash came from GridFS, has _id
		@id=params[:_id].to_s 
		@location=params[:metadata].nil? ? nil : Point.new(params[:metadata][:location])
		@place=params[:metadata].nil? ? nil : params[:metadata][:place]
	else              #assume hash came from Rails
     	@id=params[:id] #if hash didn't come from GridFS, use that otherwise just take what was given from rails scallfold
     	@location=params[:metadata].nil? ? nil : Point.new(params[:metadata][:location])
     	@place=params[:metadata].nil? ? nil : params[:metadata][:place]
	end


end

#returns ture if the instance has been created within GridFS
def persisted?
	!@id.nil?
end

def save
	if !self.persisted?
		Rails.logger.debug {"saving gridfs file #{self.to_s}"}
		description={}
		description[:metadata]={}
		#extract geolocation information from jpeg file stored in contents
		gps=EXIFR::JPEG.new(@contents).gps
		#gps object can be inspected for latitude and longitude properties that instantiate
		#the Point class. Point class can product a location in GeoJSON Point format, which
		#can be stored in meta data properties of file in the location property.
		@location=Point.new(:lng=>gps.longitude, :lat=>gps.latitude)
		description[:metadata][:location]=@location.to_hash
		#store the content type of image/jpeg to GridFS contentType
		description[:content_type]="image/jpeg"
		#save the place information to record
		description[:metadata][:place]=@place

		#call rewind between EXIFR and GridFS since they will be reading the same file
		@contents.rewind

		#store the data contents in GridFS, @contents should have file
		if @contents
			Rails.logger.debug {"contents= #{@contents}"}
			grid_file = Mongo::Grid::File.new(@contents.read, description )
			#call rewind between EXIFR and GridFS since they will be reading the same file
			@contents.rewind
			id=self.class.mongo_client.database.fs.insert_one(grid_file)
			@id=id.to_s
			#Rails.logger.debug {"saved gridfs file #{id}"}
			#store the generated _id for the file in the :id property of the Photo model instance
			@id
		end
	else
		b_id=BSON::ObjectId.from_string(@id)
		#updated saved location
		loc_hash=@location.to_hash
		self.class.mongo_client.database.fs.find(:_id=>b_id)
										.update_one('$set'=>{"metadata.location"=>loc_hash})
		#byebug
		#update saved place
		self.class.mongo_client.database.fs.find(:_id=>b_id)
										.update_one('$set'=>{"metadata.place"=>@place})
		#byebug
	end
end

def self.all(offset=0,limit=nil)
	#byebug
    files=[]
    if limit
    	mongo_client.database.fs.find.skip(offset).limit(limit).each do |r| 
  	    	files << Photo.new(r)
  		end
    else
		mongo_client.database.fs.find.skip(offset).each do |r| 
  	    	files << Photo.new(r)
  		end
    end
    return files
end

#given id number of photo, finds it in collection
def self.find(id)
	#byebug
	id=BSON::ObjectId.from_string(id)
	ph=mongo_client.database.fs.find(:_id=>id).first
	#byebug
	#if ph
	#	@id=ph[:_id].to_s
	#	@location=ph[:metadata][:location]
	#end
	return ph.nil? ? nil : Photo.new(ph)
end
  #once we click insert, to show it was successfully updated, it goes and finds one
  # which was id that was just assigned and return the data to the browser. Uses find one to
  # find file object matching criteria
def contents
	Rails.logger.debug {"getting gridfs content #{@id}"}
    f=self.class.mongo_client.database.fs.find_one(:_id=>BSON::ObjectId.from_string(@id))
    # read f into buffer, array of chunks is reduced to single buffer and returned to caller.
    # this is how file is broken apart and put together and assembled. Buffer is sent back to browser
    # to disaply on the screen
    if f 
      buffer = ""
      f.chunks.reduce([]) do |x,chunk| 
          buffer << chunk.data.data 
      end
      return buffer
    end 

end


def destroy
	Rails.logger.debug {"destroying gridfs file #{@id}"}
	self.class.mongo_client.database.fs.find(:_id=>BSON::ObjectId.from_string(@id)).delete_one
end

#photo herlper instance method that returns the _id of the document within the places collection. This
#place document must be within a specified distance threshold of where the photo was taken.
def find_nearest_place_id max_dist
	#byebug
	phot=self.class.find(@id)
	phot=phot.location
	phot=Place.near(phot,max_dist).projection(:_id=>1).first
	return phot[:_id]
end

#custom getter that finds and returns place instance that represents the stored id
def place
	@place.nil? ? nil : Place.find(@place.to_s)
	
end

#custom setter that will update the place ID by accepting a BSON::ObjectId, String or Place instance
def place=(set_place)
	#derive BSON::ObjectId from what is passed in for all 3 cases
	if set_place.is_a?(Place)
		@place=BSON::ObjectId.from_string(set_place.id)
	elsif set_place.is_a?(String)
		@place=BSON::ObjectId.from_string(set_place)
	else #should already be BSON::ObjectId
		@place=set_place
	end
end

#class method that accepts BSON objectid or a string of a place and returns a 
#collection view of photo documents that have the foreign key reference.
def self.find_photos_for_place place_id
	#byebug
	place_id=BSON::ObjectId.from_string(place_id) if place_id.is_a?(String)
	mongo_client.database.fs.find('metadata.place'=>place_id)
end

end