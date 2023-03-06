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