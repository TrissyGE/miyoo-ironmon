-- Rearrange the unmodified upstream Tracker's rendered panels, including their
-- original buttons. Fonts, sprites, stages, hidden data and themes stay upstream.
local L={}
local function round(n) return math.floor(n+0.5) end
function L.panels(gw,gh,ballPicker)
    local side=640-gw
    local headerH=round(side*(ballPicker and 81/102 or 52/66))
    local scale=math.min((side-12)/45,(gh-headerH-40)/76)
    local statsW,statsH=round(45*scale),round(76*scale)
    local movesH=480-gh-46
    local movesW=round(movesH*150/55)
    local portraitW=round(movesH*38/56)
    local lowerX=movesW+portraitW
    local lowerW=640-lowerX
    local carouselH=round(lowerW*20/150)
    local healsH=movesH-carouselH
    local healsW=math.min(lowerW,round(healsH*102/25))
    healsH=round(healsW*25/102)
    return {
        ballPicker and {240,0,102,81,gw,0,side,headerH} or {276,4,66,52,gw,0,side,headerH},
        {341,5,45,76,gw+(side-statsW)//2,headerH+9,statsW,statsH},
        {240,81,150,55,0,gh,movesW,movesH},
        {240,0,38,56,movesW,gh,portraitW,movesH},
        {240,56,102,25,lowerX+(lowerW-healsW)//2,gh,healsW,healsH},
        {240,136,150,20,lowerX,gh+movesH-carouselH,lowerW,carouselH},
    },headerH+statsH+12
end
function L.popup()
    return (MiyooDialogs and MiyooDialogs.active) or
        (Program and Program.currentScreen and Program.currentScreen~=TrackerScreen) or
        (Program and Program.currentOverlay) or
        (TeamViewArea and TeamViewArea.isDisplayed())
end
local function color(key,fallback) return Theme and Theme.COLORS[key] or fallback end
local function text(x,y,s,size,c) miyoo.text(x,y,tostring(s or ''),c or color('Default text',0xffffffff),size or 14) end
local function rect(x,y,w,h,c) miyoo.rect(x,y,w,h,c or color('Main background',0xff000000)) end
local function short(s,n) s=tostring(s or '');return #s>n and s:sub(1,n-1)..'~' or s end
function L.draw(Q,R)
    local gw,gh=miyoo.viewport()
    rect(gw,0,640-gw,480)
    rect(0,gh,640,480-gh)
    local ballPicker=TrackerScreen and TrackerScreen.canShowBallPicker()
    local panels,sideFooter=L.panels(gw,gh,ballPicker)
    if not R.pending and not R.ended and not L.popup() then
        for i,p in ipairs(panels) do if not ballPicker or i~=4 then miyoo.panel(table.unpack(p)) end end
    end
    local header=color('Header text',0xffffffff)
    text(gw+4,sideFooter,short(R.routeName(),19),11,header)
    text(gw+4,sideFooter+13,R.routes[R.routeKey()] and 'Route used' or 'Catch / KO open',11,
        color(R.routes[R.routeKey()] and 'Intermediate text' or 'Positive text',0xffffffff))
    if not R.pending then
        for slot=1,6 do
            local p=TrackerAPI.getPlayerPokemon(slot)
            if p then
                local info=PokemonData.Pokemon[p.pokemonID] or {}
                local hp=(p.stats or {}).hp or 0
                local c=color(p.curHP<=hp//4 and 'Negative text' or 'Default text',0xffffffff)
                local px=8+((slot-1)%3)*212
                text(px,436+((slot-1)//3)*15,short(info.name,12)..' '..p.curHP..'/'..hp,12,c)
            end
        end
    end
    rect(0,466,640,14)
    text(8,467,'#'..tostring(Main.currentSeed or 1)..'   Start: Own / Enemy   X: Cursor   L/R: Mark stats   Select: Notes   L2: Menu',10,header)
    if L.popup() and not Q.menu and not R.pending and not R.ended then
        if MiyooDialogs and MiyooDialogs.active then
            -- Forms and keyboard occupy the full logical 390x160 canvas.
            miyoo.panel(0,0,390,160,0,96,640,263)
        elseif Program.currentOverlay or (TeamViewArea and TeamViewArea.isDisplayed()) then
            local w,h=miyoo.canvasSize()
            local scale=math.min(640/w,440/h)
            local dw,dh=round(w*scale),round(h*scale)
            miyoo.panel(0,0,w,h,(640-dw)//2,(440-dh)//2,dw,dh)
        else
            -- Every upstream detail/settings page keeps its complete 150x160 UI.
            miyoo.panel(240,0,150,160,91,20,330,352)
        end
        rect(0,466,640,14)
        text(8,467,'X: Cursor / Play   A: Click   B: Back   Select: Enemy notes',10,header)
    end
end
return L
