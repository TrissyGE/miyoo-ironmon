-- Runtime guards for FireRed USA Rev 1. Data layouts: pret/pokefirered and
-- Ironmon-Tracker GameAddresses/Pokemon FireRed v1.1.json (see SOURCES.md).
MiyooRules = {routes={},dead={},rejected={},seen={},trainers={},hidden={},history={},ended=false,firstBattle=false}
local R=MiyooRules
local P=dofile('../rule_policy.lua')
local rb=memory.read_u8
local rw=memory.read_u16_le
local rd=memory.read_u32_le
local wb=memory.write_u8
local ww=memory.write_u16_le
local wd=memory.write_u32_le
local function valid(a,size) return a and a>=0x02000000 and a+(size or 1)<=0x02040000 end
local function bytes(a,n) local t={} for i=0,n-1 do t[i+1]=rb(a+i) end return t end
local function writeBytes(a,t) for i,v in ipairs(t) do wb(a+i-1,v) end end
local function zero(a,n) for i=0,n-1 do wb(a+i,0) end end
local function identity(a) return string.format('%08x:%08x',rd(a),rd(a+4)) end
local function growth(a)
    local pid=rd(a);local key=pid~rd(a+4)
    local off=32+(MiscData.TableData.growth[pid%24+1]-1)*12
    return a+off,key
end
local function validBox(a)
    -- The core yields at VBlank, which can interrupt Get/SetMonData between
    -- DecryptBoxMon and EncryptBoxMon. Never edit that transient plaintext.
    if not valid(a,80) or (rb(a+19)&3)~=2 then return false end
    local key=rd(a)~rd(a+4);local sum=0
    local g=growth(a);local id=(rd(g)~key)&0xffff
    if id<1 or id>411 then return false end
    for i=0,11 do local v=rd(a+32+i*4)~key;sum=(sum+(v&0xffff)+(v>>16))&0xffff end
    return sum==rw(a+28)
end
local function species(a) local g,k=growth(a);return (rd(g)~k)&0xffff end
local function setGrowth(a,index,value)
    if not validBox(a) then return false end
    local g,k=growth(a);local old=rd(g+index*4)~k
    if old==value then return true end
    local checksum=rw(a+28)
    checksum=(checksum-(old&0xffff)-(old>>16)+(value&0xffff)+(value>>16))&0xffff
    wd(g+index*4,value~k);ww(a+28,checksum)
    return validBox(a)
end
local function held(a) local g,k=growth(a);return (rd(g)~k)>>16 end
local function clearHeld(a) local g,k=growth(a);return setGrowth(a,0,(rd(g)~k)&0xffff) end
local function isShiny(a)
    local pid,tid=rd(a),rd(a+4)
    return ((pid&0xffff)~(pid>>16)~(tid&0xffff)~(tid>>16))<8
end
local function storage()
    local a=rd(0x03005010)
    if valid(a,33744) then return a end
end
local function party() return GameSettings.pstats end
local function count() return math.min(6,rb(GameSettings.gPlayerPartyCount)) end
local function partyReady()
    local n=rb(GameSettings.gPlayerPartyCount)
    if n>6 then return false end
    for i=0,5 do
        local a=party()+i*100;local occupied=(rb(a+19)&2)~=0
        if i<n then
            if not occupied or not validBox(a) then return false end
        elseif occupied then return false end -- Party reorder/count update in progress.
    end
    return true
end
local function inField()
    -- Rev 1 CB2_Overworld, observed on the real core and matched to overworld.c.
    -- Menu callbacks retain party indices; never compact their live party data.
    return rd(0x030030f4)==0x080565c9 and not Program.inStartMenu
end
local function boxSlots(fn)
    local base=storage();if not base then return end
    for b=0,13 do for s=0,29 do
        local a=base+4+(b*30+s)*80
        if (rb(a+19)&2)~=0 then fn(a,b,s) end
    end end
end
local function partySlots(fn)
    for i=0,count()-1 do local a=party()+i*100;if (rb(a+19)&2)~=0 then fn(a,i) end end
