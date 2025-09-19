-- FoxGuildCal Sync System
local addonName, addon = ...

local PREFIX = "FOXGCAL"
local CHANNEL = "GUILD"
local MAX_MSG_SIZE = 240

-- 동기화 상태
local syncState = {
    started = false,
    finished = false,
    tries = 0,
    maxTries = 5,
    retrySchedule = {5, 15, 30, 60, 120}, -- 재시도 간격 (초)
    lastSync = 0,
    receivedResponse = false,
    manualSyncTimer = nil,
    syncRequestCount = 0,  -- 동기화 요청에 응답한 횟수
    maxSyncResponses = 2,  -- 최대 응답 횟수
}

-- 네트워크 상태 추적
local networkMetrics = {
    latency = {},  -- {playerName = averageLatency}
    lastMeasured = {},  -- {playerName = timestamp}
    successfulSyncs = 0,
    failedSyncs = 0,
    totalSyncTime = 0,
    syncCount = 0,
}

-- 프로토콜 버전
local PROTOCOL_VERSION = "1.2.0"
local MIN_COMPATIBLE_VERSION = "1.0.0"

-- 동기화 히스토리 (디버깅용)
local syncHistory = {}  -- 최근 20개 동기화 기록
local MAX_HISTORY_SIZE = 20

-- 최근 접속자 관리
local recentLogins = {}  -- {playerName = loginTime}
local MAX_RECENT_LOGINS = 50  -- 최대 보관 접속자 수
local LOGIN_REPLY_TIME_PHASE1 = 1200  -- 20분 (1단계 회신 시간)
local LOGIN_REPLY_TIME_PHASE2 = 7200  -- 2시간 (2단계 회신 시간)
local SYNC_REQUEST_DELAY = 30  -- 30초 후 동기화 요청
local MAX_SYNC_TARGETS = 5  -- 최대 5명에게 동기화 요청
local ADAPTIVE_SYNC_THRESHOLD = 100  -- 네트워크 상태에 따른 조절 임계값 (ms)

-- 헬퍼 함수들
-- 프로토콜 버전 호환성 체크
local function isVersionCompatible(version)
    if not version then return false end

    local major, minor = version:match("(%d+)%.(%d+)")
    local minMajor, minMinor = MIN_COMPATIBLE_VERSION:match("(%d+)%.(%d+)")

    if not major or not minMajor then return false end

    major, minor = tonumber(major), tonumber(minor)
    minMajor, minMinor = tonumber(minMajor), tonumber(minMinor)

    if major < minMajor then return false end
    if major == minMajor and minor < minMinor then return false end

    return true
end

-- 네트워크 지연 계산
local function getAverageNetworkLatency()
    local totalLatency = 0
    local count = 0
    local currentTime = GetTime()

    for player, latency in pairs(networkMetrics.latency) do
        local lastMeasured = networkMetrics.lastMeasured[player]
        if lastMeasured and (currentTime - lastMeasured) < 300 then  -- 5분 이내 데이터만
            totalLatency = totalLatency + latency
            count = count + 1
        end
    end

    if count > 0 then
        return totalLatency / count
    end

    return 0  -- 데이터 없으면 기본값
end

-- 네트워크 지연 측정
local function measureNetworkLatency(player)
    local startTime = GetTime()

    -- PING 메시지 전송 및 응답 측정 (실제로는 메시지 전송 시간 기록)
    -- 이것은 예시이며, 실제 PING/PONG은 메시지 핸들러에서 처리
    return startTime
end

-- 동기화 히스토리 추가
local function addSyncHistory(event, targetCount)
    local entry = {
        timestamp = time(),
        event = event,
        targets = targetCount,
        success = targetCount > 0
    }

    table.insert(syncHistory, 1, entry)

    -- 최대 크기 유지
    while #syncHistory > MAX_HISTORY_SIZE do
        table.remove(syncHistory)
    end
end

