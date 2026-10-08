-- Read/advance ONLY an isolated repaired copy of the failed Tower checkpoint.
assert(os.getenv('IRONMON_GHOST_QA')=='1','ghost test requires isolated QA')
local marker=assert(io.open('../data/.qa-allow','r'));marker:close()
local original=dofile
local inspected=false
local routes
local function routeKeys()
    local keys={};for k,v in pairs(MiyooRules.routes) do if v then keys[#keys+1]=k end end
    table.sort(keys);return table.concat(keys,',')
end
dofile=function(path)
    local result=original(path)
    if path:match('Program%.lua$') then
        local loop=Program.mainLoop
        Program.mainLoop=function()
            loop()
            local R=MiyooRules
            if R.loaded and not inspected then
                inspected=true;routes=routeKeys()
                console.log('TOWER SNAPSHOT',string.format('flags=%x outcome=%d map=%s route=%s used=%s',
                    memory.read_u32_le(GameSettings.gBattleTypeFlags),memory.read_u8(GameSettings.gBattleOutcome),
                    tostring(Program.GameData.mapId),R.routeName(),tostring(R.routes[R.routeKey()])))
                assert((memory.read_u32_le(GameSettings.gBattleTypeFlags)&0xa000)==0xa000 and
                    memory.read_u8(GameSettings.gBattleOutcome)==1,'checkpoint is not a won mandatory ghost fight')
                assert(R.routeName():find('Tower 6F',1,true) and R.routes[R.routeKey()],'checkpoint lacks the used Tower encounter')
                assert(not R.ended and not R.pending,'repaired checkpoint remains blocked')
            end
            if inspected then
                assert(not R.ended and not R.pending,'resume triggered a new rule loss or catch')
                assert(routes==routeKeys(),'resume changed encounter records')
            end
            -- Actual A inputs finish the original post-victory story messages.
            miyoo.setButtons(miyoo.frame()%30<3 and 256 or 0)
            if miyoo.frame()==590 then
                local sb=memory.read_u32_le(GameSettings.gSaveBlock1ptr)
                local scene=memory.read_u16_le(sb+(GameSettings.gameVarsOffset or 0x1000)+(0x4059-0x4000)*2)
                assert(inspected and scene==1,'ghost story has not completed naturally')
                assert(memory.read_u32_le(0x030030f4)==0x080565c9,'did not return to playable overworld')
                assert(not Battle.inBattleScreen and not GameOverScreen.isDisplayed and not MiyooQol.menu,'resume still shows game over')
                console.log('PASS: restored Tower ghost checkpoint, natural story completion, playable overworld and unchanged encounters')
            end
        end
    end
    return result
end
original('../bootstrap.lua')
