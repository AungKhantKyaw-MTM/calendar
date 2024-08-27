class CalendarsController < ApplicationController
    before_action :set_client, only: [:redirect, :callback, :events, :calendars]
  
    def redirect
      @client = Signet::OAuth2::Client.new(client_options) # Initialize the client here
        
      respond_to do |format|
        format.json { render json: { url: @client.authorization_uri.to_s } }
        format.html { redirect_to @client.authorization_uri.to_s, allow_other_host: true }
      end
    end
      
    def callback
        authorization_code = params[:code]
        @client.code = authorization_code
      
        response = @client.fetch_access_token!
        session[:authorization] = response
      
        redirect_to calendars_url
    end
  
    def events
      service = Google::Apis::CalendarV3::CalendarService.new
      service.authorization = @client
  
      @event_list = service.list_events(params[:calendar_id])
    rescue Google::Apis::AuthorizationError
      response = @client.refresh!
      session[:authorization] = session[:authorization].merge(response)
      retry
    end
  
    def calendars
        service = Google::Apis::CalendarV3::CalendarService.new
        service.authorization = @client
    
        begin
          @calendar_list = service.list_calendar_lists
        rescue Google::Apis::AuthorizationError => e
          flash[:alert] = "Authorization error: #{e.message}"
          redirect_to error_path and return
        rescue Google::Apis::ClientError => e
          flash[:alert] = "Client error: #{e.message}"
          redirect_to error_path and return
        end
    end
  
    private
  
    def set_client
        @client = Signet::OAuth2::Client.new(client_options)
        @client.update!(session[:authorization]) if session[:authorization]
    end
    
    def client_options
        {
          client_id: ENV.fetch("GOOGLE_CLIENT_ID", ""),
          client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET", ""),
          authorization_uri: "https://accounts.google.com/o/oauth2/auth",
          token_credential_uri: "https://oauth2.googleapis.com/token",
          scope: Google::Apis::CalendarV3::AUTH_CALENDAR,
          redirect_uri: callback_url
        }
    end
end