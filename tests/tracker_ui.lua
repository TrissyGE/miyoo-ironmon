-- Real-core UI integration test. Use ONLY an isolated app directory with an
-- active battle state. This intentionally edits that test installation's notes.
assert(os.getenv('IRONMON_UI_QA')=='1','UI QA must be explicitly enabled')
local marker=assert(io.open('../data/.qa-allow','r'),'isolated QA marker missing');marker:close()
local original=dofile
local layout=original('../tracker_layout.lua')
local enemy,baseline,noteText,abilityControl,abilityIndex
local function point(x,y,r)
    r=r or {0,0,390,160,0,96,640,263}
    miyoo.pointer(math.floor(r[5]+(x-r[1]+.5)*r[7]/r[3]),math.floor(r[6]+(y-r[2]+.5)*r[8]/r[4]))
end
local function controlPoint(c)
    local form=MiyooDialogs.controls[MiyooDialogs.active]
    local scale=math.min(378/form.Width,135/math.max(1,form.Height-36))
    local ox=6+(378-form.Width*scale)/2
    point(ox+(c.Left+c.Width/2)*scale,19+(c.Top+c.Height/2)*scale)
end
local function controls(kind)
    local list={}
    for _,c in pairs(MiyooDialogs.controls) do if c.parent==MiyooDialogs.active and c.kind==kind then list[#list+1]=c end end
    table.sort(list,function(a,b)return a.Top<b.Top end);return list
end
dofile=function(path)
    local result=original(path)
    if path=='../qol.lua' then
        local input=MiyooQol.input
        MiyooQol.input=function()
            input()
            local frame=miyoo.frame();local b=0
            local panels=layout.panels(miyoo.viewport())
            if frame==50 then
                assert(Battle.inActiveBattle(),'load an active battle state')
                Battle.isViewingOwn=false;Program.changeScreenView(TrackerScreen);Program.redraw(true)
                enemy=assert(Tracker.getViewedPokemon()).pokemonID
                baseline=Tracker.getStatMarkings(enemy).hp
            elseif frame==60 then miyoo.setCursor(true);point(373,13,panels[2])
            elseif frame==70 then b=256
            elseif frame==90 then assert(Tracker.getStatMarkings(enemy).hp==(baseline+1)%4,'scaled stat click failed')
            elseif frame==100 then b=1024 -- L: select HP marking
            elseif frame==110 then b=2048 -- R: change marking
            elseif frame==130 then assert(Tracker.getStatMarkings(enemy).hp==(baseline+2)%4,'L/R marking failed')
            elseif frame==140 then b=8
            elseif frame==160 then assert(Battle.isViewingOwn,'Start failed to switch to own Pokemon');console.log('PASS: stat click, L/R marking, Start own view')
            elseif frame==210 then b=8
            elseif frame==240 then assert(not Battle.isViewingOwn,'Start failed to switch to enemy');b=4
            elseif frame==270 then
                assert(MiyooDialogs.active,'Select did not open original note editor')
                abilityControl=assert(controls('dropdown')[1]);controlPoint(abilityControl)
            elseif frame==280 then b=256
            elseif frame==300 then
                assert(MiyooDialogs.dropdown,'mapped ability dropdown click failed')
                for i,name in ipairs(abilityControl.items) do if name=='Intimidate' then abilityIndex=i end end
                assert(abilityIndex,'ability dropdown is incomplete')
            elseif frame>=320 and frame<=380 and frame%8==0 and MiyooDialogs.dropdown then
                local page=(abilityIndex-1)//15+1
                if MiyooDialogs.dropdown.page<page then point(155,142)
                else local slot=(abilityIndex-1)%15;point(68+(slot%3)*127,31+(slot//3)*21) end
                b=256
            elseif frame==395 then assert(not MiyooDialogs.dropdown and abilityControl.text=='Intimidate','ability selection failed')
            elseif frame==410 then controlPoint(assert(controls('textbox')[1]));b=256
            elseif frame==430 then assert(MiyooDialogs.keyboard,'mapped note textbox failed');point(22,53)
            elseif frame==440 then b=256
            elseif frame==450 then point(336,142);b=256
            elseif frame==470 then assert(not MiyooDialogs.keyboard,'keyboard Done failed');noteText=controls('textbox')[1].text;assert(noteText:sub(-1)=='1','keyboard key failed')
            elseif frame==490 then controlPoint(assert(controls('button')[1]));b=256
            elseif frame==520 then
                assert(not MiyooDialogs.active,'original Save & Close failed')
                assert(Tracker.getNote(enemy)==noteText,'note did not save')
                local ability=Tracker.getAbilities(enemy)[1].id
                assert(AbilityData.Abilities[ability].name=='Intimidate','ability guess did not save')
                Tracker.AutoSave.saveToFile()
                console.log('PASS: note editor, dropdown paging, guessed ability, keyboard, persistent save')
            elseif frame==600 then point(273,99,panels[3])
            elseif frame==610 then b=256
            elseif frame==640 then assert(Program.currentScreen==InfoScreen,'move info click failed');b=1
            elseif frame==670 then assert(Program.currentScreen==TrackerScreen,'B failed to return from details');console.log('PASS: original move info page and B back') end
            miyoo.setButtons(b)
        end
    end
    return result
end
original('../bootstrap.lua')
