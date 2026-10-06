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
assert(R.ended and R.reason=='Regelbruch: Zweiter Wild-KO an diesem Ort.','real second KO was exempted')
-- Unexplained real catches retain the original fail-closed behavior.
R.ended=false;paused=false;R.routes={}
Battle.inBattleScreen=true;w8(GameSettings.gBattleOutcome,0);R.update()
Battle.inBattleScreen=false;w8(GameSettings.gBattleOutcome,7);R.update()
assert(R.ended and R.reason=='Fangdaten unklar: Run angehalten.','unknown real catch was exempted')
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
