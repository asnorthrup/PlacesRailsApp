class AddressComponent
	attr_reader :long_name, :short_name, :types

	#initialize instance variables from hash passed in
	def initialize(params={})
		@long_name=params[:long_name]
		@short_name=params[:short_name]
		@types=params[:types]
	end
end