-- smart math inspired by https://github.com/Coffeelot/cw-racingapp/blob/main/html/src/helpers/gameToMap.ts
local longitudeTransforms = { a = -4.38407057047e-09, b = 0.019935666257721, c = -97.224922143314 }
local latitudeTransforms = { a = 2.4480481560015e-14, b = -2.6058899468842e-10, c = -7.0754974317837e-07, d = 0.019323267489522, e = 11.908728964674 }

local function gameToMap(x, y)
    local lng = longitudeTransforms.a * x ^ 2 + longitudeTransforms.b * x + longitudeTransforms.c
    local lat = latitudeTransforms.a * y ^ 4 + latitudeTransforms.b * y ^ 3 + latitudeTransforms.c * y ^ 2 + latitudeTransforms.d * y + latitudeTransforms.e
    return lng, lat
end

AddEventHandler('playerDropped', function(reason, resourceName, clientDropReason)
    local src = source --[[@as number]]
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local lon, lat = gameToMap(playerCoords.x, playerCoords.y)
    local params = ClassifyDrop({ reason = reason, resource = resourceName, category = clientDropReason })

    lib.logger(src, params.category, params.cleanReason or reason, ('lon:%s'):format(lon), ('lat:%s'):format(lat), ('resource:%s'):format(params.resource or resourceName))
end)

-- I don't know what the performance impact of this is. Use at your own risk.
-- CreateThread(function()
--     while true do
--         for _, playerId in ipairs(GetPlayers()) do
--             local ped = GetPlayerPed(playerId)
--             if ped then
--                 local coords = GetEntityCoords(ped)
--                 local lon, lat = gameToMap(coords.x, coords.y)
--                 lib.logger(tonumber(playerId), 'heatmap', 'update', ('lon:%s'):format(lon), ('lat:%s'):format(lat))
--             end
--         end
--         Wait(15000)
--     end
-- end)