end
function R.notify(message)
    console.log('RULE:',message)
    if MiyooQol then MiyooQol.notify(message) end
end
function R.log(kind,text)
    local f=io.open('../data/history.tsv','a')
    if f then f:write(os.date('!%Y-%m-%dT%H:%M:%SZ'),'\t',tostring(Main.currentSeed),'\t',kind,'\t',text:gsub('[\r\n\t]',' '),'\n');f:close() end
end
function R.save()
    local f=io.open('../data/current.rules.tmp','w');if not f then return end
    f:write('rom=',gameinfo.getromhash(),'\nfirst=',R.firstBattle and '1' or '0','\nended=',R.ended and '1' or '0','\nreason=',(R.reason or ''):gsub('[\r\n]',' '),'\nstarted=',R.starterLogged and '1' or '0','\nbadges=',tostring(R.badges or 0),'\n')
    if R.pending then local p=R.pending;f:write('pending=',p.id,'|',p.species,'|',p.route,'|',p.name:gsub('[|\r\n]',' '),'\n')
        for id,item in pairs(p.stolen or {}) do f:write('stolen=',id,'|',item,'\n') end
    end
    for _,group in ipairs({'routes','dead','rejected','seen','trainers','hidden'}) do
        for k,v in pairs(R[group]) do if v then f:write(group,'=',tostring(k),'\n') end end
    end
    f:close();os.rename('../data/current.rules.tmp','../data/current.rules')
end
function R.load()
    local f=io.open('../data/current.rules','r');if not f then return end
    local data=f:read('*a');f:close()
    if not data:find('rom='..gameinfo.getromhash(),1,true) then return end
    for key,value in data:gmatch('([^=\n]+)=([^\n]*)') do
        if R[key] and type(R[key])=='table' then R[key][(key=='routes' or key=='trainers' or key=='hidden') and tonumber(value) or value]=true
        elseif key=='first' then R.firstBattle=value=='1'
        elseif key=='ended' then R.ended=value=='1' end
        if key=='reason' then R.reason=value
        elseif key=='started' then R.starterLogged=value=='1'
        elseif key=='badges' then R.badges=tonumber(value)
        elseif key=='pending' then
            local id,species,route,name=value:match('^(.-)|(%d+)|(%d+)|(.*)$')
            if id then R.pending={id=id,species=tonumber(species),route=tonumber(route),name=name,stolen={}} end
        elseif key=='stolen' and R.pending then
            local id,item=value:match('^(.-)|(%d+)$');if id then R.pending.stolen[id]=tonumber(item) end
        end
    end
end
function R.endRun(reason)
    if R.ended then return end
    R.ended=true;R.reason=reason;R.pending=nil
    R.log('end',reason);R.save();R.notify(reason)
    client.pause()
    if miyoo.checkpoint then miyoo.checkpoint() end
end
function R.canReset()
    if R.firstBattle or R.ended or R.unstableReported or count()==0 then return true end
    R.notify('Standard: Erst den Laborkampf spielen.');return false
end
function R.routeKey()
    -- regionMapSectionId unifies floors and encounter methods of a location.
    return rb(GameSettings.gMapHeader+0x14)
end
function R.routeName()
    local info=RouteData.Info[Program.GameData.mapId or 0] or {}
    return info.name or 'Start'
end
function R.lab()
    local name=R.routeName():lower()
    return name:find('lab',1,true)~=nil
end
function R.deposit(a,rejected)
    if not partyReady() or not validBox(a) then return false end
    local base=storage();if not base then return false end
    local target
    -- Last available boxes are used as the graveyard. Preserve other box mons.
    for b=13,0,-1 do for s=29,0,-1 do
        local dst=base+4+(b*30+s)*80
        if (rb(dst+19)&2)==0 then target=dst;break end
    end if target then break end end
    if not target then R.endRun('Boxen voll: Kein sicherer Transfer moeglich.');return false end
    local id=identity(a)
    if rejected then R.rejected[id]=true else R.dead[id]=true end
    if not clearHeld(a) then return false end -- No item can be salvaged from the box.
    writeBytes(target,bytes(a,80))
    local index=(a-party())//100;local n=count()
    for i=index,n-2 do writeBytes(party()+i*100,bytes(party()+(i+1)*100,100)) end
    zero(party()+(n-1)*100,100);wb(GameSettings.gPlayerPartyCount,n-1)
    R.save();return true
