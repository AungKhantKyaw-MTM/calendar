class EventsController < ApplicationController
    before_action :set_client, :set_service
  
    def new
      @event = Event.new
    end
  
    def redirect
      @client = Signet::OAuth2::Client.new(client_options)
  
      authorization_url = @client.authorization_uri(
        scope: Google::Apis::CalendarV3::AUTH_CALENDAR
      )
  
      respond_to do |format|
        format.json { render json: { url: authorization_url.to_s } }
        format.html { redirect_to authorization_url.to_s, allow_other_host: true }
      end
    end
  
    def verify_scopes
      token_info = @client.token_info(@client.token)
      puts token_info.scope
    end
  
    def create
      @event = Event.new(event_params)
    
      start_date = Date.parse(params[:event][:start_time])
      start_time = Time.parse(params[:event][:event_start_time])
      @event.start_time = DateTime.new(start_date.year, start_date.month, start_date.day, start_time.hour, start_time.min, start_time.sec)
    
      end_date = Date.parse(params[:event][:end_time])
      end_time = Time.parse(params[:event][:event_end_time])
      
      @event.end_time = DateTime.new(end_date.year, end_date.month, end_date.day, end_time.hour, end_time.min, end_time.sec)
      
      if @event.save
        begin
          create_google_event(@event)
          byebug
          redirect_to events_path, notice: 'Event was successfully created.'
        rescue Google::Apis::AuthorizationError => e
          flash[:alert] = "Authorization error: #{e.message}"
          redirect_to error_path and return
        rescue Google::Apis::ClientError => e
          flash[:alert] = "Client error: #{e.message}"
          redirect_to error_path and return
        end
      else
        render :new
      end
    end    
  
    def index
      @calendar_service = initialize_calendar_service
      calendar_id = 'mtm.aungkhantkyaw@gmail.com'
  
      begin
        @events = @calendar_service.list_events(calendar_id)
      rescue Google::Apis::ClientError => e
        if e.message.include?('notFound')
          flash[:alert] = "Calendar not found."
        else
          flash[:alert] = "An error occurred: #{e.message}"
        end
        redirect_to events_path
      end
    end
  
    def show
      service = Google::Apis::CalendarV3::CalendarService.new
      service.authorization = @client
    
      calendar_id = params[:calendar_id] || "mtm.aungkhantkyaw@gmail.com"
      event_id = params[:id]
    
      if calendar_id.blank?
        flash[:alert] = "Calendar ID is missing."
        redirect_to events_path and return
      end
    
      Rails.logger.debug "Fetching event with Calendar ID: #{calendar_id}, Event ID: #{event_id}"
    
      begin
        @event = service.get_event(calendar_id, event_id)
      rescue Google::Apis::ClientError => e
        Rails.logger.error "Error fetching event: #{e.message}"
        
        if e.message.include?('notFound')
          flash[:alert] = "Event not found."
        else
          flash[:alert] = "An error occurred while fetching the event."
        end
        
        redirect_to events_path
      end
    end

    def edit
      service = Google::Apis::CalendarV3::CalendarService.new
      service.authorization = @client
    
      calendar_id = params[:calendar_id] || "mtm.aungkhantkyaw@gmail.com"
      event_id = params[:id]
    
      begin
        @event = service.get_event(calendar_id, event_id)
      rescue Google::Apis::ClientError => e
        Rails.logger.error "Error fetching event: #{e.message}"
        flash[:alert] = "Event not found."
        redirect_to events_path and return
      end
    end

    def update
      service = Google::Apis::CalendarV3::CalendarService.new
      service.authorization = @client
    
      calendar_id = params[:calendar_id] || "mtm.aungkhantkyaw@gmail.com"
      event_id = params[:id]
    
      start_time = Time.zone.parse("#{params[:start_time]} #{params[:event_start_time]}").utc.iso8601
      end_time = Time.zone.parse("#{params[:end_time]} #{params[:event_end_time]}").utc.iso8601
    
      event_params = {
        summary: params[:summary],
        description: params[:description],
        start: { date_time: start_time, time_zone: 'UTC' },
        end: { date_time: end_time, time_zone: 'UTC' }
      }
    
      begin
        @event = service.update_event(calendar_id, event_id, event_params)
        flash[:notice] = "Event updated successfully."
        redirect_to events_path(calendar_id: calendar_id)
      rescue Google::Apis::ClientError => e
        Rails.logger.error "Error updating event: #{e.message}"
        flash[:alert] = "Failed to update event."
        
        @event = service.get_event(calendar_id, event_id)
        render :edit
      end
    end

    def destroy
      @event = @service.get_event('primary', params[:id])
      @service.delete_event('primary', @event.id)
  
      respond_to do |format|
        format.html { redirect_to events_path, notice: 'Event was successfully deleted.' }
        format.json { head :no_content }
      end
    rescue Google::Apis::ClientError => e
      redirect_to events_path, alert: "Error deleting event: #{e.message}"
    end

    private

    def set_service
      @service = Google::Apis::CalendarV3::CalendarService.new
      @service.authorization = @client
    end
  
    def event_params
      params.require(:event).permit(:title, :description, :start_time, :end_time, :calendar_id, :event_start_time, :event_end_time)
    end
  
    def create_google_event(event)
      service = Google::Apis::CalendarV3::CalendarService.new
      service.authorization = @client
      
      if @client.expired?
        response = @client.refresh!
        session[:authorization] = response
        @client.update!(response)
      end
      
      start_time_utc = event.start_time.utc.iso8601
      end_time_utc = event.end_time.utc.iso8601
      
      google_event = Google::Apis::CalendarV3::Event.new(
        summary: event.title,
        description: event.description,
        start: Google::Apis::CalendarV3::EventDateTime.new(date_time: start_time_utc, time_zone: 'UTC'),
        end: Google::Apis::CalendarV3::EventDateTime.new(date_time: end_time_utc, time_zone: 'UTC')
      )
      byebug
      service.insert_event(event.calendar_id, google_event)
    end
  
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
  
    def initialize_calendar_service
      service = Google::Apis::CalendarV3::CalendarService.new
      service.authorization = @client
      service
    end
  end
  