require 'sinatra'
require 'firebase'
require 'json'

base_uri = 'https://versioner.firebaseio.com'
$fb_apps = Firebase::Client.new(base_uri + "/apps")
$fb_root = Firebase::Client.new(base_uri)

configure :development do
  set :bind, '0.0.0.0'
  set :port, 3000
end

get '/' do
  erb :index
end

get '/apps' do
  @fb = $fb_root
  erb :apps
end

get '/docs' do
  erb :docs
end

get '/submit' do
  erb :submit
end

get '/edit/:guid' do
  @guid = params[:guid]
  r_hash = $fb_apps.get("/"+@guid).body.first[1]
  @app_name = r_hash["app_name"]
  @app_description = r_hash["app_description"]
  @get_link = r_hash["get_link"]
  @version = r_hash["version"]
  @link_description = r_hash["link_description"]
  
  erb :edit  
end


get '/guid/:guid/json' do
  content_type :json
  @guid = params[:guid]
  "asdfasdf"
  @result = $fb_apps.get("/"+@guid).body
end

get '/guid/:guid/text' do
  del = "^"
  content_type :text
  guid = params[:guid]
  r_hash = $fb_apps.get("/"+guid).body.first[1]
  app_name = r_hash["app_name"]
  app_description = r_hash["app_description"]
  get_link = r_hash["get_link"]
  version = r_hash["version"]
  link_description = r_hash["link_description"]
  
  app_name + del + app_description + del + get_link + del + version + del + link_description
end

get '/guid/:guid/text/:del' do
  del = params[:del]
  content_type :text
  guid = params[:guid]
  r_hash = $fb_apps.get("/"+guid).body.first[1]
  app_name = r_hash["app_name"]
  app_description = r_hash["app_description"]
  get_link = r_hash["get_link"]
  version = r_hash["version"]
  link_description = r_hash["link_description"]
  
  app_name + del + app_description + del + get_link + del + version + del + link_description
end

post '/submit/:is_edit' do
  @app_name = params[:app_name]
  @app_description = params[:app_description]
  @guid = params[:guid]
  @version = params[:version]
  @get_link = params[:get_link]
  @link_description = params[:link_description]
  is_edit = params[:is_edit]
  
  $fb_apps.delete(@guid) if is_edit #delete entry if editing, then repush

  $fb_apps.push(@guid, :_id => @id, :app_name => @app_name, :app_description => @app_description, :guid => @guid, :version => @version, :get_link => @get_link, :link_description => @link_description)
  
  redirect to('/apps#' + @app_name.downcase.strip.gsub(/\s+/, "_")) #Add anchor to find app in big list
end





