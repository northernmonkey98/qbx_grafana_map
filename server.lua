-- smart math inspired by https://github.com/Coffeelot/cw-racingapp/blob/main/html/src/helpers/gameToMap.ts
local transforms = {
    band1 = { longitude = {a = -3.03663255576895e-09, b = 0.0200175350440883, c = -97.211789757094}, latitude = {a = 6.23122700084464e-14, b = 4.20129073856139e-10, c = 2.33168021020044e-06, d = 0.0240131069198339, e = 14.1346597090657} },
    band2 = { longitude = {a = 2.04927570146569e-08, b = 0.0199382651698616, c = -97.2328189248356}, latitude = {a = -5.48114969721267e-14, b = -1.7644651413213e-10, c = -6.69398961485353e-07, d = 0.019446455419011, e = 11.948776738614} },
    band3 = { longitude = {a = 1.14491978248603e-08, b = 0.0199665146367798, c = -97.2865999889282}, latitude = {a = -7.50970630543969e-15, b = 2.42587620752238e-10, c = -3.39800162545523e-06, d = 0.02514652658967, e = 7.49474095495398} },
    band4 = { longitude = {a = -4.51344244634536e-08, b = 0.0200135106227036, c = -97.1355799536373}, latitude = {a = -2.33545837309061e-14, b = 6.7194107532233e-10, c = -7.73181068541832e-06, d = 0.0443322941450463, e = -23.9182574396233} },
}

local function gameToMap(x, y)
    local t
    if y < -1000 then
        t = transforms.band1
    elseif y < 2000 then
        t = transforms.band2
    elseif y < 5000 then
        t = transforms.band3
    else
        t = transforms.band4
    end

    local lng = t.longitude.a * x^2 + t.longitude.b * x + t.longitude.c
    local lat = t.latitude.a * y^4 + t.latitude.b * y^3 + t.latitude.c * y^2 + t.latitude.d * y + t.latitude.e
    return lng, lat
end

exports('gameToMap', gameToMap)

AddEventHandler('playerDropped', function(reason, resourceName, clientDropReason)
    local src = source --[[@as number]]
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local lon, lat = gameToMap(playerCoords.x, playerCoords.y)
    local params = ClassifyDrop({ reason = reason, resource = resourceName, category = clientDropReason })

    lib.logger(src, params.category, params.cleanReason or reason, ('lon:%s'):format(lon), ('lat:%s'):format(lat), ('resource:%s'):format(params.resource or resourceName))
end)

AddEventHandler('explosionEvent', function(sender, params)
    local playerCoords = GetEntityCoords(GetPlayerPed(sender))
    local lon, lat = gameToMap(params.posX, params.posY)
    lib.logger(tonumber(sender), 'explosion', ('%s triggered explosion type: %s | distance: %s'):format(GetPlayerName(sender), params.explosionType, #(playerCoords - vector3(params.posX, params.posY, params.posZ))), ('lon:%s'):format(lon), ('lat:%s'):format(lat), json.encode(params))
end)


AddEventHandler('baseevents:onPlayerDied', function(killerType, deathCoords)
    local src = source --[[@as number]]
    local playerCoords
    if deathCoords then
        playerCoords = vector3(deathCoords.x, deathCoords.y, deathCoords.z)
    else
        playerCoords = GetEntityCoords(GetPlayerPed(src))
    end
    local lon, lat = gameToMap(playerCoords.x, playerCoords.y)
    lib.logger(src, 'death', ('Player died (killerType: %s)'):format(killerType or 'unknown'), ('lon:%s'):format(lon), ('lat:%s'):format(lat))
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
