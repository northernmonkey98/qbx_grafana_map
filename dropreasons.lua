--[[
    This file is based on code from citizenfx/txAdmin
    https://github.com/citizenfx/txAdmin

    Copyright (c) 2019-2025 André Tabarra <maintainer@txadmin.gg>
    Licensed under the MIT License.
    See the LICENSE file in the project root or https://github.com/citizenfx/txAdmin/blob/master/LICENSE
]]

local PDL_CRASH_REASON_CHAR_LIMIT = 512
local PDL_UNKNOWN_REASON_CHAR_LIMIT = 320

local playerInitiatedRules = {
    "exiting",
    "disconnected.",
    "connecting to another server",
    "could not find requested level",
    "entering rockstar editor",
    "quit:",
    "reconnecting",
    "reloading game",
}

local serverInitiatedRules = {
    "disconnected by server:",
    "server shutting down:",
    "[txadmin]",
}

local timeoutRules = {
    "server->client connection timed out",
    "connection timed out",
    "timed out after 60 seconds",
}

local securityRules = {
    "reliable network event overflow",
    "reliable network event size overflow:",
    "reliable server command overflow",
    "reliable state bag packet overflow",
    "unreliable network event overflow",
    "connection to cnl timed out",
    "server command overflow",
    "invalid client configuration. restart your game and reconnect",
}

local crashRulesIntl = {
    "game crashed: ",
    "o jogo crashou: ",
    "le jeu a cessé de fonctionner : ",
    "spielabsturz: ",
    "el juego crasheó: ",
    "تعطلت العبة: ",
    "spel werkt niet meer: ",
    "oyun çöktü: ",
    "a játék összeomlott: ",
    "il gioco ha smesso di funzionare: ",
    "游戏发生崩溃：",
    "遊戲已崩潰: ",
    "pád hry: ",
    "spelet kraschade: ",
}

local exceptionPrefixesIntl = {
    "unhandled exception: ",
    "exceção não tratada: ",
    "exception non-gérée : ",
    "unbehandelte ausnahme: ",
    "excepción no manejada: ",
    "استثناء غير معالج: ",
    -- Dutch doesn't have a translation for "unhandled exception"
    "i̇şlenemeyen özel durum: ",
    "nem kezelt kivétel: ",
    "eccezione non gestita: ",
    "未处理的异常：",
    "未處理的異常： ",
    "neošetřená výjimka: ",
    "okänt fel: ",
}