end
function R.discardCapture()
    local p=R.pending;if not p then return end
    local removed=false
    partySlots(function(a) if identity(a)==p.id then removed=R.deposit(a,true) end end)
    if not removed then boxSlots(function(a) if identity(a)==p.id then clearHeld(a);R.rejected[p.id]=true;removed=true end end) end
    if not removed then R.endRun('Fang konnte nicht sicher verworfen werden.');return end
    partySlots(function(a) if (p.stolen or {})[identity(a)]==held(a) then clearHeld(a) end end)
    R.pending=nil;R.save();R.notify('Fang verworfen. Route bleibt wie zuvor.');client.unpause()
    if miyoo.checkpoint then miyoo.checkpoint() end
end
function R.keepCapture()
    local p=R.pending;if not p then return end
    if R.routes[p.route] or (P.legendary[p.species] and not R.isFavourite(p.species)) then
        R.discardCapture();return
    end
    R.routes[p.route]=true;R.pending=nil
    R.log('catch',p.name);R.save();client.unpause();R.notify('Fang behalten: Route verbraucht.')
    if miyoo.checkpoint then miyoo.checkpoint() end
end
function R.isFavourite(id)
    for _,v in ipairs(MiyooQol and MiyooQol.settings.favourites or {}) do if v==id then return true end end
    return false
end
function R.setupStarter()
    -- UPR ZX Gen3RomHandler: indices are Bulbasaur, Charmander, Squirtle;
    -- physical balls are Bulbasaur, Squirtle, Charmander (left to right).
    local base=0x08169c2d
    local starters={rw(base),rw(base+515),rw(base+461)}
    for _,id in ipairs(starters) do if not PokemonData.isValid(id) then return end end
    local slot=tonumber(gameinfo.getromhash():sub(1,8),16)%3+1
    for _=1,3 do
        local id=starters[slot]
        if not P.legendary[id] or R.isFavourite(id) then R.starter=id;R.starterSlot=({1,3,2})[slot];return end
        slot=slot%3+1
    end
    R.endRun('Alle Starter sind durch die Legendaer-Regel gesperrt.')
