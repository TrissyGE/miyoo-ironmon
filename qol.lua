-- Miyoo-specific display and controls; original Tracker remains available on X.
MiyooQol={settings={favourites={},fast_forward='hold'},message='',messageUntil=0,menu=false,selection=1,prev=0}
local Q=MiyooQol
local Layout=dofile('../tracker_layout.lua')
local function theme(key,fallback) return Theme and Theme.COLORS[key] or fallback end
local function txt(x,y,s,size,color) miyoo.text(x,y,tostring(s or ''),color or theme('Default text',0xffeeeeee),size or 17) end
local function rect(x,y,w,h,c) miyoo.rect(x,y,w,h,c or theme('Upper box background',0xff17202b)) end
local function box(x,y,w,h)
    rect(x,y,w,h,theme('Upper box border',0xffaaaaaa));rect(x+2,y+2,w-4,h-4)
end
local function short(s,n) s=tostring(s or '');if #s>n then return s:sub(1,n-1)..'~' end return s end
function Q.notify(s) Q.message=s;Q.messageUntil=miyoo.frame()+300 end
function Q.load()
    local f=io.open('../settings.ini','r')
    if f then for line in f:lines() do
        local k,v=line:gsub('\r$',''):match('^([%w_]+)=(.*)$')
        if k=='favourites' then for id in v:gmatch('%d+') do Q.settings.favourites[#Q.settings.favourites+1]=tonumber(id) end
        elseif k then Q.settings[k]=v end
    end f:close() end
    local policy=dofile('../rule_policy.lua');local seen,legendary={},0
    local valid={}
    for _,id in ipairs(Q.settings.favourites) do
        if not seen[id] and id>0 and id<=411 and #valid<3 then
            if not policy.legendary[id] or legendary<1 then
                valid[#valid+1]=id;seen[id]=true
                if policy.legendary[id] then legendary=legendary+1 end
            end
        end
    end
    Q.settings.favourites=valid
    miyoo.fastForwardToggle(Q.settings.fast_forward=='toggle')
end
function Q.persistSpeed()
    local f=io.open('../settings.ini','r');local data=f and f:read('*a') or '';if f then f:close() end
    if data:find('fast_forward=') then data=data:gsub('fast_forward=[^\n]*','fast_forward='..Q.settings.fast_forward)
    else data=data..'\nfast_forward='..Q.settings.fast_forward..'\n' end
    f=io.open('../settings.ini.tmp','w');if f then f:write(data);f:close();os.rename('../settings.ini.tmp','../settings.ini') end
end
function Q.toggleMenu()
    if not Q.canOpenMenu() then return end
    Q.menu=not Q.menu
    if Q.menu then client.pause() else client.unpause() end
end
function Q.input()
    local b=miyoo.buttons();local press=b & ~Q.prev;Q.prev=b
    if press & (1<<12)~=0 then Q.toggleMenu() end
    if MiyooRules.pending then
        if press & (1<<8)~=0 then MiyooRules.keepCapture()
        elseif press & 1~=0 then MiyooRules.discardCapture() end
        return
    end
    if not Q.menu then
        if miyoo.isCursor() and not MiyooRules.ended then
            if press&1~=0 then
                if MiyooDialogs.keyboard then MiyooDialogs.keyboard=nil
                elseif MiyooDialogs.dropdown then MiyooDialogs.dropdown=nil
                elseif MiyooDialogs.active then forms.destroy(MiyooDialogs.active)
                elseif Program.currentOverlay then Program.closeScreenOverlay();Program.redraw(true)
                elseif Program.currentScreen~=TrackerScreen then Program.changeScreenView(Program.currentScreen.previousScreen or TrackerScreen) end
            elseif press&(1<<2)~=0 and Battle.inActiveBattle() and not Battle.isViewingOwn and not MiyooDialogs.active then
                local mon=Tracker.getViewedPokemon()
                if mon then TrackerScreen.openNotePadWindow(mon.pokemonID) end
            end
        end
        return
    end
    if press&(1<<4)~=0 then Q.selection=(Q.selection-2)%5+1 end
    if press&(1<<5)~=0 then Q.selection=Q.selection%5+1 end
    if press&1~=0 then Q.toggleMenu() end
    if press&(1<<8)~=0 then
        if Q.selection==1 then Q.toggleMenu()
        elseif Q.selection==2 then
            Q.settings.fast_forward=Q.settings.fast_forward=='hold' and 'toggle' or 'hold'
            miyoo.fastForwardToggle(Q.settings.fast_forward=='toggle');Q.persistSpeed()
        elseif Q.selection==3 then Q.history=not Q.history
        elseif Q.selection==4 then Q.help=not Q.help
        elseif Q.selection==5 then Q.toggleMenu();if MiyooRules.canReset() then miyoo.newRun() end end
    end
end
function Q.isCompact() return true end
function Q.allowOriginal() return not Q.menu and not MiyooRules.pending and not MiyooRules.ended and not MiyooRules.unstableReported and not MiyooDialogs.active end
function Q.canOpenMenu() return not MiyooRules.pending and not MiyooRules.ended and not MiyooDialogs.active end
function Q.needsNative() return Q.menu or MiyooRules.pending or MiyooRules.ended or MiyooRules.unstableReported or Layout.popup() end
function Q.trackerControlsAllowed() return not Q.menu and not MiyooRules.pending and not MiyooRules.ended and not MiyooRules.unstableReported and not MiyooDialogs.active end
function Q.useCompositeGame() return Program and not MiyooDialogs.active and not Program.currentOverlay end
function Q.prepareGame()
    if Program and TrackerScreen and MiyooRules.starterSlot and not MiyooRules.starterLogged
        and TrackerScreen.PokeBalls.chosenBall~=MiyooRules.starterSlot then
        TrackerScreen.PokeBalls.chosenBall=MiyooRules.starterSlot;Program.redraw(true)
    end
    if Q.useCompositeGame() and Program and Program.GameTimer and Options then
        Program.GameTimer:draw();Program.ActiveRepel:draw()
    end
end
function Q.draw()
    if not Program or not GameSettings.pstats then return end
    local r=MiyooRules
    if miyoo.compact() then
        Layout.draw(Q,r)
    end
    if Q.messageUntil>miyoo.frame() then rect(8,283,464,32,0xff30261a);txt(16,289,short(Q.message,51),16,0xffffcf83) end
    if r.starterSlot and not r.starterLogged and not Q.menu then
        rect(8,8,360,28,0xff30261a)
        txt(16,12,'Assigned starter: '..({'LEFT','MIDDLE','RIGHT'})[r.starterSlot],18,0xffffcf83)
    end
    local own=TrackerAPI.getPlayerPokemon() or {}
    if (own.stats or {}).hp and own.curHP>0 and own.curHP<=own.stats.hp//4 then
        rect(8,8,115,26,0xff5a2128);txt(16,11,'LOW HP',16,0xffffbaba)
    elseif own.status==2 or own.status==6 then
        rect(8,8,150,26,0xff4f245e);txt(16,11,'POISONED',16,0xffe3bbff)
    end
    if r.pending then
        box(35,100,410,125);txt(55,117,'Keep this catch?',23)
        txt(55,151,'Stats stay hidden until you decide.',16)
        txt(55,188,'A: Keep       B: Discard unseen',17,0xff74cbd7)
    elseif r.ended then
        box(20,90,445,135);txt(40,105,'RUN ENDED',24,theme('Negative text',0xffffa4a4))
        txt(40,145,short(r.reason or 'Team wiped',47),17)
        txt(40,184,'Hold A+B+Start 2 seconds: New seed',18)
    elseif Q.menu then
        box(30,32,420,260);txt(50,44,'MIYOO IRONMON',22,theme('Header text',0xffffffff))
        local labels={'Continue','Speed: '..(Q.settings.fast_forward=='hold' and 'Hold R2' or 'Toggle R2'),'Run history','Controls / help','New seed'}
        for i,s in ipairs(labels) do
            local selected=i==Q.selection;local background=theme('Upper box border',0xff304b63)
            if selected then rect(43,75+i*32,389,28,background) end
            local brightness=((background>>16)&255)*299+((background>>8)&255)*587+(background&255)*114
            txt(53,78+i*32,s,20,selected and (brightness>128000 and 0xff111111 or 0xffffffff) or nil)
        end
        if Q.help then rect(34,300,440,156);txt(47,311,'X: Tracker cursor  |  Y: Layout',17);txt(47,341,'R2: Speed  |  L2: Menu  |  MENU: Save / exit',16);txt(47,371,'Reset: Hold A+B+Start for 2 seconds',17);txt(47,402,'Standard: A team wipe ends the run',16) end
        if Q.history then
            rect(32,300,445,166);local f=io.open('../data/history.tsv','r');local list={}
            if f then for line in f:lines() do list[#list+1]=line end f:close() end
            for i=math.max(1,#list-6),#list do txt(43,306+(i-math.max(1,#list-6))*21,short(list[i]:gsub('^.-\t',''):gsub('\t','  '),52),14) end
        end
    end
    if r.unstableReported and not Q.menu and not r.ended and not r.pending then
        box(20,90,445,135);txt(40,105,'DATA CHECK: PAUSED',21)
        txt(40,145,'Invalid Pokemon data. No run loss.',16)
        txt(40,184,'L2: Menu / new seed   MENU: Exit',16)
    end
end
Q.load()
