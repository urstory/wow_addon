local addonName, addon = ...

-- 공통 유틸리티 모듈
FoxChat = FoxChat or {}
FoxChat.Utils = FoxChat.Utils or {}
FoxChat.Utils.Common = {}

local Common = FoxChat.Utils.Common

-- 문자열이 비어있거나 공백만 있는지 확인
function Common:IsEmptyOrWhitespace(str)
    return not str or string.gsub(str, "%s+", "") == ""
end

-- 문자열 트림 (앞뒤 공백 제거)
function Common:Trim(str)
    if not str then return "" end
    return (str:gsub("^%s*(.-)%s*$", "%1"))
end

-- 테이블 깊은 복사
function Common:DeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[self:DeepCopy(orig_key)] = self:DeepCopy(orig_value)
        end
        setmetatable(copy, self:DeepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- 테이블 병합 (source를 target으로)
function Common:MergeTable(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then
        return target
    end

    for key, value in pairs(source) do
        if type(value) == "table" and type(target[key]) == "table" then
            self:MergeTable(target[key], value)
        else
            target[key] = value
        end
    end

    return target
end

-- 색상 코드 생성 (RGB to Hex)
function Common:RGBToHex(r, g, b, a)
    a = a or 1
    return string.format("|c%02x%02x%02x%02x",
        math.floor(a * 255),
        math.floor(r * 255),
        math.floor(g * 255),
        math.floor(b * 255))
end

-- Hex to RGB 변환
function Common:HexToRGB(hex)
    if not hex then return 1, 1, 1, 1 end

    -- |cAARRGGBB 형식 처리
    if string.sub(hex, 1, 2) == "|c" then
        hex = string.sub(hex, 3)
    end

    local a = tonumber(string.sub(hex, 1, 2), 16) / 255
    local r = tonumber(string.sub(hex, 3, 4), 16) / 255
    local g = tonumber(string.sub(hex, 5, 6), 16) / 255
    local b = tonumber(string.sub(hex, 7, 8), 16) / 255

    return r or 1, g or 1, b or 1, a or 1
end

-- 금액 포맷팅 (구리 -> 골드/실버/구리)
function Common:FormatMoney(copper)
    if not copper or copper == 0 then
        return "0"
    end

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperLeft = copper % 100

    local result = ""

    if gold > 0 then
        result = gold .. "g"
    end

    if silver > 0 then
        if result ~= "" then result = result .. " " end
        result = result .. silver .. "s"
    end

    if copperLeft > 0 then
        if result ~= "" then result = result .. " " end
        result = result .. copperLeft .. "c"
    end

    return result
end

-- 시간 포맷팅 (초 -> 시:분:초)
function Common:FormatTime(seconds)
    if not seconds or seconds < 0 then
        return "00:00"
    end

    if seconds < 60 then
        return string.format("00:%02d", seconds)
    elseif seconds < 3600 then
        local mins = math.floor(seconds / 60)
        local secs = seconds % 60
        return string.format("%02d:%02d", mins, secs)
    else
        local hours = math.floor(seconds / 3600)
        local mins = math.floor((seconds % 3600) / 60)
        local secs = seconds % 60
        return string.format("%d:%02d:%02d", hours, mins, secs)
    end
end

-- 날짜 포맷팅
function Common:FormatDate(timestamp)
    if not timestamp then
        timestamp = time()
    end
    return date("%Y-%m-%d %H:%M:%S", timestamp)
end

-- 간략한 시간 표시 (방금, 5분 전, 1시간 전 등)
function Common:FormatTimeAgo(timestamp)
    if not timestamp then return "알 수 없음" end

    local now = time()
    local diff = now - timestamp

    if diff < 60 then
        return "방금"
    elseif diff < 3600 then
        local mins = math.floor(diff / 60)
        return mins .. "분 전"
    elseif diff < 86400 then
        local hours = math.floor(diff / 3600)
        return hours .. "시간 전"
    else
        local days = math.floor(diff / 86400)
        if days == 1 then
            return "어제"
        else
            return days .. "일 전"
        end
    end
end

-- 플레이어 이름 정규화 (서버명 제거)
function Common:NormalizeName(name)
    if not name then return nil end

    -- "이름-서버" 형식에서 서버 부분 제거
    local plainName = name:match("^([^-]+)")
    if plainName then
        return plainName
    end

    return name
end

-- 완전한 플레이어 이름 가져오기 (서버명 포함)
function Common:GetFullName(name, realm)
    if not name then return nil end

    -- 이미 서버명이 포함된 경우
    if string.find(name, "-") then
        return name
    end

    -- 서버명이 없으면 현재 서버명 추가
    realm = realm or GetRealmName()
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end

    return name
end

-- 문자열 분할
function Common:Split(str, delimiter)
    if not str then return {} end

    delimiter = delimiter or ","
    local result = {}
    local from = 1
    local delim_from, delim_to = string.find(str, delimiter, from)

    while delim_from do
        table.insert(result, string.sub(str, from, delim_from - 1))
        from = delim_to + 1
        delim_from, delim_to = string.find(str, delimiter, from)
    end

    table.insert(result, string.sub(str, from))
    return result
end

-- 테이블을 문자열로 (디버깅용)
function Common:TableToString(tbl, indent)
    if type(tbl) ~= "table" then
        return tostring(tbl)
    end

    indent = indent or 0
    local spaces = string.rep("  ", indent)
    local result = "{\n"

    for key, value in pairs(tbl) do
        result = result .. spaces .. "  "
        if type(key) == "string" then
            result = result .. '["' .. key .. '"]'
        else
            result = result .. "[" .. tostring(key) .. "]"
        end
        result = result .. " = "

        if type(value) == "table" then
            result = result .. self:TableToString(value, indent + 1)
        elseif type(value) == "string" then
            result = result .. '"' .. value .. '"'
        else
            result = result .. tostring(value)
        end
        result = result .. ",\n"
    end

    result = result .. spaces .. "}"
    return result
end

-- 안전한 함수 호출
function Common:SafeCall(func, ...)
    if type(func) ~= "function" then
        return false, "Not a function"
    end

    local success, result = pcall(func, ...)
    if not success then
        FoxChat:Debug("SafeCall 오류:", result)
    end

    return success, result
end

-- 딜레이 실행
function Common:Delay(seconds, func, ...)
    if type(func) ~= "function" then return end

    local args = {...}
    C_Timer.After(seconds, function()
        func(unpack(args))
    end)
end

-- 반복 실행
function Common:Repeat(interval, func, ...)
    if type(func) ~= "function" then return end

    local args = {...}
    local timer

    local function tick()
        local continue = func(unpack(args))
        if continue ~= false then
            timer = C_Timer.After(interval, tick)
        end
    end

    timer = C_Timer.After(interval, tick)
    return timer
end

-- 쿨다운 체크
local cooldowns = {}

function Common:IsOnCooldown(key)
    if not cooldowns[key] then
        return false
    end

    return GetTime() < cooldowns[key]
end

function Common:SetCooldown(key, duration)
    cooldowns[key] = GetTime() + duration
end

function Common:GetCooldownRemaining(key)
    if not cooldowns[key] then
        return 0
    end

    local remaining = cooldowns[key] - GetTime()
    return remaining > 0 and remaining or 0
end

function Common:ClearCooldown(key)
    cooldowns[key] = nil
end

-- 채팅 채널 타입 판별
function Common:GetChannelType(channelName)
    if not channelName then return "UNKNOWN" end

    local name = channelName:upper()

    -- 길드/공격대/파티
    if name == "GUILD" then
        return "GUILD"
    elseif name == "RAID" or name == "RAID_WARNING" or name == "RAID_LEADER" then
        return "RAID"
    elseif name == "PARTY" or name == "PARTY_LEADER" then
        return "PARTY"
    elseif name == "INSTANCE_CHAT" then
        return "INSTANCE"
    -- 공개 채널
    elseif name == "SAY" or name == "YELL" then
        return "PUBLIC"
    -- 파티찾기
    elseif string.find(name, "파티찾기") or string.find(name, "LOOKINGFORGROUP") then
        return "LFG"
    -- 일반 채널
    elseif string.find(name, "일반") or string.find(name, "GENERAL") then
        return "GENERAL"
    -- 거래 채널
    elseif string.find(name, "거래") or string.find(name, "TRADE") then
        return "TRADE"
    -- 속삭
    elseif name == "WHISPER" or name == "BN_WHISPER" then
        return "WHISPER"
    else
        return "CHANNEL"
    end
end