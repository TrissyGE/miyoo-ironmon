-- Run with Lua 5.4 from the installed tracker directory. Fake memory protects runs.
local ram={}
memory={}
function memory.read_u8(a) assert(a,'nil address');return ram[a] or 0 end
function memory.read_u16_le(a) return memory.read_u8(a)|(memory.read_u8(a+1)<<8) end
function memory.read_u32_le(a) return memory.read_u16_le(a)|(memory.read_u16_le(a+2)<<16) end
function memory.write_u8(a,v) ram[a]=v&255 end
function memory.write_u16_le(a,v) memory.write_u8(a,v);memory.write_u8(a+1,v>>8) end
function memory.write_u32_le(a,v) memory.write_u16_le(a,v);memory.write_u16_le(a+2,v>>16) end
local w8,w16,w32=memory.write_u8,memory.write_u16_le,memory.write_u32_le
local r16,r32=memory.read_u16_le,memory.read_u32_le
local P=dofile('../rule_policy.lua')
assert(P.shopAllowed(4) and P.shopAllowed(86) and not P.shopAllowed(13))
local used,action=P.wildResult(false,1,false,false);assert(used and action=='kill')
used,action=P.wildResult(true,1,true,false);assert(used and action=='bonus')
used,action=P.wildResult(true,1,false,false);assert(action=='violation')
used,action=P.wildResult(false,7,false,false);assert(not used and action=='none')
used,action=P.wildResult(false,7,false,true);assert(used and action=='catch')
assert(not P.starterAllowed(150,150,{},false))
assert(P.starterAllowed(150,1,{150},false))
assert(P.starterAllowed(150,1,{},true))
GameSettings={pstats=0x02024284,gPlayerPartyCount=0x02024029,gSaveBlock1ptr=0x03005008,gSaveBlock2ptr=0x0300500c,gMapHeader=0x02036dfc,gBattleOutcome=0x02023e8a,gBattleTypeFlags=0x02022b4c,gTrainerBattleOpponent_A=0x020386ae,estats=0x0202402c}
Program={GameData={mapId=1},isValidMapLocation=function()return true end,inCatchingTutorial=false}
Battle={inBattleScreen=false,isWildEncounter=false}
RouteData={Info={[1]={name='Route 1'}}}
TrackerAPI={getBadgeList=function() return {} end}
PokemonData={Pokemon={[25]={name='Pikachu'},[19]={name='Rattata'}}}
MiscData={TableData={growth={1,1,1,1,1,1,2,2,3,4,3,4,2,2,3,4,3,4,2,2,3,4,3,4}}}
Main={currentSeed=999}
gameinfo={getromhash=function()return 'test-only' end}
console={log=function(...) print(...) end}
local paused=false
client={pause=function()paused=true end,unpause=function()paused=false end}
miyoo={frame=function()return 1 end}
MiyooQol={settings={favourites={}},notify=function()end}
local oldopen=io.open
-- Tests write no files, including the production rule journal.
io.open=function() return nil end
dofile('../rules.lua')
local R=MiyooRules
w32(0x03005010,0x02029800);w32(0x03005008,0x02025500);w32(0x0300500c,0x02024400)
w32(0x030030f4,0x080565c9)
w32(0x02024400+0xf20,0x12345678)
w32(0x02025500+0x290,3000~0x12345678);w16(0x02025500+0x294,0x5678)
w8(GameSettings.gMapHeader+0x14,88)
for _,p in ipairs({{0x310,42},{0x3b8,30},{0x430,13},{0x464,58},{0x54c,43}}) do
    for i=0,p[2]-1 do w16(0x02025500+p[1]+i*4+2,0x5678) end
end
local function mon(slot,pid,id,hp,item)
    local a=GameSettings.pstats+slot*100;w32(a,pid);w32(a+4,0x12345678)
    w8(a+19,2);w8(a+84,5);w16(a+86,hp);w16(a+88,20)
    local g=a+32+(MiscData.TableData.growth[pid%24+1]-1)*12
    local v=id|(item<<16)
    for i=0,11 do w32(a+32+i*4,pid~0x12345678) end
    w32(g,v~pid~0x12345678)
    w16(a+28,(id+item)&65535)
    return a,g
