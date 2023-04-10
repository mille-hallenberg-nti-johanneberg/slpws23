require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/reloader'
require_relative './model.rb'

enable :sessions

# Hem
get('/') do
  slim(:index)
end

# Visar register-sidan
get('/showregister') do
  slim(:register)
end

# Visar login-sidan
get("/showlogin") do
  slim(:login)
end

# Visar sidan för att skapa en post
get("/showcreatepost") do
  slim(:"posts/new", locals:{user:session[:id]})
end

# Skapar ny databas
def new_database(path)
  return SQLite3::Database.new(path)
end

# Loggar in
post("/login") do
  username = params[:username]
  password = params[:password]

  db = new_database("db/parking.db")
  db.results_as_hash = true 
  result = db.execute("SELECT * FROM users WHERE username = ?", username).first
  
  if result == nil 
    "Wrong username or password."
    return
  end

  pwdigest = result["pwdigest"]
  id = result["id"]

  if BCrypt::Password.new(pwdigest) == password
    session["id"] = id
    session["username"] = username
    p "Login Successful"
    redirect("/privateposts")
  else
    "Wrong username or password."
  end
end

# Loggar ut användare
post("/logout") do
  if session["id"] != nil
    session["id"] = nil
    session["username"] = nil
  end

  redirect("/")
end

# Skapar ny användare
post("/users/new") do
  username = params[:username]
  password = params[:password]
  password_confirm = params[:password_confirm]
  
  if (password == password_confirm)
    password_digest = BCrypt::Password.create(password)
    db = new_database("db/parking.db")
    db.execute("INSERT INTO users (username, pwdigest) VALUES (?, ?)", username, password_digest)
    redirect('/')
  else
    p password + " " + password_confirm
    "Passwords did not match"
  end
end

# Visar privata posts
get("/privateposts") do
  id = session[:id].to_i  
  db = SQLite3::Database.new("db/parking.db")
  db.results_as_hash = true 
  result = db.execute("SELECT * FROM posts WHERE user_id = ?", id)
  slim(:"posts/index", locals:{posts:result, category:"private"})
end

# Visar globala posts
get("/globalposts") do
  id = session[:id].to_i  
  db = SQLite3::Database.new("db/parking.db")
  db.results_as_hash = true 
  result = db.execute("SELECT * FROM posts WHERE global = 1")
  slim(:"posts/index", locals:{posts:result, category:"global"})
end

