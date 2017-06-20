class ApplicationController < ActionController::Base
	# Prevent CSRF attacks by raising an exception.
	# For APIs, you may want to use :null_session instead.
	protect_from_forgery with: :exception

	def show
		@photo = Photo.find(params[:id])
		send_data @photo.contents, { type: 'image/jpeg', disposition: 'inline'}
	end

end
