    
    //Pull messages and start listening
    firebaseRef.limitToLast(MESSAGE_LIMIT).on('child_added', function(child) {
    
    var msg = child.val();
    //Object.getOwnPropertyNames(msg)
    createMessage(msg.message, child.key(), msg.timestamp, msg.author );
    
    }, function (errorObject) {
    console.log("The read failed: " + errorObject.code);
    });
    
    
    //User visibility live updates below chat text box
    usersChat.on("value", function(snapshot) {
    
      var ulist = snapshot.val();
      $('.users-in-room').empty();
      
      $.each(ulist, function( username, user_data ) {
        
        var user_entry = this.view = document.createElement("span");
        user_entry.setAttribute('class', 'user-visible');
        user_entry.innerHTML = username;
        if (user_data.admin == true) $(user_entry).addClass( 'user-admin');
        
        $(user_entry).appendTo('.users-in-room');
    
      });
    
      //Attach click handler
      $('.user-visible').click(function(){
        $('.textmock').text($('.textmock').text() + '@' + $(this).text().toString().replace("*","") + ' ');
      });
    
    }, function (errorObject) {
      console.log("The read failed on usersChat: " + errorObject.code);
    });
    
    setTimeout(function(){ scrollToBottom(false) }, 1000);
    
    ////////////////////
    // CLICKY THANGS //
    //////////////////
    
    
    //Submit button
    $(".submit-button").click(function() { 
      sendMessage();
    });
    
    //Enter key submit
    $(".textmock").keyup(function (e) {
      if (e.keyCode == 13 && e.shiftKey != true) sendMessage(); //Allows shift - !! still doesn't put \n
    });
    
    
    $( window ).keyup(function (e) { //Space will scroll you down
        if (e.keyCode == 32 ) scrollToBottom(true); 
    });
    
    
    
    
    //Admin click handlers
    $("#admin-add-user").click(function(){
      $('.textmock').text( "/add [username]");
    });
    
    $("#admin-remove-user").click(function(){
      $('.textmock').text( "/remove [username]");
    });
    
    $(".admin-help").click(function(){
      $('.textmock').text( "/help");
    });
    
    
    //Toggle userlist visibility
    $(".toggle-userlist").click(function(){
      $('.users-in-room').slideToggle();
    });
    
    $(".scroll-to-bottom").click(function(){
        scrollToBottom(true);
    });
    
    
    
    
    
    ///////////////
    // HELPERS ///
    /////////////
    
    // var objDiv = document.getElementById("chat-window");
    // objDiv.scrollTop = objDiv.scrollHeight;
    
    function scrollToBottom( animate ){
        if (animate == false ){
          $("chat-window").scrollTop($("chat-window")[0].scrollHeight);    
        } else {
          $("chat-window").animate({ scrollTop: $("chat-window")[0].scrollHeight });
        }
    }
    
    //Sends message to firebase
    var sendMessage = function(){
    
    if ($('.textmock').text().trim() == "") return false; //If not blank
    
    if ($('.textmock').text().trim().indexOf('/') == 0){ //Slash command prob will abstract this out
    
      var cmd_string = $('.textmock').text().trim().replace("/","");
      var cmd = cmd_string.split(" ")[0];
      var arg = cmd_string.split(" ")[1];
      
      switch(cmd) { //Maybe have this handled serverside as well for genuine admin check?
        case "help":
          var msg = "Try some of these commands out: ";
          if (admin == true) {
            msg += "<br><br>It also looks like you're an admin for this room (don't let the power get to yoru head). You can <b>/add</b> and <b>/remove</b> people from the channel,"
            msg += " as well as change the channel's privacy settings with <b>/room public</b> or <b>/room private</b>. In addition, you can grant others "
            msg += "admin access with <b>/grantaccess</b>. "
          }
        break;
        
        case "add":
          $.post( "/admin/add", { user: arg, room: room_name })
          .done(function( data ) {
            firebaseRef.push({
              message: cleanMessage(data),
              timestamp: getDate(),
              author: 'System'
            });
          });
          msg = "";
        break;
        
        case "remove":
          $.post( "/admin/remove", { user: arg, room: room_name })
          .done(function( data ) {
            firebaseRef.push({
              message: cleanMessage(data),
              timestamp: getDate(),
              author: 'System'
            });
          });
          msg = "";
        break;
        
        case "grantadmin":
          $.post( "/admin/grantadmin", { user: arg, room: room_name })
          .done(function( data ) {
            firebaseRef.push({
              message: cleanMessage(data),
              timestamp: getDate(),
              author: 'System'
            });
          });
          msg = "";
        break;
        
        case "room":
          $.post( "/roomstatus", { status: arg, room: room_name })
          .done(function( data ) {
            firebaseRef.push({
              message: cleanMessage(data),
              timestamp: getDate(),
              author: 'System'
            });
          });
          msg = "";
        break;
        
        default:
          msg = "No such command.";
      }
      
      if (arg == undefined && cmd != "help"){
        msg = "No argument sent with command."
      } 
      
      //createMessage(message, id, time, author)
      if (msg.trim() != "" && msg != undefined){
        createMessage(msg, 'sys', getDate(), 'System (Private)')
      }
      $('.textmock').empty();
    
    
    } else { //Non-slash command (normal message)
    
      var mmsg = cleanMessage($('.textmock').text());
      firebaseRef.push({
        message: cleanMessage( mmsg),
        timestamp: Firebase.ServerValue.TIMESTAMP,
        author: userName
      });
      
      notifyTags(mmsg);
      
      $('.textmock').empty(); //Empty field
      //var scrollBottom = $('chat-window').scrollTop() + $('chat-window').height();
      scrollToBottom(false);
      
    }
    
    };
    
    
    
    
    var esctags = ['a', 'javascript', 'marquee'] //Maybe use an array to go through the tags for removal? idk
    var cleanMessage = function(message){ //TODO !! make this actually work well
    
    var msg = message;
    msg = msg.replace('<','');
    msg = msg.replace('>','');
    msg = msg.replace('/>','');
    
    // //!! come back and fix this to get good image captures
    // if ( msg.indexOf('.gif') != -1 || msg.indexOf('.jpg')!= -1 || msg.indexOf('.png') != -1 ){
    //   msg = '{img}' + msg;
    // }   
    
    return addLinks(msg);
    
    };
    
    var _endsWith = function(og, check){ //Because safari doesn't use ES6 yet :'(
    if (og.indexOf(check) == og.length - check.length) return true;
    }
    
    var isImgLink = function(word){
    
      if (_endsWith(word, '.jpg') || _endsWith(word, '.gif') || _endsWith(word, '.png') || _endsWith(word, '.bmp')) return true;
    
    }
    
    var addLinks = function(text) {
    
        var words = text.replace(/^\s+|\s+$/g,'').split(/\s+/);
    
        words.forEach(function(word, ii){
          
          if (word.match(/(^|&lt;|\s)(www\..+?\..+?)(\s|&gt;|$)/g)){ //www link
            if (isImgLink(word)){
              words[ii] = "{img}http://" + word.trim();
            } else { words[ii] = "{url}http://" + word.trim(); }
            
          } else if (word.match(/(^|&lt;|\s)(((https?|ftp):\/\/|mailto:).+?)(\s|&gt;|$)/g)){ //http link
            if (isImgLink(word)){
              words[ii] = "{img}" + word.trim();}
            else { words[ii] = "{url}" + word.trim();  }
          }
        });
        
        return words.join(' ');
    
    
    }
    
    
    //Creates message and appends to messages box
    var createMessage = function(message, id, time, author){
      
      var datetime = new Date(time);

      var msg = this.view = document.createElement("message");
      msg.setAttribute('id', id);
      
      var aa = msg.appendChild(document.createElement("div"));
      aa.setAttribute('class', 'author');
      aa.innerHTML = author;
      
      if (author.indexOf('System')== -1) { //System messages
        var uu = new Firebase(usersGlobal + '/' + author);
        uu.once("value", function(data) {
          aa.setAttribute('style', 'background-color:#'+ data.val().color)
        });
      }
      
      var mm = msg.appendChild(document.createElement("div"));
      mm.setAttribute('class', 'message');
      mm.innerHTML = outputLinks(message).toString();
      
      var tt = msg.appendChild(document.createElement("div"));
      tt.setAttribute('class', 'timestamp');
      tt.innerHTML = datetime.getMonth() + '/' + datetime.getDate() + '  ' + datetime.getHours() + ":" + datetime.getMinutes();
      
      $(msg).appendTo('messages');
      
      // $(msg).click(function(){
      //   ($(this).toggleClass('active'));
      // });
      
      setTimeout(function(){ scrollToBottom(false) }, 200);
      
      if (document.body.className == 'blurred') {
        UNREAD += 1;
        document.title = "GRUUP (" + UNREAD + ")";
      }
    };
    
    
    
    var outputLinks = function(msg){
    var outmessage = msg;  
    var words = msg.split(" ");
    
    if(msg.indexOf('{img}') != -1){ //Image post
    
      words.forEach(function(word, ii){
        if (word.indexOf('{img}') != -1){ //word has image link
        
          var nlink = word.replace('{img}',''); //naked link
          var img_out = "<a target='_blank' class='image-link' href='" + nlink + "'>" + nlink + "</a>";
          img_out += "<img target='_blank' class='inline-image' src='" + nlink + "'/><br/>"
          //var outmessage = img_link + outmessage.replace(ww, "<img class='inline-image' src='" + link + "'></img>");
          
          words[ii] = img_out;
          outmessage = words.join(' ');
        }
      });
      
      
    } 
    if (msg.indexOf('{url}') != -1){
      
      words.forEach(function(word, ii){
        if (word.indexOf('{url}') != -1){ //word has url link
          
          var nlink = word.replace('{url}',''); //naked link
          
          if (nlink.indexOf('www') == 0){
            var url_out = "<a class='url-link' target='_blank' href='http://" + nlink + "'>" + nlink + "</a>";
          } else {
            var url_out = "<a class='url-link' target='_blank' href='" + nlink + "'>" + nlink + "</a>";
          }
          words[ii] = url_out;
          outmessage = words.join(' ').toString();
    
        }
      });
    
    } 
    
    return outmessage;
    
    }
    
    
    var getDate = function(){
      return Firebase.ServerValue.TIMESTAMP;
    //var dt = new Date();
    //var dlit = dt.toDateString();
    //return dt.getMonth() + '/' + dt.getDay() + '/' + dt.getFullYear() + ' ' + dt.getHours() + ':' + dt.getMinutes();
    }
    
    var notifyTags = function(msg){
    var usrs = msg.match(/(?:^|\W)@(\w+)(?!\w)/g);
    if (usrs ){
    usrs.forEach( function( username, ii ){
        var stripped_msg = msg.replace(username,'').trim();
        var userNotices = new Firebase("https://h4xchat.firebaseio.com/users/" + username.replace('@','').trim() + "/notices/");
        
        userNotices.push({
          room: room_name,
          message: stripped_msg,
          time: Firebase.ServerValue.TIMESTAMP
        });
      
    });
    }
    }
    
    // //Create eventListner for onclick event of stickers button
    // $('.stickers-modal-button').on('click', function(e) {
    //   var connectionStr = 'http://api.flickr.com/services/feeds/photos_public.gne?format=json&tags=pugs&jsoncallback=?';
    //   var $img = $("<img>");
    //   var maxNumOfImages = 10;
    //   $.getJSON(connectionStr, function(data) {
    //       //Loop through each item of the response
    //       data.items.forEach(function(photo) {
    //         //Initialize the $img obj to blank <img> tag
    //         $img = $("<img>").addClass('stickerItem');
    //         if(maxNumOfImages === 0) {
    //           return;
    //         }
    //         //Append the img URL to $img obj
    //         $img.attr("src", photo.media.m);
    //         $li = $("<li>").addClass('stickerItem');
    
    //         $li.append($img)
    //         $(".stickerImages").append($li);
    //         maxNumOfImages--;
    //       });        
    //   });
    //   $('#dialog').css('display', 'block');
    // });
    
    