# Filtrerar posts
get("/filterposts") do
  db = SQLite3::Database.new("db/parking.db")
  db.results_as_hash = true 
  username = params[:username]
  likedPost = params[:likedPost]

  usernameEntered = username != nil && username != ""
  filterLikes = likedPost != nil

  if usernameEntered
    # Filtrera på namn och om användaren har gillat dem
    if filterLikes
      result = db.execute("SELECT p.*
        FROM posts p
        JOIN users_likes_posts_rel ulp ON ulp.post_id = p.id AND ulp.user_id = ? AND p.global = 1 AND ulp.value = 1
        JOIN users u ON u.id = p.user_id AND u.username = ?", getUserId(), username)
    # Filtrera bara på namn
    else
      result = db.execute("SELECT p.*
        FROM posts p
        JOIN users u ON p.user_id = u.id
        WHERE u.username = ? AND p.global = 1", username)
    end
  else
    # Filtrera bara på ifall användaren har gillat dem
    if filterLikes
      result = db.execute("SELECT p.*
        FROM posts p
        JOIN users_likes_posts_rel ulp ON ulp.post_id = p.id AND p.global = 1 AND ulp.user_id = ? AND ulp.value = 1", getUserId())
    # Inget filter 
    else
      result = db.execute("SELECT * from posts WHERE posts.global = 1")
    end
  end

  slim(:"posts/index", locals:{posts:result, category:"global"})
end

# Skapar post
post("/posts/new") do
  streetName = params[:streetName]
  
  isGlobal = 0
  if params[:isGlobal] == "on" 
    isGlobal = 1
  end

  if POSTRequestApproved(getUserId())
    db = SQLite3::Database.new("db/parking.db")
    db.results_as_hash = true 

    db.execute("INSERT INTO posts (user_id, data, global) VALUES (?, ?, ?)", getUserId(), streetName, isGlobal).first
  end

  redirect("/privateposts")
end

# Tar bort post
post("/posts/:id/delete") do
  post_id = params[:id].to_i
  
  if POSTRequestApproved(getUserIdByPost(post_id))
    db = SQLite3::Database.new("db/parking.db")
    db.results_as_hash = true 

    db.execute("DELETE FROM posts WHERE id = ?", post_id).first
  end

  redirect("/privateposts")
end

# Visar update-slimmen och skickar in information om user-posten som ska
# uppdateras
get("/posts/:id/update") do
  if !POSTRequestApproved(getUserIdByPost(params[:id]).to_i)
    slim(:shamecorner)
  else
    content = params[:content]
     
    db = SQLite3::Database.new("db/parking.db")
    db.results_as_hash = true 

    post_id = params[:id]

    post_info = db.execute("SELECT * FROM posts WHERE id = ?", post_id).first
    p post_info

    slim(:"posts/update", locals:{id:post_id, streetName:post_info["data"], global:post_info["global"]})
  end
end

# Uppdatera user-posten 
post("/posts/:id/update") do
  post_id = params[:id].to_i
  streetName = params[:streetName]

  isGlobal = 0
  if params[:isGlobal] == "on" 
    isGlobal = 1
  end
  
  if POSTRequestApproved(getUserIdByPost(post_id))
    db = SQLite3::Database.new("db/parking.db")
    db.results_as_hash = true 

    db.execute("UPDATE posts SET data = ?, global = ? WHERE id = ?", streetName, isGlobal, post_id).first
  end

  redirect("/privateposts")
end

#Skapa en like/dislike
post("/posts/like/:post_id/new/:value") do
  post_id = params[:post_id].to_i
  like_value = params[:value].to_i

  if POSTRequestApproved(getUserId())
    db = SQLite3::Database.new("db/parking.db")
    db.results_as_hash = true 

    db.execute("INSERT INTO users_likes_posts_rel (user_id, post_id, value) VALUES (?, ?, ?)", getUserId(), post_id, like_value).first
  end
  
  redirect("/globalposts")
end

#Uppdatera värdet på en like/dislike
post("/posts/like/:post_id/update/:value") do
  post_id = params[:post_id].to_i
  like_value = params[:value].to_i

  if POSTRequestApproved(getUserId())
    p "This is the opinion #{opinionOnPostIs(post_id, like_value)} and the value of my shit is #{like_value}"
    if opinionOnPostIs(post_id, like_value)
      deleteLike(post_id)
    else
      db = SQLite3::Database.new("db/parking.db")
      db.results_as_hash = true 

      db.execute("UPDATE users_likes_posts_rel SET value = ? WHERE post_id = ? AND user_id = ?", like_value, post_id, getUserId()).first
    end
  end
    
  redirect("/globalposts")
end

# Tar bort post
post("/posts/like/:post_id/delete") do
  post_id = params[:post_id].to_i

  if POSTRequestApproved(getUserId())
    deleteLike(post_id)
  end

  redirect("/privateposts")
end

# Funktion, tar bort like
def deleteLike(post_id)
  db = SQLite3::Database.new("db/parking.db")
  db.results_as_hash = true 

  db.execute("DELETE FROM users_likes_posts_rel WHERE user_id = ? AND post_id = ?", getUserId(), post_id).first
end

# Kontrollerar att requesten för någon sorts POST är gjort av rätt användare (behöver vara inloggad och användar-id behöver stämma)
# eller är gjort av en admin
def POSTRequestApproved(id_in_question)
  p id_in_question
  p getUserId()
  return isLoggedIn() && (getUserId() == id_in_question || isAdmin())
end

helpers do
  # Funktion som returner true ifall man har loggat in.
  def isLoggedIn()
    return session["id"] != nil
  end

  #Funktion som returnerar id på användaren.
  def getUserId()
    if session["id"] == nil
      return -1
    end

    return session["id"].to_i
  end

  # Funktion som kollar ifall användaren är admin.
  def isAdmin()
    return session["id"].to_i == 2
  end
end