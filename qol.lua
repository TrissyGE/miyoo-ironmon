-- Miyoo-specific display and controls; original Tracker remains available on X.
MiyooQol={settings={favourites={},fast_forward='hold'},message='',messageUntil=0,menu=false,selection=1,prev=0}
local Q=MiyooQol
local function txt(x,y,s,size,color) miyoo.text(x,y,tostring(s or ''),color or 0xffeeeeee,size or 17) end
local function rect(x,y,w,h,c) miyoo.rect(x,y,w,h,c or 0xff17202b) end
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
    if MiyooRules.pending or MiyooRules.ended then return end
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
    if not Q.menu then return end
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
function Q.isCompact() return Battle and Battle.inBattleScreen or Q.menu or MiyooRules.pending or MiyooRules.ended end
function Q.allowOriginal() return not Q.menu and not MiyooRules.pending and not MiyooRules.ended end
function Q.needsNative() return Q.menu or MiyooRules.pending or MiyooRules.ended end
function Q.draw()
    if not Program or not GameSettings.pstats then return end
    local r=MiyooRules
    if miyoo.compact() then
        rect(480,0,160,480,0xff111924);rect(0,320,480,160,0xff17202b)
        txt(491,9,'IRONMON  '..tostring(Main.currentSeed or 1),18,0xff74cbd7)
        local enemy=Battle.inActiveBattle() and TrackerAPI.getEnemyPokemon() or nil
        local own=TrackerAPI.getPlayerPokemon() or {}
        local mon=enemy or own
        local info=PokemonData.Pokemon[mon.pokemonID or 0] or {}
        txt(491,39,enemy and 'GEGNER' or 'DEIN POKEMON',14,0xff8897aa)
        txt(491,61,short(info.name,15),18)
        txt(491,84,'Lv. '..tostring(mon.level or '?'),17)
        local abilities=enemy and Tracker.getAbilities(mon.pokemonID) or {{id=PokemonData.getAbilityId(mon.pokemonID or 0,mon.abilityNum or 0)}}
        txt(491,115,'FAEHIGKEIT',13,0xff8897aa)
        for i=1,2 do local a=AbilityData.Abilities[(abilities[i] or {}).id or 0] or {}
            txt(491,135+(i-1)*21,short(a.name or '?',17),16)
        end
        txt(491,185,enemy and 'BEKANNTE ATTACKEN' or 'ATTACKEN',12,0xff8897aa)
        local moves=enemy and Tracker.getMoves(mon.pokemonID,mon.level) or mon.moves or {}
        for i=1,4 do local m=moves[i] or {};local mi=MoveData.Moves[m.id or 0] or {}
            txt(491,207+(i-1)*43,short(mi.name or '?',17),16)
            if m.id and m.id>1 then txt(491,227+(i-1)*43,'PP '..tostring(m.pp or '?'),13,0xff93a4b8) end
        end
        local marks=enemy and Tracker.getStatMarkings(mon.pokemonID) or {}
        txt(491,385,enemy and 'DEINE STAT-NOTIZEN' or 'STATUS',12,0xff8897aa)
        if enemy then
            local keys={'atk','def','spa','spd','spe'}
            for i,k in ipairs(keys) do txt(491,403+(i-1)*14,k:upper()..'  '..tostring(marks[k] or '?'),12) end
        else txt(491,407,'HP '..tostring(own.curHP or 0)..'/'..tostring((own.stats or {}).hp or 0),17) end
        txt(12,331,short(r.routeName(),37),19,0xff74cbd7)
        txt(12,356,r.routes[r.routeKey()] and 'Route verbraucht: fliehen / Fang verwerfen' or 'Route frei: 1 Fang ODER Wild-KO',16,r.routes[r.routeKey()] and 0xffffbd69 or 0xffa6dba0)
        if r.starterSlot and not r.starterLogged then
            txt(12,389,'Ausgeloster Starter: Ball '..tostring(r.starterSlot),18,0xffffcf83)
        end
        local x,y=12,387
        for slot=1,6 do local p=TrackerAPI.getPlayerPokemon(slot)
            if p then local pi=PokemonData.Pokemon[p.pokemonID] or {};local hp=(p.stats or {}).hp or 0
                local c=p.curHP<=hp//4 and 0xffff7777 or 0xffeeeeee
                txt(x,y,short(pi.name,11)..' '..p.curHP..'/'..hp,14,c)
                x=x+155;if slot%3==0 then x=12;y=y+22 end
            end
        end
        txt(12,437,'Heals: '..tostring(Program.GameData.Items.healingTotal or 0)..' HP   '..'Zeit: '..Utils.formatTime(Tracker.Data.playtime or 0),15,0xffa5b4c5)
        txt(12,460,'L2: Menue    X: Original-Tracker    Y: Ansicht',13,0xff73869d)
    end
    if Q.messageUntil>miyoo.frame() then rect(8,283,464,32,0xff30261a);txt(16,289,short(Q.message,51),16,0xffffcf83) end
    if r.starterSlot and not r.starterLogged and not Q.menu then
        rect(8,8,360,28,0xff30261a)
        txt(16,12,'Ausgeloster Starter: '..({'LINKS','MITTE','RECHTS'})[r.starterSlot],18,0xffffcf83)
    end
    local own=TrackerAPI.getPlayerPokemon() or {}
    if (own.stats or {}).hp and own.curHP>0 and own.curHP<=own.stats.hp//4 then
        rect(8,8,115,26,0xff5a2128);txt(16,11,'WENIG HP',16,0xffffbaba)
    elseif own.status==2 or own.status==6 then
        rect(8,8,150,26,0xff4f245e);txt(16,11,'VERGIFTET',16,0xffe3bbff)
    end
    if r.pending then
        rect(35,100,410,125,0xff172a3b);txt(55,117,'Fang behalten?',23)
        txt(55,151,'Vor der Entscheidung bleiben Werte verborgen.',16)
        txt(55,188,'A: Behalten       B: Ungesehen einlagern',17,0xff74cbd7)
    elseif r.ended then
        rect(20,90,445,135,0xff392028);txt(40,105,'RUN BEENDET',24,0xffffa4a4)
        txt(40,145,short(r.reason or 'Team verloren',47),17)
        txt(40,184,'A+B+Start 2 Sekunden: Neuer Seed',18)
    elseif Q.menu then
        rect(30,32,420,260,0xff172a3b);txt(50,44,'MIYOO IRONMON',22,0xff74cbd7)
        local labels={'Weiterspielen','Tempo: '..(Q.settings.fast_forward=='hold' and 'R2 halten' or 'R2 umschalten'),'Run-Verlauf','Tasten / Hilfe','Neuer Seed'}
        for i,s in ipairs(labels) do if i==Q.selection then rect(43,75+i*32,389,28,0xff304b63) end
            txt(53,78+i*32,s,20)
        end
        if Q.help then rect(34,300,440,156);txt(47,311,'X: Tracker / Cursor  |  Y: Ansicht',17);txt(47,341,'R2: Tempo  |  L2: Menue  |  MENU: Speichern',16);txt(47,371,'Reset: A+B+Start 2 Sekunden halten',17);txt(47,402,'Standard: Teamverlust beendet den Run',16) end
        if Q.history then
            rect(32,300,445,166);local f=io.open('../data/history.tsv','r');local list={}
            if f then for line in f:lines() do list[#list+1]=line end f:close() end
            for i=math.max(1,#list-6),#list do txt(43,306+(i-math.max(1,#list-6))*21,short(list[i]:gsub('^.-\t',''):gsub('\t','  '),52),14) end
        end
    end
end
Q.load()
