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
	else              #assume hash came from Rails
     	@id=params[:id] #if hash didn't come from GridFS, use that otherwise just take what was given from rails scallfold
     	@location=params[:metadata].nil? ? nil : Point.new(params[:metadata][:location])
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
		#store the data contents in GridFS, @contents should have file
		if @contents
			Rails.logger.debug {"contents= #{@contents}"}
			grid_file = Mongo::Grid::File.new(@contents.read, description )
			id=self.class.mongo_client.database.fs.insert_one(grid_file)
			@id=id.to_s
			#Rails.logger.debug {"saved gridfs file #{id}"}
			#store the generated _id for the file in the :id property of the Photo model instance
			@id
		end
	end
end

def self.all(offset=0,limit=nil)
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

def self.find(id)
	id=BSON::ObjectId.from_string(id)
	ph=mongo_client.database.fs.find(:_id=>id).first
	#byebug
	#if ph
	#	@id=ph[:_id].to_s
	#	@location=ph[:metadata][:location]
	#end
	return ph.nil? ? nil : Photo.new(ph)
end



end