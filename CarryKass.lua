--[[


kekw


]]
--[[ require ]]
require("common.log")
module("Carry Kass", package.seeall, log.setup)
clean.module("Carry Kass", package.seeall, log.setup)
--[[ SDK ]]
local SDK         = _G.CoreEx
local Libs        = _G.Libs

local Obj         = SDK.ObjectManager
local Event       = SDK.EventManager
local Game        = SDK.Game
local Enums       = SDK.Enums
local Geo         = SDK.Geometry
local Renderer    = SDK.Renderer
local Input       = SDK.Input
--[[Libraries]] 
local TS          = _G.Libs.TargetSelector()
local Menu        = _G.Libs.NewMenu
local Orb         = _G.Libs.Orbwalker
local Collision   = _G.Libs.CollisionLib
local Pred        = _G.Libs.Prediction
local HealthPred  = _G.Libs.HealthPred
local DmgLib      = _G.Libs.DamageLib
local ImmobileLib = _G.Libs.ImmobileLib
local Spell       = _G.Libs.Spell

local LocalPlayer = Obj.Player.AsHero

-- Check if we are using the right champion
if LocalPlayer.CharName ~= "Kassadin" then return false end
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
local Kassadin = {}
local KassadinHP = {}
local KassadinNP = {}
local LastSheen = os.clock()
local LastLichBane = os.clock()
local ItemSlots = require("lol/Modules/Common/ItemID")
--[[Spells]] 
local Q = Spell.Targeted({
    Slot = Enums.SpellSlots.Q,
    Range = 650,
    Delay = 0.25,
    Key = "Q",
})
local W = Spell.Active({
    Slot = Enums.SpellSlots.W,
    Delay = 0,
    Range = 150,
    Key = "W",
})
local E = Spell.Skillshot({
    Slot = Enums.SpellSlots.E,
    Range =  600,
    Delay = 0.25,
    Speed = math.huge,
    Key = "E",
    Type = "Cone"
})
local R = Spell.Skillshot({
    Slot = Enums.SpellSlots.R,
    Delay = 0.25,
    Range = 500,
    Radius = 150,
    Speed = math.huge,
    Type = "Circular",
    Key = "R",
})
local Summoner1 = Spell.Skillshot({
    Slot = Enums.SpellSlots.Summoner1,
    Range = 400,
    Key = "I"
})
local Summoner2 = Spell.Skillshot({
    Slot = Enums.SpellSlots.Summoner2,
    Range = 400,
    Key = "I"
})
--[[Startup]] 
local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or LocalPlayer.IsDead or LocalPlayer.IsRecalling)
end

