-- Capture real UI frames only in an isolated battle fixture, never user saves.
assert(os.getenv('IRONMON_SCREENSHOT_QA')=='1','screenshots require isolated QA')
local marker=assert(io.open('../data/.qa-allow'));marker:close()
local mode=os.getenv('IRONMON_SCREENSHOT_MODE') or 'own'
local original=dofile
dofile=function(path)
    local result=original(path)
    if path=='../qol.lua' then
        local input=MiyooQol.input
        MiyooQol.input=function()
            input()
            if miyoo.frame()==80 then
                assert(Battle.inActiveBattle(),'load an active battle fixture')
                Battle.isViewingOwn=false
                local enemy=assert(Tracker.getViewedPokemon()).pokemonID
                -- Illustrative player guesses in QA notes; no hidden data is read.
                Tracker.setAbilities(enemy,'Intimidate')
                Tracker.TrackNote(enemy,'Watch Attack drops')
                Battle.isViewingOwn=mode=='own'
                Program.changeScreenView(TrackerScreen);Program.redraw(true)
                if mode=='notes' then TrackerScreen.openNotePadWindow(enemy)
                elseif mode=='menu' then MiyooQol.toggleMenu();MiyooQol.help=true end
                client.pause()
            end
            if miyoo.frame()==290 then
                assert(not MiyooRules.ended and not MiyooRules.pending,'fixture was stopped by a guard')
                console.log('PASS: real screenshot',mode)
            end
        end
    end
    return result
end
original('../bootstrap.lua')
