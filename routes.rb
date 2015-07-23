require 'sinatra'
require 'firebase'
require 'json'
require 'digest'

require_relative 'helpers'

$base_uri = 'https://h4xchat.firebaseio.com'
$fb_root = Firebase::Client.new($base_uri)
$global_users = Firebase::Client.new($base_uri + "/users")
$hash_key =  $fb_root.get("/key").body.to_s
$cookie_key =  $fb_root.get("/key").body.to_s

# configure :development do
#   set :bind, '0.0.0.0'
#   set :port, 3000
# end


enable :sessions
set :session_secret, $cookie_key

#################$
## PAGE ROUTES #$
###############$

before do
  @time = getTime()
  @username = session['user'] if session['user']
  #@username = "jofuzz"
end



#Get ROOT
get '/' do
  @global_users = $global_users.get("/").body
  @public_rooms = getPublicRooms()
  @user_rooms = getUserRooms(@username)
  erb :index
end


#GET Create a room screan
get '/c/new' do
  
  erb :new
end

#POST Create a room screan
post '/c/new' do
  
  rn = params[:roomname].strip.gsub(/\W+/,'-')
  pp = true if params[:private]
  pp ? pp = true : pp = false
  
  createRoom(rn, @username, pp)
  
  #puts pp.class
  redirect to('/c/' + rn);
end


#GET Room by name
get '/c/:room' do
  @room = params[:room]
  @user_color = getUserData(@username, "color")
  sendView = :noauth
  
  begin
    
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
  
  rescue 
    halt 500
  end
  
end






#GET Add Room
get '/c/add/:roomname' do
  rn = params[:roomname]
  createRoom(rn, @username, false)
  redirect to('/c/' + rn);
end




#Default user page for self
get '/u' do
  @user_color = getUserData(@username, "color")
  erb :user
end


#Defined username (not yet used)
# get '/u/:username' do
#   erb :user
# end


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


#POST Change password
post '/changepass' do
  
  upw = Firebase::Client.new($base_uri + "/users/#{@username}")
  @pass_plus = params[:oldpass] + $hash_key
  pkey = Digest::MD5.hexdigest @pass_plus
  
  if params[:password] != params[:passwordagain] 
    
    @notice = "Passwords don't match"
    erb :user
    
  elsif upw.get("/password").body != pkey
  
    @notice = "The old password you entered is incorrect."
    erb :user
    
  else
    
    @pass_plus = params[:password] + $hash_key
    pkey = Digest::MD5.hexdigest @pass_plus
    upw.update( "/", :password => pkey )
    @notice = "Password changed!"
    erb :user
    
  end
end



#GET Login
get '/login' do
  erb :login
end


#POST login
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


#POST Admin remove from room (AJAX)
post '/admin/remove' do
  uu = params[:user].to_s
  rmm = params[:room].to_s
  
  if !getUserData(uu)
    return "There's no user by the name of #{uu} to remove."
  elsif !getUsersInRoom(rmm)[uu]
    return "That user is not in the room."
  end
  
  begin
    if isAdmin?(@username, rmm)
      removeUsersFromRoom(uu, rmm)
    else 
      return "You aren't allowed to do that."
    end
  rescue
    return "Error happened!"
  end
  
  return "#{uu} removed from #{rmm}!"
end


#POST Admin add to room (AJAX)
post '/admin/add' do
  uu = params[:user].to_s
  rmm = params[:room].to_s
  
  if !getUserData(uu)
    return "There's no user by the name of #{uu} to add."
  elsif getUsersInRoom(rmm)[uu]
    return "That user is already in the room."
  end
  
  begin
  if isAdmin?(@username, rmm)
    addUserToRoom(uu, rmm)
  else 
    return "You aren't allowed to do that!"
  end
  rescue
    return "Error happened!"
  end
  
  return "#{uu} added to #{rmm}!"
end


#POST Admin add to room (AJAX)
post '/admin/grantadmin' do
  
  uu = params[:user].to_s
  rmm = params[:room].to_s
  
  return "There's no user by the name of #{uu}." if !getUserData(uu)
    
  if getUsersInRoom(rmm)[uu]
    begin
    if isAdmin?(@username, rmm)
      addUserToRoom(uu, rmm, true)
      return "#{uu} has been granted admin access for #{rmm}!"
    else 
      return "You aren't allowed to do that!"
    end
    rescue
      return "Error happened!"
    end
  else 
    return "That user isn't in the room yet. Use '/add' to do such a thing."
  end
  
end
 


#Error 500
error 500 do
  erb :error
end


# get '/testcreate' do
#   createRoom("another", "spenser", false)
#   erb :index
# end

