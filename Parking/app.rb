require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/reloader'
require_relative './model.rb'

enable :sessions

# post("/todos/new") do
#   content = params[:content]

#   db = SQLite3::Database.new("db/todo2022.db")
#   db.results_as_hash = true 

#   db.execute("INSERT INTO todos (user_id, content) VALUES (?, ?)", session["id"], content).first
#   redirect("/todos")
# end

# get("/todos/:id/update") do
#   content = params[:content]
#   slim(:"todos/update", locals:{id:params[:id]})
# end

# post("/todos/:id/update") do
#   id = params[:id].to_i
#   p "Detta är note id #{id}"
#   db = SQLite3::Database.new("db/todo2022.db")
#   db.results_as_hash = true 

#   db.execute("UPDATE todos SET content = ? WHERE id = ?", params[:content], id).first
#   redirect("/todos")
# end

get('/') do
  slim(:index)
end

get('/showregister') do
    slim(:register)
  end

get("/showlogin") do
  slim(:login)
end

get("/showcreatepost") do
  slim(:"posts/new", locals:{user:session[:id]})
end

def new_database(path)
    return SQLite3::Database.new(path)
end

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
    redirect("/showposts")
  else
    "Wrong username or password."
  end
end

post("/logout") do
  if session["id"] != nil
    session["id"] = nil
    session["username"] = nil
  end

  redirect("/")
end

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

# Show posts
get("/showposts") do
    id = session[:id].to_i  
    db = SQLite3::Database.new("db/parking.db")
    db.results_as_hash = true 
    result = db.execute("SELECT * FROM posts WHERE user_id = ?", id)
    p("Alla posts from result: #{result}" )

    slim(:"posts/index", locals:{posts:result})
end

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

  redirect("/showposts")
end

post("/posts/:id/delete") do
  post_id = params[:id].to_i
  
  if POSTRequestApproved(getUserIdByPost(post_id))
    db = SQLite3::Database.new("db/parking.db")
    db.results_as_hash = true 

    db.execute("DELETE FROM posts WHERE id = ?", post_id).first
  end

  redirect("/showposts")
end

# Visar update-slimmen och skickar in information om user-posten som ska
# uppdateras
get("/posts/:id/update") do
  if !POSTRequestApproved(getUserIdByPost(params[:id]).to_i)
    p "FAIL"
    slim(:shamecorner)
  else
    content = params[:content]
    slim(:"posts/update", locals:{id:params[:id]})
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

  redirect("/showposts")
end

# TODO: Gör en sida som visar ALLA posts som är globala
get("/showglobalposts") do
  id = session[:id].to_i  
  db = SQLite3::Database.new("db/parking.db")
  db.results_as_hash = true 
  result = db.execute("SELECT * FROM posts WHERE global = 1")
  # p("Alla posts from result: #{result}" )
  slim(:"posts/index", locals:{posts:result})
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
  
  redirect("/showglobalposts")
end

#Uppdatera värdet på en like/dislike
post("/posts/like/:post_id/update/:value") do
  post_id = params[:post_id].to_i
  like_value = params[:value]

  if POSTRequestApproved(getUserId())
    if opinionOnPostIs(post_id, like_value)
      redirect("posts/like/#{post_id}/delete")
    end

    db = SQLite3::Database.new("db/parking.db")
    db.results_as_hash = true 

    db.execute("UPDATE users_likes_posts_rel SET value = ? WHERE post_id = ? AND user_id = ?", like_value, post_id, getUserId()).first
  end
    
  redirect("/showglobalposts")
end

post("/posts/like/:post_id/delete") do
  post_id = params[:post_id].to_i
  # p "Detta är note id #{id}"
  db = SQLite3::Database.new("db/parking.db")
  db.results_as_hash = true 

  if POSTRequestApproved(getUserId())
    db.execute("DELETE FROM users WHERE user_id = ?, post_id", getUserId(), post_id).first
  end

  redirect("/showposts")
end

# Kontrollerar att requesten för någon sorts POST är gjort av rätt användare (behöver vara inloggad och användar-id behöver stämma)
def POSTRequestApproved(id_in_question)
  p id_in_question
  p getUserId()
  return isLoggedIn() && (getUserId() == id_in_question || getUserId() == 2389579830124)
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
end