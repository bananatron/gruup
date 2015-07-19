require 'sinatra'
require 'firebase'
require 'json'
require 'digest'

$base_uri = 'https://h4xchat.firebaseio.com'
$fb_root = Firebase::Client.new($base_uri)
$global_users = Firebase::Client.new($base_uri + "/users")
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
  @time = getTime()
  @username = session['user'] if session['user']
  #@username = 'jofuzz'
end

#Get ROOT
get '/' do
  @room_list = "get public rooms from firebase"
  erb :index
end


post '/admin/remove' do
  uu = params[:user].to_s
  rmm = params[:room].to_s
  
  if !getUserData(uu)
    return "There's no user by the name of #{uu} to remove."
  elsif !getUsersInRoom(rmm)[uu]
    return "That user is not in the room."
  end
  
  begin
    removeUsersFromRoom(uu, rmm)
  rescue
    return "Error happened!"
  end
  
  return "#{uu} removed from #{rmm}!"
  
end

post '/admin/add' do
  uu = params[:user].to_s
  rmm = params[:room].to_s
  
  if !getUserData(uu)
    return "There's no user by the name of #{uu} to add."
  elsif getUsersInRoom(rmm)[uu]
    return "That user is already in the room."
  end
  
  begin
    addUserToRoom(uu, rmm)
  rescue
    return "Error happened!"
  end
  
  return "#{uu} added to #{rmm}!"
  
end

#GET Room by name
get '/c/:room' do
  @room = params[:room]
  @user_color = getUserData(@username, "color")
  sendView = :noauth
  
  #begin
    
    @chat_users = getUsersInRoom(@room)
    @private = roomPrivate?(@room) 
    @admin = false
    
    if @private #Private room - check access
        
        if @chat_users[@username] != nil #User has access
            
            @admin = isAdmin?(@username, @room)
            puts 'lol'
            puts @admin
            sendView = :chat
        else #User isn't allowed in
            @chat_users = []
            sendView = :noauth
        end
      
    else #Public room - send them through
        sendView = :chat
    end
    
    erb sendView
  
  #rescue 
  #  halt 500
  #end
  
end


#Change color
get '/color/:hex' do #Change color value for your user - will have user settings later on
  if session['user']
    hex = params[:hex]
    $global_users.update("/#{session['user']}", :color => hex) if hex.length == 3 || hex.length == 6
  end
  redirect to('/');
end


#GET Register new account
get '/register' do
  erb :register
end


#POST Register new account
post '/register' do
  session.clear
  
  if params[:password] != params[:passwordagain] 
    
    @notice = "Passwords don't match"
    erb :register
    
  elsif $global_users.get("/#{params[:username]}").body
  
    @notice = "Username already exists."
    erb :register
    
  else
    
    @notice = "Register successful, please log in!"
    @username = params[:username].downcase
    @pass_plus = params[:password] + $hash_key
    pkey = Digest::MD5.hexdigest @pass_plus
    $global_users.set(@username, :password => pkey, :created_on => @time, :color => "%06x" % (rand * 0xffffff))
    #redirect based on cases/validation
    session['user'] = @username
    redirect to('/')
    
  end
end


#GET Login
get '/login' do
  erb :login
end


#Post login
post '/login' do
  #redirect based on cases/validation
  username = params[:username].downcase
  pass_plus = params[:password] + $hash_key
  local_pass = Digest::MD5.hexdigest pass_plus
  
  db_pass = $global_users.get("/" + username + "/password").body
  
  if $global_users.get("/"+username).body
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



#GET Logout
get '/logout' do 
  session.clear  
  @notice = "Logged out!"
  #erb :index
  redirect to('/')
end


#GET Changelog
get '/changelog' do 
  erb :changelog
end


#Error 500
error 500 do
  erb :error
end




###############$
## HELPERS  ##$ 
#############$

#Move these somewhere else at some point
#!! Convert these to use the one firebase object

def getUserData(user, data=nil)
  if data
    return $fb_root.get("users/#{user}/#{data}").body
  else 
    return $fb_root.get("users/#{user}").body
  end
end


def roomPrivate?(room)
  $fb_root.get("/chats/#{room}/private").body
end


def isAdmin?(user, room)
  return $fb_root.get("chats/#{room}/users/#{user}/admin").body
end


def addUserToRoom(user, room, admin=false )
  $fb_root.set(  "/chats/#{room}/users/#{user}", :admin => admin, :added_on => getTime() )
end

def removeUsersFromRoom(user, room, message=nil )
  $fb_root.delete(  "/chats/#{room}/users/#{user}" )
end


def getUsersInRoom(room) 
  user_list = {}
  cc = Firebase::Client.new($base_uri + '/chats/' + room +  "/users")
  
  cc.get('/').body.each do |user, user_data|
    user_list[user] = user_data
  end
  
  return user_list
  
end


def getTime() #Rethink time formatting to make consistent with js?
  Time.now.to_s 
end




#################$
## API ROUTES ##$
###############$
