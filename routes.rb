require 'sinatra'
require 'firebase'
require 'json'
require 'digest'

base_uri = 'https://versioner.firebaseio.com'
$fb_root = Firebase::Client.new(base_uri)
$fb_apps = Firebase::Client.new(base_uri + "/apps")
$fb_users = Firebase::Client.new(base_uri + "/users")
$hash_key =  $fb_root.get("/key").body
$cookie_key =  $fb_root.get("/key").body.to_s

configure :development do
  set :bind, '0.0.0.0'
  set :port, 3000
end


enable :sessions
set :session_secret, $cookie_key
#################$
## PAGE ROUTES #$
###############$

get '/session' do
  session['user']
end

get '/' do
  erb :index
end

get '/apps' do
  #@fb = $fb_root
  @fb = $fb_root.get("/apps").body
  erb :apps
end

get '/docs' do
  erb :docs
end

get '/submit' do
  if session['user']
    erb :submit
  else 
    @notice = "You must be logged in."
    erb :login
  end
end

get '/login' do
  erb :login
end

get '/register' do
  erb :register
end


post '/login' do
  #redirect based on cases/validation
  username = params[:username]
  pass_plus = params[:password] + $hash_key
  local_pass = Digest::MD5.hexdigest pass_plus
  
  db_pass = $fb_users.get("/"+ username +"/password").body
  
  if $fb_users.get("/"+username).body
    if db_pass == local_pass
      session['user'] = username
      erb :index
      
    else
      @notice = "Password is wrong"
      erb :login
    end
  else
    @notice = "No user by that name."
    erb :login
  end
end


post '/register' do
  @notice = "Register successful, please log in!"
  @username = params[:username]
  @pass_plus = params[:password] + $hash_key
  pkey = Digest::MD5.hexdigest @pass_plus
  time = Time.now.to_s 
  $fb_users.set(@username, :password => pkey, :created_on => time)
  #redirect based on cases/validation
  erb :login
end

get '/logout' do 
  session.clear  
  @notice = "Logged out!"
  erb :index
end


get '/edit/:guid' do
  @guid = params[:guid]
  r_hash = $fb_apps.get("/"+@guid).body
  
  if session['user']
 
    if session['user'] == r_hash["user"]
      #$r_hash = $fb_apps.get("/"+@guid).body.first[1]
      @app_name = r_hash["app_name"]
      @app_description = r_hash["app_description"]
      @get_link = r_hash["get_link"]
      @version = r_hash["version"]
      @link_description = r_hash["link_description"]
      erb :edit  
    else
      @notice = "You don't have permission to edit that."
      @fb = $fb_root.get("/apps").body
      erb :apps
    end
    
  else
    @notice = "You must be logged in first."
    erb :login
  end
end

post '/submit/:is_edit' do
  @app_name = params[:app_name]
  @app_description = params[:app_description]
  @guid = params[:guid]
  @version = params[:version]
  @get_link = params[:get_link]
  @link_description = params[:link_description]
  @old_guid = params[:old_guid]
  @is_edit = params[:is_edit]

  if session['user']
    $fb_apps.delete(@old_guid) if @old_guid.to_s.length > 0 && @is_edit == "true" #delete entry if editing, then repush
    #$fb_apps.push(@guid, :_id => @id, :app_name => @app_name, :app_description => @app_description, :guid => @guid, :version => @version, :get_link => @get_link, :link_description => @link_description, :user => session['user'])
    $fb_apps.set(@guid, :_id => @id, :app_name => @app_name, :app_description => @app_description, :guid => @guid, :version => @version, :get_link => @get_link, :link_description => @link_description, :user => session['user'])
    redirect to('/apps#' + @app_name.downcase.strip.gsub(/\s+/, "_")) #Add anchor to find app in big list
  else
    @notice = "You must be logged in first."
    erb :login
  end
end




#################$
## API ROUTES ##$
###############$

get '/guid/:guid/json' do
  content_type :json
  @guid = params[:guid]
  "asdfasdf"
  @result = $fb_apps.get("/"+@guid).body.to_json
end


get '/guid/:guid/field/:field' do
  content_type :text
  guid = params[:guid]
  field = params[:field]
  r_hash = $fb_apps.get("/"+guid).body
  results = r_hash[field]
  results
end

get '/guid/:guid/fields' do
  content_type :text
  guid = params[:guid]
  r_hash = $fb_apps.get("/"+guid).body
  results = []
  
  r_hash.each do |k, v|
    results << k if v.length > 0
  end
  
  results.join(",")
end


get '/guid/:guid/text' do
  del = "^"
  content_type :text
  guid = params[:guid]
  r_hash = $fb_apps.get("/"+guid).body
  app_name = r_hash["app_name"]
  app_description = r_hash["app_description"]
  get_link = r_hash["get_link"]
  version = r_hash["version"]
  link_description = r_hash["link_description"]
  results = app_name + del + app_description + del + get_link + del + version + del + link_description
  
  results
end

get '/guid/:guid/text/:del' do
  del = params[:del]
  content_type :text
  guid = params[:guid]
  r_hash = $fb_apps.get("/"+guid).body
  app_name = r_hash["app_name"]
  app_description = r_hash["app_description"]
  get_link = r_hash["get_link"]
  version = r_hash["version"]
  link_description = r_hash["link_description"]
  
  app_name + del + app_description + del + get_link + del + version + del + link_description
end