local function truncateReason(reason, maxLength, prefix)
    prefix = prefix or ""
    if prefix ~= "" then
        maxLength = maxLength - #prefix
    end
    local truncationSuffix = "[truncated]"
    if #reason == 0 then
        return prefix .. "[tx:empty-reason]"
    elseif #reason > maxLength then
        return prefix .. string.sub(reason, 1, maxLength - #truncationSuffix) .. truncationSuffix
    else
        return prefix .. reason
    end
end

local function startsWith(str, start)
    return string.sub(str, 1, #start) == start
end

local function toLower(str)
    return string.lower(str)
end

local function cleanCrashReason(reason)
    local cutoffIdx = string.find(reason, ": ")
    if not cutoffIdx then return truncateReason(reason, PDL_CRASH_REASON_CHAR_LIMIT) end
    local msg = string.sub(reason, cutoffIdx + 2)
    local msgLower = toLower(msg)
    local foundPrefix = nil
    for _, prefix in ipairs(exceptionPrefixesIntl) do
        if startsWith(msgLower, toLower(prefix)) then
            foundPrefix = prefix
            break
        end
    end
    local saveMsg
    if foundPrefix then
        saveMsg = "Unhandled exception: " .. string.sub(msg, #foundPrefix + 1)
    else
        saveMsg = msg
    end
    return truncateReason(saveMsg, PDL_CRASH_REASON_CHAR_LIMIT)
end

local function guessDropReasonCategory(reason)
    if type(reason) ~= "string" then
        return { category = "unknown", cleanReason = "[tx:invalid-reason]" }
    end
    local reasonToMatch = toLower((reason:gsub("^%s*(.-)%s*$", "%1")))
    if #reasonToMatch == 0 then
        return { category = "unknown", cleanReason = "[tx:empty-reason]" }
    end
    for _, rule in ipairs(playerInitiatedRules) do
        if startsWith(reasonToMatch, rule) then
            return { category = "player" }
        end
    end
    for _, rule in ipairs(serverInitiatedRules) do
        if startsWith(reasonToMatch, rule) then
            return { category = false }
        end
    end
    for _, rule in ipairs(timeoutRules) do
        if string.find(reasonToMatch, rule, 1, true) then
            return { category = "timeout" }
        end
    end
    for _, rule in ipairs(securityRules) do
        if string.find(reasonToMatch, rule, 1, true) then
            return { category = "security" }
        end
    end
    for _, rule in ipairs(crashRulesIntl) do
        if string.find(reasonToMatch, rule, 1, true) then
            return { category = "crash", cleanReason = cleanCrashReason(reason) }
        end
    end
    return { category = "unknown", cleanReason = truncateReason(reason, PDL_UNKNOWN_REASON_CHAR_LIMIT) }
end

local FxsDropReasonGroups = {
    RESOURCE = 1,
    CLIENT = 2,
    SERVER = 3,
    CLIENT_REPLACED = 4,
    CLIENT_CONNECTION_TIMED_OUT = 5,
    CLIENT_CONNECTION_TIMED_OUT_WITH_PENDING_COMMANDS = 6,
    SERVER_SHUTDOWN = 7,
    STATE_BAG_RATE_LIMIT = 8,
    NET_EVENT_RATE_LIMIT = 9,
    LATENT_NET_EVENT_RATE_LIMIT = 10,
    COMMAND_RATE_LIMIT = 11,
    ONE_SYNC_TOO_MANY_MISSED_FRAMES = 12,
}

local timeoutCategory = {
    [FxsDropReasonGroups.CLIENT_CONNECTION_TIMED_OUT] = true,
    [FxsDropReasonGroups.CLIENT_CONNECTION_TIMED_OUT_WITH_PENDING_COMMANDS] = true,
    [FxsDropReasonGroups.ONE_SYNC_TOO_MANY_MISSED_FRAMES] = true,
}
local securityCategory = {
    [FxsDropReasonGroups.SERVER] = true,
    [FxsDropReasonGroups.CLIENT_REPLACED] = true,
    [FxsDropReasonGroups.STATE_BAG_RATE_LIMIT] = true,
    [FxsDropReasonGroups.NET_EVENT_RATE_LIMIT] = true,
    [FxsDropReasonGroups.LATENT_NET_EVENT_RATE_LIMIT] = true,
    [FxsDropReasonGroups.COMMAND_RATE_LIMIT] = true,
}

function ClassifyDrop(payload)
    if type(payload.reason) ~= "string" then
        return { category = "unknown", cleanReason = "[tx:invalid-reason]" }
    elseif payload.category == nil or payload.resource == nil then
        return guessDropReasonCategory(payload.reason)
    end

    if type(payload.category) ~= "number" or payload.category <= 0 then
        return {
            category = "unknown",
            cleanReason = truncateReason(
                payload.reason,
                PDL_UNKNOWN_REASON_CHAR_LIMIT,
                "[tx:invalid-category]"
            ),
        }
    elseif payload.category == FxsDropReasonGroups.RESOURCE then
        if payload.resource == "monitor" then
            if payload.reason == "server_shutting_down" then
                return { category = false }
            else
                return { category = "resource", resource = "txAdmin" }
            end
        else
            return {
                category = "resource",
                resource = payload.resource ~= "" and payload.resource or "unknown",
            }
        end
    elseif payload.category == FxsDropReasonGroups.CLIENT then
        local reasonToMatch = toLower((payload.reason:gsub("^%s*(.-)%s*$", "%1")))
        for _, rule in ipairs(crashRulesIntl) do
            if string.find(reasonToMatch, rule, 1, true) then
                return {
                    category = "crash",
                    cleanReason = cleanCrashReason(payload.reason),
                }
            end
        end
        return { category = "player" }
    elseif timeoutCategory[payload.category] then
        return { category = "timeout" }
    elseif securityCategory[payload.category] then
        return { category = "security" }
    elseif payload.category == FxsDropReasonGroups.SERVER_SHUTDOWN then
        return { category = false }
    else
        return {
            category = "unknown",
            cleanReason = truncateReason(
                payload.reason,
                PDL_UNKNOWN_REASON_CHAR_LIMIT,
                "[tx:unknown-category]"
            ),
        }
    end
end
