--[[
    Modify all lamps to turn on earlier. So they don't flash on post dusk.
    We don't want them on when its basically fully bright, but on the time its not bright as it gets dark fast.
]]

for _, prototype in pairs(data.raw["lamp"]) do
    prototype.darkness_for_all_lamps_on = 0.15 -- default is 0.5
    prototype.darkness_for_all_lamps_off = 0.1 -- default is 0.3
end