end
local function bagSnapshot()
    local sb=rd(GameSettings.gSaveBlock1ptr);local sb2=rd(GameSettings.gSaveBlock2ptr)
    if not valid(sb,0x3d68) or not valid(sb2,0xf24) then return end
    local key=rd(sb2+0xf20);local slots,totals={},{}
    for _,p in ipairs({{0x310,42},{0x3b8,30},{0x430,13},{0x464,58},{0x54c,43}}) do
        for i=0,p[2]-1 do local a=sb+p[1]+i*4;local id=rw(a);local n=rw(a+2)~(key&0xffff)
            if id>0 and n>0 and n<=999 then slots[#slots+1]={a=a,id=id,n=n};totals[id]=(totals[id] or 0)+n end
        end
    end
    return {sb=sb,key=key,slots=slots,totals=totals,money=rd(sb+0x290)~key,coins=rw(sb+0x294)~(key&0xffff)}
end
local function removeItem(bag,id,n)
    for _,s in ipairs(bag.slots) do if s.id==id and n>0 then
        local take=math.min(s.n,n);s.n=s.n-take;n=n-take
        ww(s.a+2,s.n~(bag.key&0xffff));if s.n==0 then ww(s.a,0) end
    end end
end
local function restoreBalls(bag,id,n)
    for i=0,12 do local a=bag.sb+0x430+i*4;local existing=rw(a)
        if existing==id or existing==0 then
            local amount=existing==id and (rw(a+2)~(bag.key&0xffff)) or 0
            ww(a,id);ww(a+2,math.min(999,amount+n)~(bag.key&0xffff));return true
        end
    end
    return false
end
local function hiddenItems(bag)
    local recent=R.pickup
    R.hiddenPrevious=R.hiddenPrevious or {}
    for flag=1000,1190 do
        local a=bag.sb+(GameSettings.gameFlagsOffset or 0xee0)+flag//8
        local mask=1<<(flag%8);local set=rb(a)&mask~=0
        if set and R.hiddenPrevious[flag]==false and recent and recent.map==Program.GameData.mapId then
            R.hidden[flag]=true;R.save()
        end
        if R.hidden[flag] and not set then wb(a,rb(a)|mask);set=true end
        R.hiddenPrevious[flag]=set
    end
    if recent then recent.age=recent.age+1;if recent.age>600 then R.pickup=nil end end
end
local function enforceBag()
    local now=bagSnapshot();if not now then return end
    local prev=R.bag
    if prev and prev.sb==now.sb then
        if now.money<prev.money then R.purchase={money=prev.money-now.money,coins=math.max(0,now.coins-prev.coins),age=0} end
        if now.coins<prev.coins then R.coinPurchase={coins=prev.coins-now.coins,age=0} end
        local bannedPurchase,legalPurchase=false,false
        local lostBalls={}
        for id,n in pairs(prev.totals) do if id>=1 and id<=12 and n>(now.totals[id] or 0) then lostBalls[id]=n-(now.totals[id] or 0) end end
        for id,n in pairs(now.totals) do
            local gained=n-(prev.totals[id] or 0)
            if gained>0 and not P.shopAllowed(id) and (R.purchase or R.coinPurchase) then
                removeItem(now,id,gained);bannedPurchase=true
            elseif gained>0 and P.shopAllowed(id) then legalPurchase=true
            end
            if gained>0 and not R.purchase and not R.coinPurchase then
                if not P.shopAllowed(id) and next(lostBalls) then
                    removeItem(now,id,gained)
                    for ball,n in pairs(lostBalls) do restoreBalls(now,ball,n) end
                    R.notify('Ball-Tausch gegen andere Items gesperrt.')
                else R.pickup={map=Program.GameData.mapId,age=0} end
            end
        end
        if bannedPurchase or (R.purchase and R.purchase.coins>0) then
            if R.purchase then
                wd(now.sb+0x290,math.min(999999,now.money+R.purchase.money)~now.key)
                ww(now.sb+0x294,math.max(0,now.coins-R.purchase.coins)~(now.key&0xffff))
            elseif R.coinPurchase then ww(now.sb+0x294,(now.coins+R.coinPurchase.coins)~(now.key&0xffff)) end
            R.purchase=nil;R.coinPurchase=nil;R.notify('Kauf gesperrt: Nur Baelle und Repels.');R.log('guard','shop rejected')
        end
        if legalPurchase then R.purchase=nil;R.coinPurchase=nil end
    end
    for _,k in ipairs({'purchase','coinPurchase'}) do if R[k] then R[k].age=R[k].age+1;if R[k].age>180 then R[k]=nil end end end
    for id,n in pairs(now.totals) do
        if P.bannedItems[id] or id==362 then -- VS Seeker rematches are prohibited.
            removeItem(now,id,n)
        end
    end
    R.bag=bagSnapshot()
    if R.bag then hiddenItems(R.bag) end
end
local function roster()
    local t={}
    partySlots(function(a) t[identity(a)]={a=a,species=species(a)} end)
    boxSlots(function(a) t[identity(a)]={a=a,species=species(a)} end)
    return t
end
local function oldManTutorial()
    -- FireRed's demo reports CAUGHT but deliberately adds no Pokemon to the
    -- player's roster. Program.inCatchingTutorial can clear before Battle does.
    return (rd(GameSettings.gBattleTypeFlags)&0x200)~=0
end
local function finishBattle(b)
    if oldManTutorial() then return end
    local outcome=rb(GameSettings.gBattleOutcome)
    if not b.wild and outcome==1 then R.trainers[b.trainer]=true;R.save()
    elseif b.wild and outcome==1 then
        local _,action=P.wildResult(R.routes[b.route],outcome,b.shiny,false)
        if action=='violation' then R.endRun('Regelbruch: Zweiter Wild-KO an diesem Ort.');return end
        if action=='kill' then R.routes[b.route]=true end
        R.log(action,R.routeName());R.save()
    elseif b.wild and outcome==7 then
        local after=roster();local found
        for id,p in pairs(after) do if not b.before[id] then found={id=id,species=p.species,route=b.route,name=R.routeName()};break end end
        if found then
            R.seen[found.id]=true
            found.stolen=b.stolen
            R.pending=found;R.save();client.pause();if miyoo.checkpoint then miyoo.checkpoint() end
            if R.routes[b.route] or (P.legendary[found.species] and not R.isFavourite(found.species)) then R.discardCapture() end
        else R.endRun('Fangdaten unklar: Run angehalten.');end
    end
    -- Items stolen from wild mons may only be retained if the mon is kept.
    if b.wild and outcome~=7 then
        partySlots(function(a)
            local item=held(a)
            if item~=0 and (b.stolen or {})[identity(a)]==item then clearHeld(a);R.notify('Wildes Item entfernt (Diebstahlregel).') end
        end)
    end
end
function R.update()
    if not GameSettings.pstats or not Program.isValidMapLocation() then return end
    if not R.loaded then
        R.load();R.loaded=true
    end
    if R.ended then client.pause();return end
    if not partyReady() then
        local frame=miyoo.coreFrame and miyoo.coreFrame() or miyoo.frame()
        if frame~=R.lastUnstableFrame then
            R.lastUnstableFrame=frame;R.unstableFrames=(R.unstableFrames or 0)+1
        end
        if R.unstableFrames>=120 and not R.unstableReported then
            R.unstableReported=true;client.pause()
            R.notify('Pokemon-Daten instabil: sicher angehalten.')
            R.log('guard','party data stayed invalid; paused without a run loss')
        end
        return
    end
    R.unstableFrames=0;R.unstableReported=nil;R.lastUnstableFrame=nil
    if not R.rosterLoaded then
        R.rosterLoaded=true;R.seen=R.seen or {}
        for id in pairs(roster()) do R.seen[id]=true end
        if count()==0 then R.setupStarter() end
    end
    if R.pending then client.pause() end
    -- Ignore the entire demonstration, including stale tracker battle state on
    -- exit. Its raw battle flag persists in the field, so only suppress active
    -- battle updates here; normal field guards must continue afterwards.
    if Program.inCatchingTutorial or (Battle.inBattleScreen and oldManTutorial()) then
        R.battle=nil
        return
    end
    local inBattle=Battle.inBattleScreen
    if inBattle and not R.battle then
        local b={route=R.routeKey(),wild=Battle.isWildEncounter,before=roster(),items={},stolen={},shiny=isShiny(GameSettings.estats),trainer=rw(GameSettings.gTrainerBattleOpponent_A)}
        if not b.wild and (R.trainers[b.trainer] or TrackerAPI.hasDefeatedTrainer(b.trainer)) then R.endRun('Regelbruch: Trainer-Revanche.');return end
        partySlots(function(a) b.items[identity(a)]=held(a) end)
        R.battle=b;R.firstBattle=true;R.save()
    elseif R.battle and not inBattle then local b=R.battle;R.battle=nil;finishBattle(b) end
    if R.battle and R.battle.wild and rb(GameSettings.gBattleOutcome)==0 then
        partySlots(function(a) local id=identity(a);local item=held(a)
            if R.battle.items[id]==0 and item>0 then R.battle.stolen[id]=item end
        end)
    end
    if R.ended then return end
    local living,real=0,0
    partySlots(function(a)
        if (rb(a+19)&4)~=0 then return end -- Eggs cannot fight and do not constitute a wipe.
        local id=identity(a);real=real+1
        if rw(a+88)>0 and rb(a+84)>0 and rw(a+86)==0 then
            if not R.dead[id] then R.dead[id]=true;R.log('death',(PokemonData.Pokemon[species(a)] or {}).name or id);R.save() end
        elseif not R.dead[id] and not R.rejected[id] then living=living+1 end
        if R.dead[id] or R.rejected[id] then
            clearHeld(a);ww(a+86,0) -- A Center or Revive never resurrects a dead mon.
        elseif P.bannedItems[held(a)] and not R.lab() then clearHeld(a);R.notify('Verbotenes getragenes Item entfernt.') end
        -- Disable the optional Faster FireRed friendship boost in Viridian.
        local g,k=growth(a);local v=rd(g+8)~k;local friendship=(v>>8)&255
        R.friendship=R.friendship or {}
        if not inBattle and R.friendship[id] and friendship-R.friendship[id]>10 and R.routeName():find('Viridian',1,true) then
            friendship=R.friendship[id];setGrowth(a,2,(v&~0xff00)|(friendship<<8))
            R.notify('Optionaler Freundschaftsbonus gesperrt.')
        end
        R.friendship[id]=friendship
    end)
    if real>0 and living==0 then R.endRun('Game Over: Das ganze Team ist besiegt.');return end
    if not inBattle and not R.pending and inField() then
        -- Compact backwards so that removing a party slot cannot skip its successor.
        for i=count()-1,0,-1 do local a=party()+i*100;local id=identity(a)
            if R.dead[id] or R.rejected[id] then R.deposit(a,R.rejected[id]) end
        end
    end
    if not inBattle then enforceBag() end
    if not R.starterLogged and count()>0 then
        R.starterLogged=true;R.log('starter',(PokemonData.Pokemon[species(party())] or {}).name or '?')
        if R.starter then
            local id=species(party());local sb=rd(GameSettings.gSaveBlock1ptr)
            local chosen=rw(sb+(GameSettings.gameVarsOffset or 0x1000)+0x62)+1
            if not R.isFavourite(id) and (id~=R.starter or chosen~=R.starterSlot) then
                R.endRun('Regelbruch: Anderer als der ausgeloste Starter.');return
            end
        end
    end
    if not inBattle and not R.pending then
        local fresh
        partySlots(function(a)
            local id=identity(a)
            if not R.seen[id] then
                R.seen[id]=true
                if R.firstBattle and not R.dead[id] and not R.rejected[id] then fresh={id=id,species=species(a),route=R.routeKey(),name=R.routeName()} end
            end
        end)
        -- Full-party gifts and static encounters may go directly to a PC box.
        -- Handle one unseen identity at a time so no simultaneous gift is skipped.
        if not fresh and miyoo.frame()%30==0 and inField() then
            boxSlots(function(a)
                local id=identity(a)
                if not fresh and not R.seen[id] then
                    R.seen[id]=true
                    if R.firstBattle and not R.dead[id] and not R.rejected[id] then
                        fresh={id=id,species=species(a),route=R.routeKey(),name=R.routeName()}
                    end
                end
            end)
        end
        if fresh then
            R.pending=fresh;R.save();client.pause();if miyoo.checkpoint then miyoo.checkpoint() end
            if R.routes[fresh.route] or (P.legendary[fresh.species] and not R.isFavourite(fresh.species)) then R.discardCapture() end
        end
    end
    if miyoo.frame()%120==0 then
        boxSlots(function(a) if R.dead[identity(a)] or R.rejected[identity(a)] then clearHeld(a) end end)
        local badges=TrackerAPI.getBadgeList();local n=0;for _,v in ipairs(badges) do if v then n=n+1 end end
        if R.badges and n>R.badges then R.log('badge',tostring(n)) end;R.badges=n
    end
end
