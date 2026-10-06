-- Real-core regression: create a second valid QA-only teammate, let the enemy
-- KO the 1-HP lead, switch, win, and verify the graveyard plus surviving team.
assert(os.getenv('IRONMON_PARTY_QA')=='1','party battle test requires isolated QA')
local marker=assert(io.open('../data/.qa-allow','r'));marker:close()
local rb,rw,rd=memory.read_u8,memory.read_u16_le,memory.read_u32_le
local wb,ww,wd=memory.write_u8,memory.write_u16_le,memory.write_u32_le
local original=dofile
local stage=0
local leadId,leadPid,survivorPid
local function checksum(a)
    local key=rd(a)~rd(a+4);local sum=0
    for i=0,23 do sum=(sum+((rw(a+32+i*2)~((key>>((i%2)*16))&65535))&65535))&65535 end
    return sum
end
local function validMon(a)return (rb(a+19)&3)==2 and checksum(a)==rw(a+28) end
local function encode(a,pid,tid,blocks)
    wd(a,pid);wd(a+4,tid);local key=pid~tid
    local names={'growth','attack','effort','misc'};local sum=0
    for b,name in ipairs(names) do
        local offset=32+(MiscData.TableData[name][pid%24+1]-1)*12
        for i=0,2 do local v=blocks[b][i+1];wd(a+offset+i*4,v~key);sum=(sum+(v&65535)+(v>>16))&65535 end
    end
    ww(a+28,sum)
    assert(validMon(a),'invalid QA fixture')
end
dofile=function(path)
    local result=original(path)
    if path:match('Program%.lua$') then
        local mainLoop=Program.mainLoop
        Program.mainLoop=function()
            mainLoop()
            local f=miyoo.frame();local R=MiyooRules;local key=0
            if stage==0 and f>=60 and Battle.inActiveBattle() then
                local a=GameSettings.pstats
                if not validMon(a) then return end
                assert(rb(GameSettings.gPlayerPartyCount)==1,'fixture needs a one-mon battle')
                leadPid=rd(a);local tid=rd(a+4);local oldKey=leadPid~tid
                leadId=string.format('%08x:%08x',leadPid,tid)
                local blocks={}
                for b,name in ipairs({'growth','attack','effort','misc'}) do
                    local offset=32+(MiscData.TableData[name][leadPid%24+1]-1)*12
                    blocks[b]={};for i=0,2 do blocks[b][i+1]=rd(a+offset+i*4)~oldKey end
                end
                blocks[1][1]=(blocks[1][1]&65535)|(185<<16)
                encode(a,leadPid,tid,blocks)
                local next=a+100
                for i=0,99 do wb(next+i,rb(a+i)) end
                survivorPid=(leadPid+1)&0xffffffff
                blocks[1][1]=blocks[1][1]&65535
                blocks[2]={33|(33<<16),33|(33<<16),35|(35<<8)|(35<<16)|(35<<24)}
                encode(next,survivorPid,tid,blocks)
                -- Keep the cloned level consistent with its real experience.
                ww(next+86,100);ww(next+88,100)
                for i=90,98,2 do ww(next+i,100) end
                wb(GameSettings.gPlayerPartyCount,2)
                R.seen[string.format('%08x:%08x',survivorPid,tid)]=true
                -- Set one HP, not zero: the enemy must cause the actual KO.
                ww(a+86,1);ww(GameSettings.gBattleMons+0x28,1)
                stage=1;console.log('PARTY QA: two valid mons; lead at one HP')
            elseif stage==1 then
                key=f%30<3 and 256 or 0 -- Magic Coat; enemy Thundershock KOs the lead.
                if rw(GameSettings.pstats+86)==0 then
                    stage=2;console.log('PARTY QA: natural lead KO',f)
                end
            elseif stage==2 then
                -- A accepts the replacement prompt; one Down pulse selects slot 2.
                key=f%240<3 and 32 or (f%30<3 and 256 or 0)
                if rw(GameSettings.gBattlerPartyIndexes)==1 then
                    stage=3;console.log('PARTY QA: switched to surviving mon',f)
                end
            elseif stage==3 then
                key=f%30<3 and 256 or 0 -- Strong surviving teammate wins with Tackle.
                if rd(0x030030f4)==0x080565c9 and not Battle.inBattleScreen then
                    stage=4;console.log('PARTY QA: won and returned to field',f)
                end
            end
            assert(not R.ended,'one lead death incorrectly ended the Standard run')
            if stage>=2 and rb(GameSettings.gPlayerPartyCount)==2 then
                assert((rb(GameSettings.pstats+19)&1)==0,'lead became a Bad Egg')
                assert((rb(GameSettings.pstats+100+19)&1)==0,'survivor became a Bad Egg')
            end
            if f%500==0 then
                console.log('PARTY PROGRESS',f,miyoo.coreFrame(),stage,rb(GameSettings.gBattleOutcome),
                    string.format('callback=%08x',rd(0x030030f4)),R.unstableFrames,R.unstableReported,R.pending,
                    rw(GameSettings.pstats+86),rw(GameSettings.pstats+100+86))
            end
            if f==4190 then
                assert(stage==4 and rb(GameSettings.gPlayerPartyCount)==1,'did not complete KO, switch, win and graveyard transfer')
                assert(rd(GameSettings.pstats)==survivorPid and rw(GameSettings.pstats+86)>0 and validMon(GameSettings.pstats),'surviving mon corrupted')
                assert(R.dead[leadId],'natural KO was not journaled')
                local base=rd(0x03005010);local grave
                for slot=0,419 do local a=base+4+slot*80;if rd(a)==leadPid then grave=a;break end end
                assert(grave and validMon(grave),'graveyard contains an invalid/Bad Egg record')
                local g=grave+32+(MiscData.TableData.growth[leadPid%24+1]-1)*12
                assert(((rd(g)~rd(grave)~rd(grave+4))>>16)==0,'dead item remains accessible')
                console.log('PASS: natural lead KO, second mon switch/win, valid graveyard, removed item and surviving Standard run')
            end
            miyoo.setButtons(key)
        end
    end
    return result
end
original('../bootstrap.lua')
