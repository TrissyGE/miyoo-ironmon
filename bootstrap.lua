-- Adapter for the upstream Ironmon-Tracker. This is an independent frontend,
-- not BizHawk; the compatibility version selects the graphical tracker API.
local originalDofile = dofile
originalDofile('../forms.lua')
originalDofile('../rules.lua')
originalDofile('../qol.lua')
dofile = function(path)
    local result = originalDofile(path)
    if path:match('[/\\]Main%.lua$') then
        Main.CheckForVersionUpdate = function() end
        Main.DisplayError = function(message) console.log(message) end
        Main.LoadNextRom = function()
            if MiyooRules and not MiyooRules.canReset() then return end
            Main.ExitSafely(false)
            miyoo.newRun()
        end
        Main.GenerateNextRom = Main.LoadNextRom
        Main.LoadRom = Main.LoadNextRom
        Main.ReadAttemptsCount = function()
            local f = io.open('../data/attempt.txt','r')
            Main.currentSeed = f and tonumber(f:read('*a')) or 1
            if f then f:close() end
            Main.currentSeed = Main.currentSeed or 1
        end
        local exitSafely = Main.ExitSafely
        Main.ExitSafely = function(crashed)
            if Tracker and Tracker.AutoSave then Tracker.AutoSave.saveToFile() end
            exitSafely(crashed)
        end
        local initialize = Main.Initialize
        Main.Initialize = function()
            local ok = initialize()
            if ok then
                Options['Refocus emulator after load'] = false
                Options['Animated Pokemon popout'] = false
                Options['Show card pack on screen after capturing a GachaMon'] = false
                Options['GachaMon Ratings Ruleset'] = 'Standard'
                Options['Generate ROM each time'] = true
                Options.CONTROLS['Load next seed'] = 'NOTBOUND' -- Native held combo prevents accidental resets.
                Options.CONTROLS['Toggle view'] = 'Start'
                Options['Game Over condition'] = 'EntirePartyFaints'
                Options['Enable restore points'] = false
                Options.FILES['Source ROM'] = '../source.gba'
                Options.FILES['Settings File'] = '../standard.rnqs'
                Options.FILES['Randomizer JAR'] = '../PokeRandoZX.jar'
                Options.PATHS['Java Path'] = '../runtime/bin/java'
                local f = io.open('../data/attempt.txt','r')
                if f then Main.currentSeed = tonumber(f:read('*a')) or 1; f:close() end
            end
            return ok
        end
    elseif path:match('[/\\]QuickloadScreen%.lua$') then
        QuickloadScreen.getGameProfileTdatPath = function() return '../data/current.tdat' end
    elseif path:match('[/\\]Program%.lua$') then
        local mainLoop = Program.mainLoop
        Program.mainLoop = function()
            Options['Game Over condition']='EntirePartyFaints'
            Options['Enable restore points']=false
            Options.CONTROLS['Load next seed']='NOTBOUND'
            mainLoop()
            MiyooRules.update()
            MiyooQol.input()
            MiyooDialogs.draw()
        end
    elseif path:match('[/\\]GameOverScreen%.lua$') then
        GameOverScreen.LossConditions.EntirePartyFaints=function() return MiyooRules.ended end
        GameOverScreen.createTempSaveState = function() end
        GameOverScreen.loadTempSaveState = function() end
        for _,key in ipairs({'RetryBattle','ContinuePlaying'}) do
            GameOverScreen.Buttons[key].isVisible=function() return false end
            GameOverScreen.Buttons[key].onClick=function() end
        end
    elseif path:match('[/\\]TrackerScreen%.lua$') then
        local chooseBall=TrackerScreen.randomlyChooseBall
        TrackerScreen.randomlyChooseBall=function()
            if MiyooRules.starterSlot then TrackerScreen.PokeBalls.chosenBall=MiyooRules.starterSlot;return MiyooRules.starterSlot end
            return chooseBall()
        end
        local drawBall=TrackerScreen.drawBallPicker
        TrackerScreen.drawBallPicker=function()
            if MiyooRules.starterSlot then TrackerScreen.PokeBalls.chosenBall=MiyooRules.starterSlot end
            drawBall()
        end
        TrackerScreen.Buttons.RerollBallPicker.onClick=function()
            MiyooRules.notify('Starter wurde vorab ausgelost: kein Reroll.')
        end
    elseif path:match('[/\\]TimeMachineScreen%.lua$') then
        TimeMachineScreen.createRestorePoint=function() end
        TimeMachineScreen.checkCreatingRestorePoint=function() end
        TimeMachineScreen.restorePoint=function() end
    elseif path:match('[/\\]Utils%.lua$') then
        Utils.bit_and = function(a,b) return math.floor(a) & math.floor(b) end
        Utils.bit_or = function(a,b) return math.floor(a) | math.floor(b) end
        Utils.bit_xor = function(a,b) return math.floor(a) ~ math.floor(b) end
        -- The tracker also uses shifts wider than 32 bits to serialize GachaMons.
        Utils.bit_lshift = function(a,b) return math.floor(a) * (2 ^ b) end
        Utils.bit_rshift = function(a,b) return math.floor(a / (2 ^ b)) end
    end
    return result
end
originalDofile('Ironmon-Tracker.lua')
