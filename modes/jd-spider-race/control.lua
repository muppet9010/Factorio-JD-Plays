local EventScheduler = require("utility/event-scheduler")
local GuiActionsClick = require("utility.gui-actions-click")
local Utils = require("utility/utils")

local PlayerHome = require("modes/jd-spider-race/scripts/player-home")
local WaterBarrier = require("modes/jd-spider-race/scripts/water-barrier")
local Spider = require("modes.jd-spider-race.scripts.spider")
local Map = require("modes.jd-spider-race.scripts.map")

if settings.startup["jdplays_mode"].value ~= "jd_spider_race" then
    return
end

local function CreateGlobals()
    global.general = global.general or {}
    global.general.surfaceName = "jd-spider-race"
    global.general.surface = global.general.surface or nil ---@type LuaSurface
    global.general.perTeamMapHeight = 512 -- Tested at 1024, but "should" accept any size.

    PlayerHome.CreateGlobals()
    Map.CreateGlobals()
    WaterBarrier.CreateGlobals()
    Spider.CreateGlobals()
end

local function OnLoad()
    --Any Remote Interface registration calls can go in here or in root of control.lua
    PlayerHome.OnLoad()
    Map.OnLoad()
    Spider.OnLoad()
    WaterBarrier.OnLoad()
end

--local function OnSettingChanged(event)
--if event == nil or event.setting == "xxxxx" then
--  local x = tonumber(settings.global["xxxxx"].value)
--end
--end

local function OnStartup()
    CreateGlobals()
    OnLoad()
    --OnSettingChanged(nil)

    Utils.DisableIntroMessage()

    -- Do first as sets teams and surfaces.
    PlayerHome.OnStartup()
    Map.OnStartup()

    -- Regular startup (non ordered).
    WaterBarrier.OnStartup()
    Spider.OnStartup()
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
--script.on_event(defines.events.on_runtime_mod_setting_changed, OnSettingChanged)
script.on_load(OnLoad)
EventScheduler.RegisterScheduler()
GuiActionsClick.MonitorGuiClickActions()

--- Do the on_damaged_event in an ultra UPS optimised manner.
script.on_event(
    defines.events.on_entity_damaged,
    ---@param event on_entity_damaged
    function(event)
        -- Check all events for the cross player damage.
        PlayerHome.OnEntityDamaged(event)

        -- Very limtied cases need the boss spider damage reaction run.
        if event.final_damage_amount > 0 then
            local entityDamagedName = event.entity.name
            if entityDamagedName == "jd_plays-jd_spider_race-spidertron_boss" then
                Spider.OnBossSpiderEntityDamaged(event)
            end
        end
    end,
    {
        -- Don't give us events when biter units or spawners are damaged. We only care about player force type entities.
        -- Worms are "turrets", so this blacklist filter can't exclude them :(
        {filter = "type", type = "unit", invert = true},
        {filter = "type", type = "unit-spawner", invert = true, mode = "and"}
        -- As the spidertron is a player type entity, the biter unit and spawner exclusion filters work appropriately for it also.
    }
)

-- Mod wide function interface table creation. Means EmmyLua can support it and saves on UPS cost of old Interface function middelayer.
---@class InternalInterfaces
MOD.Interfaces = MOD.Interfaces or {} ---@type table<string, function>
--[[
    Populate and use from within module's OnLoad() functions with simple table reference structures, i.e:
        MOD.Interfaces.Tunnel = MOD.Interfaces.Tunnel or {}
        MOD.Interfaces.Tunnel.CompleteTunnel = Tunnel.CompleteTunnel
--]]
--
