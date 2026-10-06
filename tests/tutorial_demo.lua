-- Replays the real Old Man battle in an isolated, already-repaired checkpoint.
-- Only the QA copy's Old Man scene variable is reset; inputs start the actual
-- script and battle engine. Never run or deploy this in the live installation.
assert(os.getenv('IRONMON_TUTORIAL_QA')=='1','tutorial test requires isolated QA')
local marker=assert(io.open('../data/.qa-allow','r'));marker:close()
local original=dofile
local started=false
local completed=false
local routes
local function routeKeys()
    local keys={};for k in pairs(MiyooRules.routes) do keys[#keys+1]=k end
    table.sort(keys);return table.concat(keys,',')
end
dofile=function(path)
    local result=original(path)
    if path:match('Program%.lua$') then
        local mainLoop=Program.mainLoop
        Program.mainLoop=function()
            mainLoop()
            local frame=miyoo.frame()
            local R=MiyooRules
            if frame==500 then
                assert(R.loaded and not R.ended and R.routeName():find('Viridian',1,true),'QA checkpoint not ready')
                routes=routeKeys()
                local sb=memory.read_u32_le(GameSettings.gSaveBlock1ptr)
                memory.write_u16_le(sb+(GameSettings.gameVarsOffset or 0x1000)+(0x4051-0x4000)*2,1)
            end
            local demo=(memory.read_u32_le(GameSettings.gBattleTypeFlags)&0x200)~=0
            local outcome=memory.read_u8(GameSettings.gBattleOutcome)
            if frame>500 and demo and outcome==0 then
                if not started then console.log('REAL TUTORIAL START',frame) end
                started=true
                assert(not R.battle,'demo created a real capture snapshot')
            elseif started and outcome==7 and not Battle.inBattleScreen then
                if not completed then console.log('REAL TUTORIAL CAUGHT',frame) end
                completed=true
            end
            assert(not R.ended and not R.pending,'real demo triggered capture guard')
            if routes then assert(routes==routeKeys(),'demo consumed an encounter') end
            if frame%1000==0 then
                console.log('TUTORIAL PROGRESS',frame,outcome,Battle.inBattleScreen,
                    string.format('callback=%08x mainflags=%x',memory.read_u32_le(0x030030f4),memory.read_u8(0x03003529)))
            end
            if frame==3790 then
                assert(started and completed,'did not complete the real tutorial')
                console.log('PASS: full Old Man demo, caught outcome, unchanged routes and playable run')
            end
            miyoo.setButtons(frame%30<3 and 256 or 0)
        end
    end
    return result
end
original('../bootstrap.lua')