function Kassadin.OnHighPriority() 
    if not GameIsAvailable() then
        return
    end
    if Kassadin.Auto() then return end
    local ModeToExecute = KassadinHP[Orb.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

function Kassadin.OnNormalPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = KassadinNP[Orb.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

--[[Draw]] 
function Kassadin.OnDraw()
    local Pos = LocalPlayer.Position
    local spells = {Q,E,R}
    for k, v in pairs(spells) do
        if Menu.Get("Drawing."..v.Key..".Enabled", true) and v:IsReady() then
            Renderer.DrawCircle3D(Pos, v.Range, 30, 3, Menu.Get("Drawing."..v.Key..".Color"))
        end
    end
end

--[[Helper Functions]]
local function GetRStacks()
    local buff = LocalPlayer:GetBuff("RiftWalk")
    if buff then
        return buff.Count
    else 
        return 0
    end
end


local function CanCast(spell,mode)
    return spell:IsReady() and Menu.Get(mode .. ".Cast"..spell.Key)
end

local function HitChance(spell)
    return Menu.Get("Chance."..spell.Key)
end

local function Lane(spell)
    return spell:IsReady() and Menu.Get("Lane."..spell.Key)
end

local function LastHit(spell)
    return Menu.Get("LastHit."..spell.Key) and spell:IsReady()
end

local function Structure(spell)
    return Menu.Get("Structure."..spell.Key) and spell:IsReady()
end

local function Jungle(spell)
    return spell:IsReady() and Menu.Get("Jungle."..spell.Key)
end

local function Flee(spell)
    return Menu.Get("Flee."..spell.Key) and spell:IsReady()
end

local function KS(spell)
    return Menu.Get("KS."..spell.Key) and spell:IsReady()
end

local function GetTargetsRange(Range)
    return {TS:GetTarget(Range,true)}
end

local function GetTargets(Spell)
    return {TS:GetTarget(Spell.Range,true)}
end

local function CountHeroes(pos,Range,type)
    local num = 0
    for k, v in pairs(Obj.Get(type, "heroes")) do
        local hero = v.AsHero
        if hero and hero.IsTargetable and not hero.IsMe and hero:Distance(pos.Position) < Range then
            num = num + 1
        end
    end
    return num
end

local function Count(spell,team,type)
    local num = 0
    for k, v in pairs(Obj.Get(team, type)) do
        local minion = v.AsAI
        local Tar    = spell:IsInRange(minion) and minion.MaxHealth > 6 and minion.IsTargetable and not Orb.IsLasthitMinion(minion)
        if minion and Tar then
            num = num + 1
        end
    end
    return num
end

local function ValidAI(minion,Range)
    local AI = minion.AsAI
    return AI.IsTargetable and AI.MaxHealth > 6 and AI:Distance(LocalPlayer) < Range
end

local function ValidAItospell(minion,spell1,spell2)
    local AI = minion.AsAI
    return AI.IsTargetable and AI.MaxHealth > 6 and spell1:IsInRange(AI) and not spell2:IsInRange(AI) 
end

local function SortMinion(list)
    table.sort(list, function(a, b) return a.MaxHealth > b.MaxHealth end)
    return list
end

local function IsUnderTurrent(pos)
    local sortme = {}
    for k, v in pairs(Obj.Get("enemy", "turrets")) do
        if not v.IsDead and v.IsTurret then 
            table.insert(sortme,v)
        end
    end
    table.sort(sortme,function(a, b) return b:Distance(LocalPlayer) > a:Distance(LocalPlayer) end)
    for  k,v  in ipairs(sortme) do 
        return v:Distance(pos) <= 870
    end
end

local function CastFlash(spell,Castpos)
    return spell:Cast(Castpos)
end

local function FlashR(spell,obj)
    local Castpos = LocalPlayer.Position:Extended(obj.Position, obj:Distance(LocalPlayer))
    if not R:IsReady() or R:IsInRange(obj) or Castpos:IsWall() then return end
    return R:Cast(Castpos) and delay(50,CastFlash,spell,Castpos) 
end

local function dmg(spell)
    local dmg = 0
    local Extra = (40 + (R:GetLevel() - 1) * 10) + (0.1 * LocalPlayer.TotalAP) + LocalPlayer.MaxMana * 0.01
    if spell.Key == "Q" then 
        dmg = (65 + (Q:GetLevel() - 1) * 30) + (0.7 * LocalPlayer.TotalAP)
    end
    if spell.Key == "E" then 
        dmg = (80 + (E:GetLevel() - 1) * 25) + (0.8 * LocalPlayer.TotalAP)
    end
    if spell.Key == "R" then
        dmg = (80 + (R:GetLevel() - 1) * 20) + (0.4 * LocalPlayer.TotalAP) + LocalPlayer.MaxMana * 0.02 + (Extra * GetRStacks())
    end
    return math.floor(dmg) 
end

local function Wdmg()
    local dmg = 0
    local Extra = 0
    local passive = 20 + (0.1 * LocalPlayer.TotalAP)
    local time = os.clock()
    for v, k in pairs(LocalPlayer.Items) do
        local id = k.ItemId
        if id == ItemSlots.LichBane then
            if (time >= LastLichBane or LocalPlayer:GetBuff("lichbane")) then 
                Extra = LocalPlayer.BaseAD * 1.5 + LocalPlayer.TotalAP * 0.4
            end
        end
    end
    dmg = (70 + (W:GetLevel() - 1) * 25) + (0.8 * LocalPlayer.TotalAP)
    return math.floor(dmg + Extra + passive) 
end

local function dmgsheen()
    local dmg = 0
    local time = os.clock()
    for v, k in pairs(LocalPlayer.Items) do
        local id = k.ItemId
        if id == ItemSlots.Sheen then
            if (time >= LastSheen or LocalPlayer:GetBuff("sheen")) then 
                dmg = LocalPlayer.BaseAD 
            end
        end
    end
    return math.floor(dmg) 
end

local function TotalDmg(t)
    local Damage = DmgLib.CalculatePhysicalDamage(LocalPlayer,t,LocalPlayer.TotalAD)
    if Q:IsReady() then
        Damage = Damage + DmgLib.CalculateMagicalDamage(LocalPlayer,t,dmg(Q))
    end
    if W:IsReady() then
        Damage = Damage + DmgLib.CalculateMagicalDamage(LocalPlayer,t,Wdmg()) + DmgLib.CalculatePhysicalDamage(LocalPlayer,t,dmgsheen())
    end
    if E:IsReady() then
        Damage = Damage + DmgLib.CalculateMagicalDamage(LocalPlayer,t,dmg(E))
    end
    if R:IsReady() then
        Damage = Damage + DmgLib.CalculateMagicalDamage(LocalPlayer,t,dmg(R))
    end
    return Damage
end

--[[Events]]
function Kassadin.Auto()
    if Menu.Get("Flash.R") then
        Orb.Orbwalk(Renderer.GetMousePos())
        for k, obj in pairs(GetTargetsRange(Summoner1.Range + R.Range)) do 
            if Summoner1:IsReady() and Summoner1:GetName() == "SummonerFlash" then 
                if FlashR(Summoner1,obj) then return end
            end
            if Summoner2:IsReady() and Summoner2:GetName() == "SummonerFlash" then 
                if FlashR(Summoner2,obj) then return end
            end
        end
    end
    if KS(Q) then
        for k,v in pairs(GetTargets(Q)) do 
            local dmg = DmgLib.CalculateMagicalDamage(LocalPlayer,v,dmg(Q))
            local Ks  = Q:GetKillstealHealth(v)
            if dmg > Ks and Q:Cast(v) then return end
        end
    end
    if KS(E) then
        for k,v in pairs(GetTargets(E)) do 
            local dmg = DmgLib.CalculateMagicalDamage(LocalPlayer,v,dmg(E))
            local Ks  = E:GetKillstealHealth(v)
            if dmg > Ks and E:CastOnHitChance(v,0.75) then return end
        end
    end
    if KS(R) then
        for k,v in pairs(GetTargets(R)) do 
            local dmg = DmgLib.CalculateMagicalDamage(LocalPlayer,v,dmg(R))
            local Ks  = R:GetKillstealHealth(v)
            if dmg > Ks and R:Cast(v.Position) then return end
        end
    end
end

function Kassadin.OnBuffLost(sender,Buff)
    if not sender.IsMe then return end
    if Buff.Name == "sheen" then 
        LastSheen = os.clock() + 2
    end
    if Buff.Name == "lichbane" then 
        LastLichBane = os.clock() + 3
    end
end

function Kassadin.OnPreAttack(args)
    local Target = args.Target.AsAI
    local mode = Orb.GetMode()
    if not Target or not W:IsReady() then return end
    if mode == "Combo" and Target.IsHero then 
        if CanCast(W,mode) and Menu.Get("WDrop") == 0 then 
            if W:Cast() then return end
        end
    end
    if mode == "Harass" and Target.IsHero and Menu.Get("ManaSlider") < LocalPlayer.ManaPercent * 100 then 
        if CanCast(W,mode) and Menu.Get("hWDrop") == 0 then 
            if W:Cast() then return end
        end
    end
end

function Kassadin.OnInterruptibleSpell(source, spell, danger, endT, canMove)
    if not (source.IsEnemy and Menu.Get("Misc.QI") and Q:IsReady() and danger > 2) then return end
    if not Menu.Get("2" .. source.AsHero.CharName) then return end
    if Q:IsInRange(source) and Q:Cast(source) then
        return 
    end
end

function Kassadin.OnGapclose(Source, DashInstance)
    if not (Source.IsEnemy) then return end
    if not Menu.Get("3" .. Source.AsHero.CharName) then return end
    if Menu.Get("Misc.Q") and Q:IsReady() then
        if Q:IsInRange(Source) and Q:Cast(Source) then
            return 
        end 
    end
end

function Kassadin.OnPostAttack(targets)
    local Target = targets.AsAI
    local mode = Orb.GetMode()
    if not Target or not W:IsReady() then return end
    if mode == "Combo" and Target.IsHero then 
        if CanCast(W,mode) and Menu.Get("WDrop") == 1 then 
            if W:Cast() then return end
        end
    end
    if mode == "Harass" and Target.IsHero and Menu.Get("ManaSlider") < LocalPlayer.ManaPercent * 100 then 
        if CanCast(W,mode) and Menu.Get("hWDrop") == 1 then 
            if W:Cast() then return end
        end
    end
    if Target.IsStructure and Structure(W) then 
        if W:Cast() then return end
    end
end

function Kassadin.OnDrawDamage(target, dmgList)
    if Menu.Get("DrawDmg") then 
        table.insert(dmgList,TotalDmg(target))
    end
end

--[[Orbwalker Recallers]]
function KassadinHP.Combo()
    local mode = "Combo"
    if CanCast(R,mode) and GetRStacks() <= Menu.Get("Combo.RS")then 
        for k,v in pairs(GetTargets(R)) do 
            if IsUnderTurrent(v.Position) and not Menu.Get("UseR") then return end
            if R:Cast(v.Position) then return end
        end
    end
end

function  KassadinNP.Combo()
    local mode = "Combo"
    if CanCast(Q,mode) then 
        for k,v in pairs(GetTargets(Q)) do 
            if v:Distance(LocalPlayer) < LocalPlayer.AttackRange + 50 and W:IsReady() then return end
            if Q:Cast(v) then return end
        end
    end
    if CanCast(E,mode) then 
        for k,v in pairs(GetTargets(E)) do 
            if E:CastOnHitChance(v,HitChance(E)) then return end
        end
    end
end

function KassadinNP.Harass()
    local mode = "Harass"
    if Menu.Get("ManaSlider") > LocalPlayer.ManaPercent * 100 then return end
    if CanCast(Q,mode) then 
        for k,v in pairs(GetTargets(Q)) do 
            if v:Distance(LocalPlayer) < LocalPlayer.AttackRange + 50 and W:IsReady() then return end
            if Q:Cast(v) then return end
        end
    end
    if CanCast(E,mode) then 
        for k,v in pairs(GetTargets(E)) do 
            if E:CastOnHitChance(v,HitChance(E)) then return end
        end
    end
end

function KassadinHP.Waveclear()
    if Menu.Get("ManaSliderLane") < LocalPlayer.ManaPercent * 100 and Menu.Get("SpellFarm") then 
        if Lane(E) then 
            local EPoint = {}
            for k, v in pairs(Obj.Get("enemy", "minions")) do
                if ValidAI(v,E.Range) then
                    local minion = v.AsAI
                    local pos = minion:FastPrediction(Game.GetLatency()+ E.Delay)
                    local isKillable = DmgLib.CalculateMagicalDamage(LocalPlayer, minion, dmg(E)) > minion.Health
                    if pos:Distance(LocalPlayer.Position) < E.Range then
                        table.insert(EPoint, pos)
                    end
                end                       
            end
            local bestPos, hitCount =  Geo.BestCoveringCone(EPoint,LocalPlayer.Position, 60)
            if bestPos and hitCount >= Menu.Get("Lane.EH") then
                if E:Cast(bestPos) then return end
            end
        end
        if Lane(R) and GetRStacks() <= Menu.Get("Lane.RS") and not E:IsReady() then 
            local RPoint = {}
            for k, v in pairs(Obj.Get("enemy", "minions")) do
                if ValidAI(v,R.Range) then
                    local minion = v.AsAI
                    local pos = minion:FastPrediction(Game.GetLatency()+ R.Delay)
                    if pos:Distance(LocalPlayer.Position) < R.Range then
                        table.insert(RPoint, pos)
                    end
                end                       
            end
            local bestPos, hitCount = R:GetBestCircularCastPos(RPoint, 250)
            if bestPos and hitCount >= Menu.Get("Lane.RH") then
                if R:Cast(bestPos) then return end
            end
        end
    end
    if Jungle(E) then 
        for k,v in pairs(Obj.Get("neutral","minions")) do
            if ValidAI(v,E.Range) then  
                if E:Cast(v.Position) then return end
            end
        end
    end
    if Jungle(R) and GetRStacks() <= Menu.Get("Jungle.RS") then 
        for k,v in pairs(Obj.Get("neutral","minions")) do
            if ValidAI(v,R.Range) then  
                if R:Cast(v.Position) then return end
            end
        end
    end
end

function KassadinNP.Waveclear()
    if Menu.Get("ManaSliderLane") < LocalPlayer.ManaPercent * 100 and Menu.Get("SpellFarm") then 
        if Lane(W) then 
            for k,v in pairs(Obj.Get("enemy","minions")) do
                local minion = v.AsAI
                local trueRange = W.Range + LocalPlayer.BoundingRadius + minion.BoundingRadius
                if ValidAI(v,trueRange) then 
                    local healthPred = W:GetHealthPred(minion)
                    local WDmg = DmgLib.CalculateMagicalDamage(LocalPlayer, minion, Wdmg())
                    local AADmg = math.floor(LocalPlayer.TotalAD)
                    local Sheendmg = DmgLib.CalculatePhysicalDamage(LocalPlayer, minion, dmgsheen())
                    if healthPred > 0 and healthPred < WDmg + AADmg + Sheendmg then 
                        Orb.StopIgnoringMinion(minion)
                        if W:Cast() then return end
                    end       
                end
            end  
        end 
        if Lane(Q) then 
            for k,v in pairs(Obj.Get("enemy","minions")) do
                if ValidAItospell(v,Q,W) then 
                    local minion = v.AsAI
                    local healthPred = Q:GetHealthPred(minion)
                    local QDmg = DmgLib.CalculateMagicalDamage(LocalPlayer, minion, dmg(Q))
                    if healthPred > 0 and healthPred < QDmg then 
                        if Q:Cast(minion) then return end
                    end       
                end
            end
        end
    end
    if Jungle(W) then 
        for k,v in pairs(Obj.Get("neutral","minions")) do
            local minion = v.AsAI
            local trueRange = W.Range + LocalPlayer.BoundingRadius + minion.BoundingRadius
            if ValidAI(v,trueRange) then 
                if W:Cast() then return end 
            end
        end  
    end 
    if Jungle(Q) then 
        for k,v in pairs(Obj.Get("neutral","minions")) do
            if ValidAI(v,Q.Range) then  
                if Q:Cast(v) then return end
            end
        end
    end
end

function KassadinHP.Lasthit()
    if LastHit(E) then 
        local EPoint = {}
        for k, v in pairs(Obj.Get("enemy", "minions")) do
            if ValidAI(v,E.Range) then
                local minion = v.AsAI
                local pos = minion:FastPrediction(Game.GetLatency()+ E.Delay)
                local isKillable = DmgLib.CalculateMagicalDamage(LocalPlayer, minion, dmg(E)) > minion.Health
                if pos:Distance(LocalPlayer.Position) < E.Range and isKillable then
                    table.insert(EPoint, pos)
                end
            end                       
        end
        local bestPos, hitCount =  Geo.BestCoveringCone(EPoint,LocalPlayer.Position, 60)
        if bestPos and hitCount >= Menu.Get("LastHit.EH") then
            if E:Cast(bestPos) then return end
        end
    end
    if LastHit(R) and GetRStacks() <= Menu.Get("LastHit.RS") and not E:IsReady() then 
        local RPoint = {}
        for k, v in pairs(Obj.Get("enemy", "minions")) do
            if ValidAI(v,R.Range) then
                local minion = v.AsAI
                local pos = minion:FastPrediction(Game.GetLatency()+ R.Delay)
                local isKillable = DmgLib.CalculateMagicalDamage(LocalPlayer, minion, dmg(R)) > minion.Health
                if pos:Distance(LocalPlayer.Position) < R.Range and isKillable then
                    table.insert(RPoint, pos)
                end
            end                       
        end
        local bestPos, hitCount = R:GetBestCircularCastPos(RPoint, 250)
        if bestPos and hitCount >= Menu.Get("LastHit.RH") then
            if R:Cast(bestPos) then return end
        end
    end
end

function KassadinNP.Lasthit()
    local list = {}
    for k,v in pairs(Obj.Get("enemy","minions")) do
        local trueRange = W.Range + LocalPlayer.BoundingRadius + v.AsAI.BoundingRadius
        if ValidAI(v,trueRange) then 
            table.insert(list,v.AsAI)
        end
    end
    if not list then return end
    SortMinion(list)
    if LastHit(W) then 
        for k,minion in pairs(list) do 
            local healthPred = W:GetHealthPred(minion)
            local WDmg = DmgLib.CalculateMagicalDamage(LocalPlayer, minion, Wdmg())
            local AADmg = math.floor(LocalPlayer.TotalAD)
            local Sheendmg = DmgLib.CalculatePhysicalDamage(LocalPlayer, minion, dmgsheen())
            if healthPred > 0 and healthPred < WDmg + AADmg + Sheendmg then 
                Orb.StopIgnoringMinion(minion)
                if W:Cast() then return end
            end       
        end  
    end 
    if LastHit(Q) then 
        for k,v in pairs(Obj.Get("enemy","minions")) do
            local minion = v.AsAI
            if ValidAItospell(minion,Q,W) then 
                local healthPred = Q:GetHealthPred(minion)
                local QDmg = DmgLib.CalculateMagicalDamage(LocalPlayer, minion, dmg(Q))
                if healthPred > 0 and healthPred < QDmg then 
                    if Q:Cast(minion) then return end
                end       
            end
        end
    end
end

function KassadinNP.Flee()
    if Flee(R) then
        local CastPos = LocalPlayer.Position:Extended(Renderer.GetMousePos(), R.Range)
        if CastPos:IsWall() then return end
        if R:Cast(CastPos) then return end
    end
end

--[[Menu]]
function Kassadin.LoadMenu()
    Menu.RegisterMenu("CarryKass", "Carry Kass", function()
        Menu.NewTree("Combo", "Combo Options", function()
            Menu.Checkbox("Combo.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Combo.CastW",   "Use [W]", true)
            Menu.Dropdown("WDrop","^ W mode",0,{"Pre Attack", "Post Attack"})
            Menu.Checkbox("Combo.CastE",   "Use [E]", true)
            Menu.Checkbox("Combo.CastR",   "Use [R]", true)
            Menu.Slider("Combo.RS","Use R when Buff Count = X",4,0,4)
            Menu.Keybind("Flash.R", "Flash R Key", string.byte('T'))
        end)
            Menu.NewTree("Harass", "Harass Options", function()
            Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
            Menu.Slider("ManaSlider","",50,0,100)
            Menu.Checkbox("Harass.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Harass.CastW",   "Use [W]", true)
            Menu.Dropdown("hWDrop","^ W mode",0,{"Pre Attack", "Post Attack"})
            Menu.Checkbox("Harass.CastE",   "Use [E]", false)
        end)
        Menu.NewTree("Waveclear", "Waveclear Options", function()
            Menu.NewTree("Lane", "Lane Options", function() 
                Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
                Menu.Slider("ManaSliderLane","",50,0,100)
                Menu.Checkbox("Lane.Q",   "Use [Q]", true)
                Menu.Checkbox("Lane.W",   "Use [W]", true)
                Menu.Checkbox("Lane.E",   "Use [E]", true)
                Menu.Slider("Lane.EH","E HitCount",3,1,5)
                Menu.Checkbox("Lane.R",   "Use [R]", true)
                Menu.Slider("Lane.RS","Use R when Buff Count = X",1,0,4)
                Menu.Slider("Lane.RH","R HitCount",3,1,5)
            end)
            Menu.NewTree("Lasthit", "Lasthit Options", function() 
                Menu.Checkbox("LastHit.Q",   "Use [Q] ", true)
                Menu.Checkbox("LastHit.W",   "Use [W] ", true)
                Menu.Checkbox("LastHit.E",   "Use [E]", true)
                Menu.Slider("LastHit.EH","E HitCount",3,1,5)
                Menu.Checkbox("LastHit.R",   "Use [R]", true)
                Menu.Slider("LastHit.RS","Use R when Buff Count = X",1,0,4)
                Menu.Slider("LastHit.RH","R HitCount",3,1,5)
            end)
            Menu.NewTree("Structure", "Structure Options", function() 
                Menu.Checkbox("Structure.W",   "Use [W]", true)
            end)
            Menu.NewTree("Jungle", "Jungle Options", function() 
                Menu.Checkbox("Jungle.Q",   "Use [Q]", true)
                Menu.Checkbox("Jungle.W",   "Use [W]", true)
                Menu.Checkbox("Jungle.E",   "Use [E]", true)
                Menu.Checkbox("Jungle.R",   "Use [R]", true)
                Menu.Slider("Jungle.RS","Max R Count | Only use When = X",1,0,4)
            end)
        end)
        Menu.NewTree("KillSteal", "KillSteal Options", function()
            Menu.Checkbox("KS.Q"," Use Q", true)
            Menu.Checkbox("KS.E"," Use E", true)
            Menu.Checkbox("KS.R"," Use R", true)
        end)
        Menu.NewTree("Flee", "Flee Options", function()
            Menu.Checkbox("Flee.R"," Use R", true)
        end)
        Menu.NewTree("Prediction", "Prediction Options", function()
            Menu.Slider("Chance.E","HitChance [E]",0.6, 0, 1, 0.05)
        end)
        Menu.NewTree("Misc", "Misc Options", function()
            Menu.Checkbox("Misc.QI",   "Use [Q] on Interrupter", true)
            Menu.NewTree("Interrupter", "Interrupter Whitelist", function()
                for k, v in pairs(Obj.Get("enemy", "heroes")) do
                    local Name = v.AsHero.CharName
                    Menu.Checkbox("2" .. Name, "Use on " .. Name, true)
                end
            end)
            Menu.Checkbox("Misc.Q",   "Use [Q] on gapclose", true)
            Menu.NewTree("gapclose", "gapclose Whitelist", function()
                for k, v in pairs(Obj.Get("enemy", "heroes")) do
                    local Name = v.AsHero.CharName
                    Menu.Checkbox("3" .. Name, "Use on " .. Name, true)
                end
            end)
        end)
        Menu.NewTree("Draw", "Drawing Options", function()
            Menu.Checkbox("Drawing.Q.Enabled",   "Draw [Q] Range",true)
            Menu.ColorPicker("Drawing.Q.Color", "Draw [Q] Color", 0x118AB2FF)
            Menu.Checkbox("Drawing.E.Enabled",   "Draw [E] Range",true)
            Menu.ColorPicker("Drawing.E.Color", "Draw [E] Color", 0x118AB2FF)
            Menu.Checkbox("Drawing.R.Enabled",   "Draw [R] Range",true)
            Menu.ColorPicker("Drawing.R.Color", "Draw [R] Color", 0x118AB2FF)
            Menu.Checkbox("DrawDmg",   "Draw Total Dmg",true)
            Menu.Checkbox("DrawPer",   "Draw permaShow Menu ",true)
        end)
    end)
    Menu.RegisterPermashow("KassadinPermaShow", "          Carry Kass : Toggle Keys           ", function()
        Menu.Keybind("SpellFarm", "SpellFarm", string.byte("M"), true, false)
        Menu.Keybind("UseR", "R UnderTurret", string.byte("N"), true, false)
    end, function() 
        return Menu.Get("DrawPer")
    end)
end

-- LOAD
function OnLoad()
    Kassadin.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Kassadin[eventName] then
            Event.RegisterCallback(eventId, Kassadin[eventName])
        end
    end    
    return true
end