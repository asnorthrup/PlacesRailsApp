class Point

attr_accessor :longitude, :latitude

def to_hash
	{:type=>"Point",:coordinates=>[@longitude,@latitude]} #GeoJSON Point format
end

#initialize a point, pass in parameters of point
def initialize (params={})
	#byebug
	#deep symbolize! wasn't working in place (destructively)
	params=params.deep_symbolize_keys
	if params.key?(:type)
		@longitude = params[:coordinates][0]
		@latitude = params[:coordinates][1]
	else
		@longitude = params[:lng]
		@latitude = params[:lat]
	end

end

end
