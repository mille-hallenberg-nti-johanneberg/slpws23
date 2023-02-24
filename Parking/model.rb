def retrieveName()
    
end

helpers do 
    # Funktion som returner true ifall man har loggat in.
    def isLoggedIn()
        return session["id"] != nil
    end