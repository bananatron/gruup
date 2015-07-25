#//////////////
#// HELPERS //
#////////////


def getPublicRooms()
  public_rooms = {}
  $fb_root.get("/chats").body.each do |roomname, roomdata|
    public_rooms[roomname] = roomdata.tap { |rd| rd.delete("messages") } if roomdata["private"] == false
  end
  
  return public_rooms
end


def getUserRooms(username)
  user_rooms = {}
  
  $fb_root.get("/chats").body.each do |roomname, roomdata| #Return room data minus messages
    user_rooms[roomname] = roomdata.tap { |rd| rd.delete("messages") } if roomdata["private"] == true && roomdata["users"][username]
  end
  
  return user_rooms
end


def getUserData(user, data=nil)
  return false if !user || user == ""
  if data
    return $fb_root.get("/users/#{user}/#{data}").body
  else 
    return $fb_root.get("/users/#{user}").body
  end
end


def roomPrivate?(room)
  $fb_root.get("/chats/#{room}/private").body
end

def getChatData(room)
  $fb_root.get("/chats/#{room}").body
end


def isAdmin?(user, room)
  return $fb_root.get("chats/#{room}/users/#{user}/admin").body
end

def changeRoomStatus(room, priv=false)
  $fb_root.update(  "/chats/#{room}", :private => priv)
end

def createRoom(room_name, admin, private=false)
  $fb_root.set(  "/chats/#{room_name}", :private => private, :created_on => getTime())
  addUserToRoom(admin, room_name, true)
end


def addUserToRoom(user, room, admin=false )
  $fb_root.set(  "/chats/#{room}/users/#{user}", :admin => admin, :added_on => getTime() )
end

#def grantAdmin(user, room )
#  $fb_root.update(  "/chats/#{room}/users/#{user}", :admin => true )
#end


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
  Firebase::ServerValue::TIMESTAMP
  #Time.now.to_s 
end