-- 동기화 매트릭스 가져오기
function addon:GetSyncMetrics()
    local avgSyncTime = 0
    if networkMetrics.syncCount > 0 then
        avgSyncTime = networkMetrics.totalSyncTime / networkMetrics.syncCount
    end

    return {
        successRate = networkMetrics.successfulSyncs / math.max(1, networkMetrics.successfulSyncs + networkMetrics.failedSyncs),
        averageSyncTime = avgSyncTime,
        totalSyncs = networkMetrics.successfulSyncs + networkMetrics.failedSyncs,
        averageLatency = getAverageNetworkLatency(),
        recentHistory = syncHistory
    }
end

-- 메시지 인코딩/디코딩
local function escape(str)
    str = tostring(str or "")
    str = str:gsub("%%", "%%%%"):gsub("|", "||"):gsub("\n", "\\n")
    return str
end

local function unescape(str)
    str = tostring(str or "")
    str = str:gsub("||", "|"):gsub("\\n", "\n")
    return str
end

-- 메시지 직렬화
local function serializeEvent(msgType, event)
    -- 메시지 형식: TYPE|version|id|date|hour|minute|title|author|description|updatedAt
    local parts = {
        msgType,
        PROTOCOL_VERSION,  -- 프로토콜 버전 추가
        escape(event.id),
        escape(event.date),
        tostring(event.hour or 0),
        tostring(event.minute or 0),
        escape(event.title),
        escape(event.author),
        escape(event.description or ""),
        tostring(event.updatedAt or time())
    }
    
    if msgType == "DELETE" then
        parts[#parts + 1] = tostring(event.deletedAt or time())
        parts[#parts + 1] = escape(event.deletedBy or "")
    end
    
    return table.concat(parts, "|")
end

-- 메시지 역직렬화
local function deserializeMessage(msg)
    local parts = {}
    for part in string.gmatch(msg .. "|", "([^|]*)|") do
        table.insert(parts, part)
    end
    
    local msgType = parts[1]
    
    if msgType == "SYNCREQ" then
        return {
            type = "SYNCREQ",
            requester = unescape(parts[2] or ""),
            lastEventTime = tonumber(parts[3]) or 0
        }
    elseif msgType == "INCREMENTAL" then
        -- 증분 동기화 메시지
        return {
            type = "INCREMENTAL",
            events = unescape(parts[2] or "")
        }
    elseif msgType == "LOGIN" then
        return { type = "LOGIN", player = unescape(parts[2] or ""), loginTime = tonumber(parts[3]) or time() }
    elseif msgType == "LOGINREPLY" then
        -- LOGIN에 대한 응답
        return { type = "LOGINREPLY", player = unescape(parts[2] or ""), loginTime = tonumber(parts[3]) or time() }
    elseif msgType == "LOGINREQ" then
        -- 2단계 LOGIN 요청
        return { type = "LOGINREQ" }
    elseif msgType == "SYNCSTART" then
        return { type = "SYNCSTART", count = tonumber(parts[2]) or 0 }
    elseif msgType == "SYNCEND" then
        return { type = "SYNCEND" }
    elseif msgType == "ADD" or msgType == "UPDATE" then
        -- 버전 호환성 체크
        local version = parts[2]
        if not isVersionCompatible(version) then
            return nil  -- 호환되지 않는 버전
        end
        return {
            type = msgType,
            id = unescape(parts[3] or ""),  -- 버전 다음부터 시작
            date = unescape(parts[4] or ""),
            hour = tonumber(parts[5]) or 0,
            minute = tonumber(parts[6]) or 0,
            title = unescape(parts[7] or ""),
            author = unescape(parts[8] or ""),
            description = unescape(parts[9] or ""),
            updatedAt = tonumber(parts[10]) or time()
        }
    elseif msgType == "DELETE" then
        -- DELETE도 버전 체크
        local version = parts[2]
        if not isVersionCompatible(version) then
            return nil
        end
        return {
            type = msgType,
            id = unescape(parts[3] or ""),
            date = unescape(parts[4] or ""),
            deletedAt = tonumber(parts[11]) or time(),
            deletedBy = unescape(parts[12] or "")
        }
    end
    
    return nil
end

-- 애드온 메시지 전송
local function sendAddonMessage(msg, target)
    if not C_ChatInfo.IsAddonMessagePrefixRegistered(PREFIX) then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    end
    
    if #msg > MAX_MSG_SIZE then
        msg = string.sub(msg, 1, MAX_MSG_SIZE)
    end
    
    if target then
        C_ChatInfo.SendAddonMessage(PREFIX, msg, "WHISPER", target)
    else
        C_ChatInfo.SendAddonMessage(PREFIX, msg, CHANNEL)
    end
end

-- 마지막 이벤트 시간 가져오기
local function getLastEventTime()
    local lastTime = 0

    -- 개인 일정 확인
    for _, event in pairs(addon.db.personalEvents or {}) do
        if event.updatedAt and event.updatedAt > lastTime then
            lastTime = event.updatedAt
        end
    end

    -- 길드 일정 확인
    local guildKey = addon:GetGuildKey()
    if guildKey then
        for _, event in pairs(addon.db.events[guildKey] or {}) do
            if event.updatedAt and event.updatedAt > lastTime then
                lastTime = event.updatedAt
            end
        end
    end

    return lastTime
end

-- 동기화 요청 (lastEventTime 포함)
local function sendSyncRequest(target, lastEventTime)
    local player = addon:GetPlayerFullName()
    local msg = string.format("SYNCREQ|%s|%d", escape(player), lastEventTime or 0)
    if target then
        sendAddonMessage(msg, target)
    else
        sendAddonMessage(msg)
    end
end

-- 접속 알림 브로드캐스트
local function broadcastLogin()
    local player = addon:GetPlayerFullName()
    local loginTime = time()
    -- 자기 자신을 먼저 추가 (회신 시 중복 방지)
    recentLogins[player] = loginTime
    -- 모든 길드원에게 브로드캐스트
    sendAddonMessage("LOGIN|" .. escape(player) .. "|" .. loginTime)
end

-- 동기화 요청 브로드캐스트 (수동 동기화용)
local function broadcastSyncRequest()
    local player = addon:GetPlayerFullName()
    local currentTime = time()
    -- 모든 길드원에게 동기화 요청 브로드캐스트
    sendAddonMessage(string.format("SYNCREQ|%s|%d", escape(player), currentTime))
end

-- 오래된 접속 기록 정리 (2시간 기준)
local function cleanupOldLogins()
    local currentTime = time()
    local cleaned = {}
    local count = 0

    -- 2시간 이내 기록만 유지
    for player, loginTime in pairs(recentLogins) do
        if currentTime - loginTime < LOGIN_REPLY_TIME_PHASE2 then
            cleaned[player] = loginTime
            count = count + 1
            if count >= MAX_RECENT_LOGINS then
                break
            end
        end
    end

    recentLogins = cleaned
end

-- 가장 최근 접속자 찾기 (시간 필터 옵션)
local function getRecentLoginPlayers(count, maxAge)
    cleanupOldLogins()
    local currentTime = time()
    maxAge = maxAge or LOGIN_REPLY_TIME_PHASE2  -- 기본값 2시간

    -- 접속 시간으로 정렬
    local sorted = {}
    for player, loginTime in pairs(recentLogins) do
        -- 자기 자신 제외 & 시간 필터
        if player ~= addon:GetPlayerFullName() and (currentTime - loginTime) < maxAge then
            table.insert(sorted, {player = player, time = loginTime})
        end
    end

    -- 가장 최근 순으로 정렬
    table.sort(sorted, function(a, b) return a.time > b.time end)

    -- 요청한 수만큼 반환
    local result = {}
    for i = 1, math.min(count, #sorted) do
        table.insert(result, sorted[i].player)
    end

    return result
end

-- 전체 데이터 스냅샷 전송
local function sendSnapshot(target)
    local guildKey = addon:GetGuildKey()
    if not guildKey then return end
    
    local events = addon.db.events[guildKey]
    if not events then return end
    
    -- 이벤트 수 계산
    local count = 0
    for _ in pairs(events) do
        count = count + 1
    end
    
    -- 동기화 시작 알림
    sendAddonMessage("SYNCSTART|" .. count, target)
    
    -- 각 이벤트 전송 (공유 일정만)
    for _, event in pairs(events) do
        -- 개인 일정은 동기화하지 않음
        if event.isShared ~= false then
            local msgType = event.deleted and "DELETE" or "ADD"
            local msg = serializeEvent(msgType, event)
            sendAddonMessage(msg, target)
        end
    end
    
    -- 동기화 종료 알림
    sendAddonMessage("SYNCEND", target)
end

-- 이벤트 병합 (데이터 검증 추가)
local function mergeEvent(event)
    -- 데이터 유효성 검사
    if not event or not event.id or not event.date then
        return false
    end

    -- 날짜 검증
    local year, month, day = event.date:match("(%d+)-(%d+)-(%d+)")
    if not year or not month or not day then
        return false
    end

    year = tonumber(year)
    month = tonumber(month)
    day = tonumber(day)

    -- 비정상적인 날짜 거부
    local currentYear = tonumber(date("%Y"))
    if year < currentYear - 1 or year > currentYear + 5 then
        addon:Print(string.format("잘못된 날짜의 이벤트 거부: %s", event.date))
        return false
    end

    local guildKey = addon:GetGuildKey()
    if not guildKey then return false end

    addon.db.events[guildKey] = addon.db.events[guildKey] or {}
    local events = addon.db.events[guildKey]

    local existing = events[event.id]

    -- 삭제 이벤트의 경우 deletedAt으로 시간 비교
    if event.deleted then
        if not existing or (event.deletedAt and event.deletedAt > (existing.deletedAt or existing.updatedAt or 0)) then
            event.year = year
            event.month = month
            event.day = day
            events[event.id] = event
            return true
        end
    else
        -- 새 이벤트이거나 더 최신 버전인 경우만 업데이트
        if not existing or (event.updatedAt and event.updatedAt > (existing.updatedAt or 0)) then
            event.year = year
            event.month = month
            event.day = day
            events[event.id] = event
            return true
        end
    end

    return false
end

-- 이벤트 브로드캐스트
function addon:BroadcastEvent(action, event)
    if not addon:GetGuildKey() then return end

    -- 개인 일정은 브로드캐스트하지 않음
    if event.isShared == false then
        return
    end

    local msg = serializeEvent(action, event)
    sendAddonMessage(msg)
end

-- 증분 동기화를 위한 이벤트 필터링
local function getEventsSince(lastEventTime)
    local events = {}
    local guildKey = addon:GetGuildKey()
    local currentDate = addon:GetCurrentDate()
    local currentDateStr = addon:FormatDate(currentDate.year, currentDate.month, currentDate.day)

    -- 개인 일정은 동기화하지 않음 (삭제됨)
    -- 개인 일정은 각자의 로컬에만 저장되어야 함

    -- 길드 일정만 동기화 (오늘 이후 일정만)
    if guildKey then
        for id, event in pairs(addon.db.events[guildKey] or {}) do
            if not event.deleted and event.date and event.date >= currentDateStr then
                -- 데이터 검증
                if event.year and event.year >= currentDate.year and event.year <= currentDate.year + 5 then
                    -- isShared가 명시적으로 false가 아닌 경우만 (기본값은 공유)
                    if event.isShared ~= false then
                        events[id] = event
                    end
                end
            end
        end
    end

    return events
end

-- 증분 데이터 전송
local function sendIncrementalData(target, lastEventTime)
    local events = getEventsSince(lastEventTime)
    local count = 0
    for _ in pairs(events) do count = count + 1 end

    if count > 0 then
        -- 동기화 시작 알림
        sendAddonMessage(string.format("SYNCSTART|%d", count), target)

        -- 각 이벤트 전송 (시간 순으로 정렬)
        local sortedEvents = {}
        for id, event in pairs(events) do
            table.insert(sortedEvents, event)
        end
        table.sort(sortedEvents, function(a, b)
            return (a.updatedAt or 0) < (b.updatedAt or 0)
        end)

        -- 순차적으로 전송 (메시지 순서 보장)
        for _, event in ipairs(sortedEvents) do
            local msgType = event.deleted and "DELETE" or "ADD"
            local msg = serializeEvent(msgType, event)
            sendAddonMessage(msg, target)
        end

        -- 동기화 종료 알림
        sendAddonMessage("SYNCEND", target)
    else
        -- 전송할 데이터 없음
        sendAddonMessage("SYNCSTART|0", target)
        sendAddonMessage("SYNCEND", target)
    end
end

-- 초기 동기화 시작
function addon:StartSync(isManual)
    -- 수동 동기화인 경우 별도 처리
    if isManual then
        -- 기존 타이머 취소
        if syncState.manualSyncTimer then
            syncState.manualSyncTimer:Cancel()
        end

        -- 응답 상태 초기화
        syncState.receivedResponse = false
        syncState.syncRequestCount = 0

        -- 길드가 있는지 확인
        if not IsInGuild() then
            addon:Print("길드에 가입되어 있지 않습니다.")
            return
        end

        -- 동기화 요청 전송
        broadcastSyncRequest()
        addon:Print("동기화 요청을 전송했습니다...")

        -- 수동 동기화도 증분 동기화 방식 사용
        C_Timer.After(3, function()
            local recentPlayers = getRecentLoginPlayers(MAX_SYNC_TARGETS, LOGIN_REPLY_TIME_PHASE2)
            if #recentPlayers > 0 then
                addon:PerformIncrementalSync(recentPlayers)
            else
                addon:Print("동기화할 다른 플레이어가 없습니다.")
            end
        end)
        return
    end

    -- 자동 동기화 로직 - 개선된 방식
    if syncState.started then return end

    -- 길드가 있는지 확인
    if not IsInGuild() then
        return
    end

    -- 1단계: 접속 알림 브로드캐스트
    broadcastLogin()
    addon:Print("접속 알림을 전송했습니다.")

    -- 5초 후 20분 이내 접속자 확인
    C_Timer.After(5, function()
        local recentPlayers = getRecentLoginPlayers(MAX_SYNC_TARGETS, LOGIN_REPLY_TIME_PHASE1)

        if #recentPlayers == 0 then
            -- 2단계: 20분 이내 없으면 2시간 이내 접속자에게 요청
            addon:Print("20분 이내 접속자가 없습니다. 2시간 이내 접속자에게 요청 중...")

            -- LOGINREQ 브로드캐스트
            sendAddonMessage("LOGINREQ")

            -- 5초 후 2시간 이내 접속자 확인
            C_Timer.After(5, function()
                recentPlayers = getRecentLoginPlayers(MAX_SYNC_TARGETS, LOGIN_REPLY_TIME_PHASE2)

                if #recentPlayers == 0 then
                    addon:Print("동기화할 다른 플레이어가 없습니다. 새 캘린더로 시작합니다.")
                    syncState.started = true
                    syncState.finished = true
                else
                    -- 30초 후 동기화 요청 예약
                    C_Timer.After(SYNC_REQUEST_DELAY - 10, function()
                        addon:PerformIncrementalSync(recentPlayers)
                    end)
                end
            end)
        else
            -- 30초 후 동기화 요청 예약
            addon:Print(string.format("%d명의 최근 접속자를 발견했습니다. 30초 후 동기화...", #recentPlayers))
            C_Timer.After(SYNC_REQUEST_DELAY, function()
                addon:PerformIncrementalSync(recentPlayers)
            end)
        end
    end)
end

-- 증분 동기화 수행
function addon:PerformIncrementalSync(targets)
    if not targets or #targets == 0 then return end

    -- 현재 로그인 시간을 기준으로 (한달 전 데이터 방지)
    local currentTime = time()
    local syncStartTime = GetTime()  -- 동기화 시작 시간

    -- 네트워크 상태에 따른 타겟 조절
    local adjustedTargets = targets
    local avgLatency = getAverageNetworkLatency()
    if avgLatency > ADAPTIVE_SYNC_THRESHOLD then
        -- 네트워크 상태가 나쁘면 타겟 수 줄이기
        local reducedCount = math.max(2, math.floor(#targets * 0.6))
        adjustedTargets = {}
        for i = 1, reducedCount do
            adjustedTargets[i] = targets[i]
        end
        addon:Print(string.format("네트워크 지연으로 동기화 대상을 %d명으로 조정", reducedCount))
    end

    addon:Print(string.format("최근 %d명에게 오늘 이후 일정 요청 중...", #adjustedTargets))

    -- 동기화 히스토리 기록
    addSyncHistory("증분 동기화 시작", #adjustedTargets)

    -- 각 타겟에게 증분 동기화 요청
    syncState.receivedResponse = false
    syncState.syncRequestCount = 0  -- 응답 카운트 리셋

    for _, player in ipairs(adjustedTargets) do
        sendSyncRequest(player, currentTime)
    end

    -- Exponential Backoff를 사용한 재시도
    local retryCount = 0
    local baseDelay = 3  -- 기본 지연 시간
    local maxRetries = 3

    local function checkResponse()
        if not syncState.receivedResponse and retryCount < maxRetries then
            retryCount = retryCount + 1
            local delay = baseDelay * math.pow(2, retryCount - 1)  -- 3, 6, 12초
            addon:Print(string.format("응답 없음. %d초 후 재시도 중... (%d/%d)", delay, retryCount, maxRetries))

            -- 재전송 (더 넓은 범위로)
            local extendedTargets = getRecentLoginPlayers(MAX_SYNC_TARGETS * 2, LOGIN_REPLY_TIME_PHASE2)
            for i = 1, math.min(#extendedTargets, MAX_SYNC_TARGETS) do
                sendSyncRequest(extendedTargets[i], currentTime)
            end

            C_Timer.After(delay, checkResponse)
        elseif not syncState.receivedResponse then
            addon:Print("동기화 응답이 없습니다.")
            networkMetrics.failedSyncs = networkMetrics.failedSyncs + 1
            addSyncHistory("동기화 실패 - 응답 없음", 0)
            syncState.started = true
            syncState.finished = true
        else
            local syncTime = GetTime() - syncStartTime
            networkMetrics.successfulSyncs = networkMetrics.successfulSyncs + 1
            networkMetrics.totalSyncTime = networkMetrics.totalSyncTime + syncTime
            networkMetrics.syncCount = networkMetrics.syncCount + 1
            addSyncHistory(string.format("동기화 성공 - %.1f초", syncTime), syncState.syncRequestCount)
            syncState.started = true
            syncState.finished = true
        end
    end

    C_Timer.After(baseDelay, checkResponse)
end

-- 동기화 완료 표시
local function markSyncComplete(isFromSync)
    syncState.receivedResponse = true

    -- 수동 동기화 타이머 취소
    if syncState.manualSyncTimer then
        syncState.manualSyncTimer:Cancel()
        syncState.manualSyncTimer = nil
    end

    if isFromSync then
        addon:Print("길드 캘린더 동기화가 완료되었습니다.")
    end

    if not syncState.finished then
        syncState.finished = true
        syncState.lastSync = time()
    end
end

-- 메시지 수신 처리
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")

frame:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
    if event ~= "CHAT_MSG_ADDON" then return end
    if prefix ~= PREFIX then return end
    if sender == addon:GetPlayerFullName() then return end -- 자신의 메시지 무시
    
    local msg = deserializeMessage(message)
    if not msg then return end
    
    if msg.type == "SYNCREQ" then
        -- 누군가 증분 동기화를 요청함
        -- 최대 응답 횟수 제한 (200명 방지)
        if not syncState.lastSyncRequests then
            syncState.lastSyncRequests = {}
        end

        local currentTime = time()
        -- 10초 이내 동일 요청자에게 재응답 방지
        if syncState.lastSyncRequests[sender] and
           currentTime - syncState.lastSyncRequests[sender] < 10 then
            return
        end

        syncState.lastSyncRequests[sender] = currentTime

        if msg.lastEventTime then
            -- 요청자가 가진 마지막 이벤트 시간 이후의 데이터만 전송
            sendIncrementalData(sender, msg.lastEventTime)
        else
            -- 전체 데이터 전송 (폴백)
            sendSnapshot(sender)
        end

    elseif msg.type == "LOGIN" then
        -- 누군가 접속함
        if msg.player and msg.loginTime then
            if msg.player ~= addon:GetPlayerFullName() then
                recentLogins[msg.player] = msg.loginTime
                cleanupOldLogins()

                -- 1단계: 20분 이내 접속자만 회신
                local myLoginTime = recentLogins[addon:GetPlayerFullName()] or time()
                local currentTime = time()

                if currentTime - myLoginTime < LOGIN_REPLY_TIME_PHASE1 then
                    sendAddonMessage("LOGINREPLY|" .. escape(addon:GetPlayerFullName()) .. "|" .. myLoginTime, sender)
                end
            end
        end

    elseif msg.type == "LOGINREQ" then
        -- 2단계 LOGIN 요청 (2시간 이내 접속자)
        local myLoginTime = recentLogins[addon:GetPlayerFullName()] or time()
        local currentTime = time()

        if currentTime - myLoginTime < LOGIN_REPLY_TIME_PHASE2 then
            sendAddonMessage("LOGINREPLY|" .. escape(addon:GetPlayerFullName()) .. "|" .. myLoginTime, sender)
        end

    elseif msg.type == "LOGINREPLY" then
        -- LOGIN 응답 받음
        if msg.player and msg.loginTime then
            recentLogins[msg.player] = msg.loginTime
            cleanupOldLogins()
        end

    elseif msg.type == "SYNCSTART" then
        -- 동기화 시작 알림
        if syncState.manualSyncTimer then
            addon:Print(string.format("%s님으로부터 동기화 시작 (%d개 이벤트)", sender, msg.count or 0))
        end
        -- 자동 동기화 시에는 메시지 표시 안함
        if not syncState.started then
            addon:Print(string.format("%s님으로부터 동기화 중...", sender))
        end
        markSyncComplete(false)

    elseif msg.type == "SYNCEND" then
        -- 동기화 종료
        markSyncComplete(true)
        if addon.calendarFrame and addon.calendarFrame:IsShown() then
            addon:UpdateCalendar()
        end

    elseif msg.type == "ADD" or msg.type == "UPDATE" then
        -- 이벤트 추가/업데이트
        local changed = mergeEvent(msg)
        if changed then
            markSyncComplete(false)
            if addon.calendarFrame and addon.calendarFrame:IsShown() then
                addon:UpdateCalendar()
            end
        end

    elseif msg.type == "DELETE" then
        -- 이벤트 삭제
        msg.deleted = true
        msg.deletedAt = msg.deletedAt or time()
        msg.deletedBy = msg.deletedBy or sender
        local changed = mergeEvent(msg)
        if changed then
            markSyncComplete(false)
            if addon.calendarFrame and addon.calendarFrame:IsShown() then
                addon:UpdateCalendar()
                -- 현재 선택된 날짜의 이벤트도 업데이트
                if selectedDay then
                    addon:ShowDayEvents(currentYear, currentMonth, selectedDay)
                end
            end
        end
    end
end)

-- 등록
C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

-- 주기적 자동 동기화는 제거 (증분 동기화로 대체)
-- 새 이벤트가 발생할 때마다 실시간 브로드캐스트로 처리