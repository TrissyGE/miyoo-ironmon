-- Actual controller-driven Safari menu test; never run against a live app.
-- Use a populated Safari checkpoint with the start-menu cursor on POKEMON.
assert(os.getenv('IRONMON_SAFARI_QA')=='1','Safari QA requires explicit isolation')
local marker=assert(io.open('../data/.qa-allow'));marker:close()
local original=dofile
local baseline,menuSeen,submenuSeen,lastKey,keyChanges=nil,false,false,nil,0
local function bag()
    local sb=memory.read_u32_le(GameSettings.gSaveBlock1ptr)
    local sb2=memory.read_u32_le(GameSettings.gSaveBlock2ptr)
    if sb<0x02000000 or sb>0x0203c000 or sb2<0x02000000 or sb2>0x0203f000 then return end
    local key=memory.read_u32_le(sb2+0xf20)
    local money=memory.read_u32_le(sb+0x290)~key
    if money>999999 then return end -- An interrupted encryption frame is not a complete observation.
    local entries={}
    for _,p in ipairs({{0x310,42},{0x3b8,30},{0x430,13},{0x464,58},{0x54c,43}}) do
        for i=0,p[2]-1 do
            local id=memory.read_u16_le(sb+p[1]+i*4)
            if id~=0 then
                local n=memory.read_u16_le(sb+p[1]+i*4+2)~(key&0xffff)
                if n==0 or n>999 then return end
                entries[#entries+1]=id..':'..n
            end
        end
    end
    table.sort(entries)
    return table.concat(entries,','),money,key
end
dofile=function(path)
    local result=original(path)
    if path:match('Program%.lua$') then
        local loop=Program.mainLoop
        Program.mainLoop=function()
            loop()
            if MiyooRules.loaded then
                local items,money,key=bag()
                if items then
                    if not baseline then
                        assert(MiyooRules.routeName():find('Safari',1,true),'use a Safari checkpoint')
                        assert(#items>100,'use a populated bag including non-shop items')
                        baseline={items=items,money=money}
                    end
                    assert(items==baseline.items,'Safari menus changed owned items/quantities')
                    assert(money==baseline.money,'Safari menus changed money')
                    if lastKey and key~=lastKey then keyChanges=keyChanges+1 end
                    lastKey=key
                end
                assert(not MiyooRules.ended and not MiyooRules.pending,'menu test stopped the run')
                menuSeen=menuSeen or Program.isInStartMenu()
                submenuSeen=submenuSeen or memory.read_u32_le(0x030030f4)~=0x080565c9
            end
            local frame=miyoo.frame();local stage=frame<1200 and frame%600 or -1
            local b=0
            if stage>=60 and stage<65 then b=8 -- START
            elseif frame<600 and stage>=80 and stage<85 then b=32 -- DOWN: POKEMON -> BAG
            elseif stage>=110 and stage<115 then b=256 -- A
            elseif (stage>=200 and stage<205) or (stage>=350 and stage<355) then b=1 end -- B
            miyoo.setButtons(b)
            if frame==1290 then
                local items,money=bag()
                assert(baseline and items==baseline.items and money==baseline.money,'final bag changed')
                assert(menuSeen and submenuSeen and keyChanges>=2,'actual menus/rekey transitions were not exercised')
                assert(not Program.isInStartMenu(),'did not return from the menus')
                console.log('PASS: real Safari start/bag menus, key transitions, unchanged owned items and money')
            end
        end
    end
    return result
end
original('../bootstrap.lua')
