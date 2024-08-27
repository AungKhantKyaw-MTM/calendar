Rails.application.routes.draw do
  get 'errors/generic_error'
  resources :events do
  end
  
  get '/error', to: 'errors#generic_error'
  get "/redirect", to: "calendars#redirect"
  get "/calendars", to: "calendars#calendars"
  get "/callback", to: "calendars#callback"
end
