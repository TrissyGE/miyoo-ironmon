-- Standard IronMON policy. Pure functions kept separate for meaningful tests.
-- Rules: https://gist.github.com/valiant-code/adb18d248fa0fae7da6b639e2ee8f9c1
local P = {}
P.bannedItems = {[45]=true,[197]=true} -- Sacred Ash, Lucky Egg
P.legendary = {}
for _,id in ipairs({144,145,146,150,151,243,244,245,249,250,251,401,402,403,404,405,406,407,408,409,410}) do P.legendary[id]=true end
function P.shopAllowed(id) return (id>=1 and id<=12) or id==83 or id==84 or id==86 end
function P.wildResult(used, outcome, shiny, keep)
    if outcome==1 then
        if shiny then return used,'bonus' end
        if used then return true,'violation' end
        return true,'kill'
    elseif outcome==7 and keep then
        if used then return true,'violation' end
        return true,'catch'
    end
    return used,'none'
end
function P.starterAllowed(id, selected, favourites, evolved)
    if evolved then return true end
    local favourite=false
    for _,v in ipairs(favourites or {}) do if id==v then favourite=true end end
    if P.legendary[id] and not favourite then return false end
    return id==selected or favourite
end
return P
