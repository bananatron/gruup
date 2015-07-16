require 'sinatra'
require 'firebase'
require 'json'
require 'digest'

base_uri = 'https://h4xchat.firebaseio.com'
$fb_root = Firebase::Client.new(base_uri)
$fb_apps = Firebase::Client.new(base_uri + "/apps")
$fb_users = Firebase::Client.new(base_uri + "/users")
$hash_key =  $fb_root.get("/key").body.to_s
$cookie_key =  $fb_root.get("/key").body.to_s

# configure :development do
#   set :bind, '0.0.0.0'
#   set :port, 3000
# end


#TODO
#Move notices to fb so we can listen for them instead

enable :sessions
set :session_secret, $cookie_key

#################$
## PAGE ROUTES #$
###############$

before do
  @username = session['user']  if session['user']
end


get '/' do
  erb :index
end

get '/color/:hex' do #Change color value for your user - will have user settings later on
  if session['user']
    hex = params[:hex]
    $fb_users.update("/#{session['user']}", :color => hex) if hex.length == 3 || hex.length == 6
  end
  redirect to('/');
end


get '/register' do
  erb :register
end


post '/register' do
  session.clear
  
  if params[:password] != params[:passwordagain] 
    
    @notice = "Passwords don't match"
    erb :register
    
  elsif $fb_users.get("/#{params[:username]}").body
    
    @notice = "Username already exists."
    erb :register
    
  else
  
  @notice = "Register successful, please log in!"
  @username = params[:username]
  @pass_plus = params[:password] + $hash_key
  pkey = Digest::MD5.hexdigest @pass_plus
  time = Time.now.to_s 
  $fb_users.set(@username, :password => pkey, :created_on => time, :color => "%06x" % (rand * 0xffffff))
  #redirect based on cases/validation
  session['user'] = @username
  redirect to('/')
  end
end



get '/login' do
  erb :login
end


post '/login' do
  #redirect based on cases/validation
  username = params[:username]
  pass_plus = params[:password] + $hash_key
  local_pass = Digest::MD5.hexdigest pass_plus
  
  db_pass = $fb_users.get("/" + username + "/password").body
  
  if $fb_users.get("/"+username).body
    if db_pass == local_pass
      session.clear 
      session['user'] = username
      redirect to('/')
    else
      @notice = "Password is wrong"
      erb :login
    end
  else
    @notice = "No user by that name."
    erb :login
  end
end


get '/logout' do 
  session.clear  
  @notice = "Logged out!"
  #erb :index
  redirect to('/')
end




#################$
## API ROUTES ##$
###############$
