require 'sinatra/reloader'

#Funktion som kollar ifall input matchar användarens like status på post
def opinionOnPostIs(post_id, opinion)
    return getDB().execute("SELECT value FROM users_likes_posts_rel WHERE post_id = ? AND user_id = ?", post_id, getUserId()).first[0] == opinion    
end

# $db = Database.new("db/parking.db")

# $db.get_user(asdasd)

# class Database
#     def initialize(db_file)
#         @db = SQLite3::Database.new(db_file)
#         db.results_as_hash = true 
#     end
    
#     def do_foo()
#         sql = <<-SQL
#             SELECT * FROM table
#         SQL

#         @db.execute(sql)
#     end
# end

def getUserIdByPost(post_id)
    return getDB().execute("SELECT user_id FROM posts WHERE id = ?", post_id).first[0].to_i
end

helpers do 
    # Hämta databas
    def getDB()
        db = SQLite3::Database.new("db/parking.db")
        db.results_as_hash = true 
        return db
    end

    #Funktion som returnerar id på användaren.
    def getUsername(id)
        db = getDB()
        return db.execute("SELECT username FROM users WHERE id = ?", id).first[0]
    end

    #Funktion som kollar ifall input matchar användarens like status på post
    def opinionOnPostIs(post_id, opinion)
        return getDB().execute("SELECT value FROM users_likes_posts_rel WHERE post_id = ? AND user_id = ?", post_id, getUserId()).first[0] == opinion    
    end

    #Funktion som kollar ifall användare har gillat/ogillat post
    def hasOpinionOnPost(post_id)
        return getDB().execute("SELECT * FROM users_likes_posts_rel WHERE post_id = ? AND user_id = ?", post_id, getUserId()).length > 0
    end

    def getAmountOfOpinionsOnPost(post_id)
        return getDB().execute("SELECT * FROM users_likes_posts_rel WHERE post_id = ?", post_id).count.to_i
    end

    def getOpinionRatioOnPost(post_id)
        return getDB().execute("SELECT * FROM users_likes_posts_rel WHERE post_id = ? AND value = 1", post_id).count.to_f / getDB().execute("SELECT * FROM users_likes_posts_rel WHERE post_id = ?", post_id).count.to_f 
    end
end