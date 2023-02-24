require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/reloader'
require_relative('model.rb')
# require ''

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

  db = SQLite3::Database.new("db/parking.db")
  db.results_as_hash = true 

  db.execute("INSERT INTO posts (user_id, data, global) VALUES (?, ?, ?)", session["id"], streetName, isGlobal).first
  redirect("/showposts")
end

post("/posts/:id/delete") do
  id = params[:id].to_i
  # p "Detta är note id #{id}"
  db = SQLite3::Database.new("db/parking.db")
  db.results_as_hash = true 

  db.execute("DELETE FROM posts WHERE id = ?", id).first
  redirect("/showposts")
end

# Visar update-slimmen och skickar in information om user-posten som ska
# uppdateras
get("/posts/:id/update") do
  content = params[:content]
  slim(:"posts/update", locals:{id:params[:id]})
end

# Uppdatera user-posten 
post("/posts/:id/update") do
  id = params[:id].to_i
  streetName = params[:streetName]

  isGlobal = 0
  if params[:isGlobal] == "on" 
    isGlobal = 1
  end

  p "The id of the post which is being edited: #{id}"
  db = SQLite3::Database.new("db/parking.db")
  db.results_as_hash = true 

  db.execute("UPDATE posts SET data = ?, global = ? WHERE id = ?", streetName, isGlobal, id).first
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

# get("/todos") do
#   id = session[:id].to_i  
#   db = SQLite3::Database.new("db/todo2022.db")
#   db.results_as_hash = true 
#   result = db.execute("SELECT * FROM todos WHERE user_id = ?", id)
#   p("Alla todos from result: #{result}" )
#   slim(:"todos/index", locals:{todos:result})
# end