end
w8(GameSettings.gPlayerPartyCount,2)
local a,g=mon(0,24,25,0,197);local b=mon(1,48,19,20,0)
R.update()
assert(memory.read_u8(GameSettings.gPlayerPartyCount)==1,'dead party slot not removed')
assert(r32(GameSettings.pstats)==48,'party compaction damaged surviving mon')
local dst=0x02029800+4+419*80
assert(r32(dst)==24,'dead mon not copied to graveyard')
assert(r16(dst+28)==25,'held item removal checksum wrong')
assert((r32(dst+32)~24~0x12345678)==25,'dead held item still accessible')
assert(not R.ended and not paused,'one death ended a Standard team run')
-- Buying a Potion is reversed, with exact money and quantity preservation.
local slot=0x02025500+0x310
w16(slot,13);w16(slot+2,3~0x5678);R.update()
w16(slot+2,5~0x5678);w32(0x02025500+0x290,2400~0x12345678);R.update()
assert((r16(slot+2)~0x5678)==3,'guard removed owned items')
assert((r32(0x02025500+0x290)~0x12345678)==3000,'refund incorrect')
-- A Pokeball purchase is legal.
slot=0x02025500+0x430
w16(slot,4);w16(slot+2,2~0x5678);w32(0x02025500+0x290,2600~0x12345678);R.update()
assert((r16(slot+2)~0x5678)==2,'legal balls removed')
assert((r32(0x02025500+0x290)~0x12345678)==2600,'legal purchase refunded')
-- Menu/save key transitions must never turn the owned bag into a purchase.
local sb,sb2=0x02025500,0x02024400
local pockets={{0x310,42},{0x3b8,30},{0x430,13},{0x464,58},{0x54c,43}}
local function bagRecord()
    local data={r32(sb+0x290),r16(sb+0x294)}
    for _,p in ipairs(pockets) do for i=0,p[2]-1 do data[#data+1]=r32(sb+p[1]+i*4) end end
    return table.concat(data,',')
end
local function rekey(newKey,publish)
    local old=r32(sb2+0xf20)
    for _,p in ipairs(pockets) do for i=0,p[2]-1 do
        local a=sb+p[1]+i*4+2;w16(a,r16(a)~(old&65535)~(newKey&65535))
    end end
    w32(sb+0x290,r32(sb+0x290)~old~newKey)
    w16(sb+0x294,r16(sb+0x294)~(old&65535)~(newKey&65535))
    if publish then w32(sb2+0xf20,newKey) end
end
w16(sb+0x3b8,364);w16(sb+0x3ba,1~0x5678) -- TM Case
w16(sb+0x464,289);w16(sb+0x466,2~0x5678)
w16(sb+0x54c,133);w16(sb+0x54e,3~0x5678)
R.update();local owned=bagRecord();local good=R.bag
-- An invalid currency value cannot become a baseline or authorize any writes.
w32(sb+0x290,0xf0000000~0x12345678);local partial=bagRecord();R.update()
assert(bagRecord()==partial and R.bag==good,'invalid money was observed or edited')
w32(sb+0x290,2600~0x12345678)
w16(sb+0x294,10000~0x5678);partial=bagRecord();R.update()
assert(bagRecord()==partial and R.bag==good,'invalid coins were observed or edited')
w16(sb+0x294,0x5678)
-- Real engine ordering: encrypted quantities/currency change before the key.
rekey(0xab94f127,false);partial=bagRecord();R.update()
assert(bagRecord()==partial and R.bag==good,'partial re-encryption damaged the bag')
w32(sb2+0xf20,0xab94f127);R.update()
assert((r16(sb+0x312)~0xf127)==3 and (r16(sb+0x3ba)~0xf127)==1,'owned items/key items removed after rekey')
assert((r16(sb+0x466)~0xf127)==2 and (r16(sb+0x54e)~0xf127)==3,'owned TMs/berries removed after rekey')
assert((r32(sb+0x290)~0xab94f127)==2600 and not R.purchase,'rekey fabricated a shop refund')
-- Even a low-half key change is caught by the encrypted empty slots.
local stable=R.bag;rekey(0xab94f126,false);partial=bagRecord();R.update()
assert(bagRecord()==partial and R.bag==stable,'small-key/empty-slot race escaped validation')
w32(sb2+0xf20,0xab94f126);R.update()
-- A pending money decrease from another context cannot cross a key boundary.
w32(sb+0x290,2100~0xab94f126);R.update();assert(R.purchase)
rekey(0x3210abcd,true);R.update();assert(not R.purchase and not R.coinPurchase,'old spending evidence survived a key change')
w16(sb+0x466,3~0xabcd);R.update()
assert((r16(sb+0x466)~0xabcd)==3,'ordinary pickup after a menu transition was discarded')
-- Invalid nonempty and empty slots must not poison the complete baseline.
stable=R.bag;w16(sb+0x312,1000~0xabcd);partial=bagRecord();R.update()
assert(R.bag==stable and bagRecord()==partial,'invalid occupied quantity was diffed')
w16(sb+0x312,3~0xabcd);w16(sb+0x3be,1~0xabcd);partial=bagRecord();R.update()
assert(R.bag==stable and bagRecord()==partial,'invalid encrypted empty quantity was diffed')
w16(sb+0x3be,0xabcd);R.update()
-- Actual purchases remain reversible, including a partial new-slot write.
w32(sb+0x290,1500~0x3210abcd);R.update();assert(R.purchase)
w16(sb+0x316,2~0xabcd);partial=bagRecord();R.update()
assert(bagRecord()==partial and R.purchase,'partial slot damaged inventory/purchase evidence')
w16(sb+0x314,14);R.update()
assert(r16(sb+0x314)==0 and (r16(sb+0x316)~0xabcd)==0,'banned purchase was missed after partial slot write')
assert((r16(sb+0x312)~0xabcd)==3 and (r16(sb+0x3ba)~0xabcd)==1,'purchase removed pre-owned items')
assert((r32(sb+0x290)~0x3210abcd)==2100,'stable purchase refund incorrect')
w32(sb+0x290,2000~0x3210abcd);R.update();assert(R.purchase)
w32(0x02020000+0xf20,0x3210abcd);w32(GameSettings.gSaveBlock2ptr,0x02020000)
w16(sb+0x550,134);w16(sb+0x552,1~0xabcd);R.update()
assert((r16(sb+0x552)~0xabcd)==1 and not R.purchase,'save-block relocation reused earlier spending evidence')
w32(GameSettings.gSaveBlock2ptr,sb2);R.update()
print('PASS: bag/currency validation, encrypted empty slots, menu rekey races, owned items and exact purchase reversal')
-- Withdrawing a dead mon is caught before it can be used.
w8(GameSettings.gPlayerPartyCount,2);mon(1,24,25,20,0)
w32(0x030030f4,0x08000001);R.update()
assert(memory.read_u8(GameSettings.gPlayerPartyCount)==2,'compacted a live menu party')
assert(r16(GameSettings.pstats+100+86)==0,'withdrawn dead mon usable in menu')
w32(0x030030f4,0x080565c9);R.update()
assert(memory.read_u8(GameSettings.gPlayerPartyCount)==1,'dead mon resurrected')
-- Full party loss ends, including the lab's automatic recovery path.
w16(GameSettings.pstats+86,0);R.update();assert(R.ended and paused,'team wipe not enforced')
-- Every Gen 3 data permutation must keep a valid checksum after removing an item.
R.ended=false
for permutation=0,23 do
    local pid=2400+permutation
    w8(GameSettings.gPlayerPartyCount,2);local a,g=mon(0,pid,25,0,197);mon(1,48,19,20,0)
    assert(R.deposit(a,false),'deposit failed')
    local target
    for slot=0,419 do local candidate=0x02029800+4+slot*80;if r32(candidate)==pid then target=candidate;break end end
    assert(target,'boxed mon missing')
    local sum=0
    for i=0,11 do local word=r32(target+32+i*4)~pid~0x12345678;sum=(sum+(word&65535)+(word>>16))&65535 end
    assert(sum==r16(target+28),'checksum failed for permutation '..permutation)
end
-- The Old Man demo reports CAUGHT without adding a Pokemon. Its tracker flag
-- can clear while Battle.inBattleScreen remains true, or only appear late.
R.ended=false;paused=false;R.battle=nil;R.routes={};R.firstBattle=false;R.pending=nil;R.dead={};R.rejected={}
mon(0,48,19,20,0)
w32(GameSettings.gBattleTypeFlags,0x200)
Battle.inBattleScreen=true;Battle.isWildEncounter=true
w8(GameSettings.gBattleOutcome,0);Program.inCatchingTutorial=false
R.update()
assert(not R.battle and not R.firstBattle,'demo became a real battle before tutorial flag')
R.battle={wild=true,route=88,before={}}
Program.inCatchingTutorial=true;R.update()
assert(not R.battle,'late tutorial detection retained a real battle snapshot')
Program.inCatchingTutorial=false;w8(GameSettings.gBattleOutcome,7);R.update()
assert(not R.ended and not R.pending and not R.routes[88],'demo catch ended or consumed run')
Battle.inBattleScreen=false;R.update()
assert(not R.ended and not R.pending and not R.routes[88],'demo exit became a real catch')
-- Even a stale snapshot at the first non-battle frame must not consume a route.
R.battle={wild=true,route=88,before={}};w8(GameSettings.gBattleOutcome,1);R.update()
assert(not R.routes[88] and not R.ended,'stale tutorial outcome became a wild KO')
-- Tutorial flags persist outside battle: normal held-item guards still work.
local a,g=mon(0,48,19,20,197);R.update()
assert((r32(g)~48~0x12345678)>>16==0,'persistent tutorial flag disabled field guards')
-- A subsequent real catch still asks for confirmation, and a second KO fails.
w32(GameSettings.estats,32);w32(GameSettings.estats+4,0) -- non-shiny identity
w32(GameSettings.gBattleTypeFlags,4);w8(GameSettings.gBattleOutcome,0)
Battle.inBattleScreen=true;R.update();assert(R.battle and R.firstBattle)
w8(GameSettings.gPlayerPartyCount,2);mon(1,4800,25,20,0)
Battle.inBattleScreen=false;w8(GameSettings.gBattleOutcome,7);R.update()
assert(R.pending and R.pending.species==25 and not R.routes[88] and paused,'real catch bypassed confirmation')
R.keepCapture();assert(R.routes[88] and not R.pending and not paused)
Battle.inBattleScreen=true;w8(GameSettings.gBattleOutcome,0);R.update()
Battle.inBattleScreen=false;w8(GameSettings.gBattleOutcome,1);R.update()
assert(R.ended and R.reason=='Rule broken: Second wild KO at this location.','real second KO was exempted')
-- Unexplained real catches retain the original fail-closed behavior.
R.ended=false;paused=false;R.routes={}
Battle.inBattleScreen=true;w8(GameSettings.gBattleOutcome,0);R.update()
Battle.inBattleScreen=false;w8(GameSettings.gBattleOutcome,7);R.update()
assert(R.ended and R.reason=='Catch data unclear: Run stopped.','unknown real catch was exempted')
-- The mandatory unveiled Tower ghost is a story KO, including on a used route.
-- Unlike the tutorial, real damage/death and stolen-item guards must still run.
for _,usedBefore in ipairs({false,true}) do
    R.ended=false;paused=false;R.battle=nil;R.pending=nil;R.dead={};R.rejected={};R.routes={[88]=usedBefore or nil}
    for slot=1,5 do for offset=0,99 do w8(GameSettings.pstats+slot*100+offset,0) end end
    w8(GameSettings.gPlayerPartyCount,1);mon(0,48,19,20,0)
    Battle.inBattleScreen=true;w32(GameSettings.gBattleTypeFlags,0xa000);w8(GameSettings.gBattleOutcome,0);R.update()
    assert(R.battle and R.battle.storyGhost,'mandatory ghost not recognized')
    Battle.inBattleScreen=false;w8(GameSettings.gBattleOutcome,1);R.update()
    assert(not R.ended and not paused and not R.pending,'mandatory story KO stopped play')
    assert(not not R.routes[88]==usedBefore,'story KO changed route availability')
end
-- Identification may arrive after the first tracker frame and clear before exit.
R.routes={};Battle.inBattleScreen=true;w32(GameSettings.gBattleTypeFlags,0x8000);w8(GameSettings.gBattleOutcome,0);R.update()
assert(R.battle and not R.battle.storyGhost,'ordinary unidentified ghost was exempted')
w32(GameSettings.gBattleTypeFlags,0xa000);R.update();assert(R.battle.storyGhost,'late ghost flag was missed')
Battle.inBattleScreen=false;w32(GameSettings.gBattleTypeFlags,0);w8(GameSettings.gBattleOutcome,1);R.update()
assert(not R.ended and not R.routes[88],'cleared ghost flag lost story exception')
-- A reused legendary bit, ordinary ghost or ordinary wild KO still violates.
for _,flags in ipairs({0,0x2000,0x8000,0x20000}) do
    R.ended=false;paused=false;R.battle=nil;R.routes={[88]=true}
    Battle.inBattleScreen=true;w32(GameSettings.gBattleTypeFlags,flags);w8(GameSettings.gBattleOutcome,0);R.update()
    Battle.inBattleScreen=false;w8(GameSettings.gBattleOutcome,1);R.update()
    assert(R.ended and paused,'normal encounter bypassed second-KO rule: '..flags)
end
-- Stale story flags in the field do not suppress normal held-item guards.
R.ended=false;paused=false;R.dead={};R.rejected={};R.battle=nil
w32(GameSettings.gBattleTypeFlags,0xa000);local storyMon,storyGrowth=mon(0,48,19,20,197);R.update()
assert((r32(storyGrowth)~48~0x12345678)>>16==0,'story flags disabled field item guard')
-- Losing the mandatory ghost fight is still a genuine Standard team wipe.
Battle.inBattleScreen=true;w8(GameSettings.gBattleOutcome,0);w16(storyMon+86,0);R.update()
assert(R.ended and paused and R.dead[string.format('%08x:%08x',48,0x12345678)],'story ghost exempted a real death')
Battle.inBattleScreen=false;w32(GameSettings.gBattleTypeFlags,0)
print('PASS: mandatory Tower ghost used/unused routes, flag races, ordinary encounters and real deaths')
-- Model the actual frame-boundary failure: game functions temporarily decrypt
-- records and update count/slots in separate instructions. Guards must wait.
local coreFrame=0
miyoo.coreFrame=function()return coreFrame end
local function step()coreFrame=coreFrame+1;R.update()end
local function crypt(a)
    local key=r32(a)~r32(a+4)
    for i=0,11 do w32(a+32+i*4,r32(a+32+i*4)~key) end
end
local function record(a,n)
    local t={};for i=0,(n or 100)-1 do t[#t+1]=string.char(memory.read_u8(a+i)) end
    return table.concat(t)
end
local function checksumValid(a)
    local key=r32(a)~r32(a+4);local sum=0
    for i=0,23 do local shift=(i%2)*16;sum=(sum+((r16(a+32+i*2)~((key>>shift)&65535))&65535))&65535 end
    return sum==r16(a+28)
end
Battle.inBattleScreen=false;w8(GameSettings.gBattleOutcome,4)
w32(0x030030f4,0x08000001) -- Remain in a menu until the final transfer check.
for permutation=0,23 do
    R.ended=false;paused=false;R.battle=nil;R.pending=nil;R.dead={};R.rejected={};R.seen={}
    R.unstableFrames=0;R.lastUnstableFrame=nil;R.unstableReported=nil
    w8(GameSettings.gPlayerPartyCount,2)
    local pid=7200+permutation
    local lead=mon(0,pid,25,0,197);local survivor=mon(1,48,19,20,0)
    local id=string.format('%08x:%08x',pid,0x12345678)
    R.seen[id]=true;R.seen['00000030:12345678']=true
    crypt(lead);local transient=record(lead)
    step()
    assert(record(lead)==transient and not R.dead[id] and not R.ended,'modified decrypted lead '..permutation)
    assert(not R.deposit(lead,false),'deposited a decrypted record')
    crypt(lead)
    w8(GameSettings.gPlayerPartyCount,1);local intact=record(lead)
    step()
    assert(record(lead)==intact and not R.dead[id] and not R.ended,'count/slot race caused a wipe')
    w8(GameSettings.gPlayerPartyCount,2)
    crypt(survivor);transient=record(survivor);step()
    assert(record(survivor)==transient and not R.dead[id],'edited team while survivor decrypted')
    crypt(survivor);local originalSurvivor=record(survivor);step()
    assert(R.dead[id] and not R.ended and not paused,'one actual death ended a two-mon team')
    assert(checksumValid(lead) and memory.read_u8(lead+19)==2,'death produced an invalid/bad-egg record')
    assert(record(survivor)==originalSurvivor,'death damaged the surviving mon')
    w32(0x030030f4,0x080565c9);step()
    assert(memory.read_u8(GameSettings.gPlayerPartyCount)==1 and record(GameSettings.pstats)==originalSurvivor,'graveyard damaged the survivor')
    local grave
    for slot=0,419 do local a=0x02029800+4+slot*80;if r32(a)==pid then grave=a;break end end
    assert(grave and checksumValid(grave) and memory.read_u8(grave+19)==2,'graveyard record corrupted')
    w32(0x030030f4,0x08000001)
end
-- UI/cursor frames do not turn a single interrupted core frame into a failure.
R.ended=false;paused=false;R.dead={};R.rejected={};R.seen={};R.unstableFrames=0;R.lastUnstableFrame=nil
w8(GameSettings.gPlayerPartyCount,2);local lead=mon(0,9600,25,0,197);mon(1,48,19,20,0)
crypt(lead);step()
for i=1,1000 do R.update() end
assert(not paused and R.unstableFrames==1,'paused cursor frames triggered integrity halt')
for i=1,119 do step() end
assert(paused and not R.ended and R.unstableReported,'persistent corruption was scored as a loss')
io.open=oldopen
print('PASS: route/capture/tutorial rules, all 24 permutations, decrypted-frame/count races, two-mon deaths, graveyard integrity, cursor pause and persistent-data halt')
