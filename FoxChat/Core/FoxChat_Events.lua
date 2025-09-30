local addonName, addon = ...

-- 이벤트 시스템 초기화
FoxChat = FoxChat or {}
FoxChat.Events = FoxChat.Events or {}

local Events = FoxChat.Events
local handlers = {}

-- 이벤트 시스템 초기화
function Events:Initialize()
    handlers = {}
    FoxChat:Debug("이벤트 시스템 초기화 완료")
end

-- 이벤트 핸들러 등록
function Events:Register(eventName, handler, priority)
    if not eventName or type(handler) ~= "function" then
        error("Invalid event registration: " .. tostring(eventName))
        return false
    end

    handlers[eventName] = handlers[eventName] or {}
    priority = priority or 50  -- 기본 우선순위는 50

    table.insert(handlers[eventName], {
        handler = handler,
        priority = priority
    })

    -- 우선순위 순으로 정렬 (높은 값이 먼저 실행)
    table.sort(handlers[eventName], function(a, b)
        return a.priority > b.priority
    end)

    FoxChat:Debug("이벤트 등록:", eventName, "우선순위:", priority)
    return true
end

-- 이벤트 핸들러 제거
function Events:Unregister(eventName, handler)
    if not handlers[eventName] then
        return false
    end

    for i = #handlers[eventName], 1, -1 do
        if handlers[eventName][i].handler == handler then
            table.remove(handlers[eventName], i)
            FoxChat:Debug("이벤트 제거:", eventName)
            return true
        end
    end

    return false
end

-- 특정 이벤트의 모든 핸들러 제거
function Events:UnregisterAll(eventName)
    if handlers[eventName] then
        handlers[eventName] = nil
        FoxChat:Debug("모든 이벤트 제거:", eventName)
        return true
    end
    return false
end

-- 이벤트 트리거
function Events:Trigger(eventName, ...)
    if not handlers[eventName] then
        return 0
    end

    local count = 0
    local args = {...}

    for _, handlerData in ipairs(handlers[eventName]) do
        local success, result = pcall(handlerData.handler, ...)

        if success then
            count = count + 1
            -- 핸들러가 true를 반환하면 이벤트 전파 중단
            if result == true then
                break
            end
        else
            FoxChat:Print("이벤트 처리 중 오류:", eventName)
            FoxChat:Debug("오류 내용:", result)
        end
    end

    if FoxChat.debugMode and count > 0 then
        FoxChat:Debug("이벤트 발생:", eventName, "처리된 핸들러 수:", count)
    end

    return count
end

-- 비동기 이벤트 트리거 (다음 프레임에 실행)
function Events:TriggerAsync(eventName, ...)
    local args = {...}
    C_Timer.After(0, function()
        Events:Trigger(eventName, unpack(args))
    end)
end

-- 지연 이벤트 트리거
function Events:TriggerDelayed(delay, eventName, ...)
    local args = {...}
    C_Timer.After(delay, function()
        Events:Trigger(eventName, unpack(args))
    end)
end

-- 등록된 이벤트 목록 확인
function Events:GetRegisteredEvents()
    local eventList = {}
    for eventName, handlerList in pairs(handlers) do
        table.insert(eventList, {
            name = eventName,
            count = #handlerList
        })
    end
    return eventList
end

-- 특정 이벤트의 핸들러 수 확인
function Events:GetHandlerCount(eventName)
    if handlers[eventName] then
        return #handlers[eventName]
    end
    return 0
end

-- 디버그: 모든 이벤트와 핸들러 출력
function Events:DumpEvents()
    print("|cffFFA500FoxChat Events|r 등록된 이벤트:")
    for eventName, handlerList in pairs(handlers) do
        print("  " .. eventName .. ": " .. #handlerList .. " 핸들러")
        for i, handlerData in ipairs(handlerList) do
            print("    [" .. i .. "] 우선순위: " .. handlerData.priority)
        end
    end
end

-- 커스텀 이벤트 목록 (문서화용)
FoxChat.Events.CustomEvents = {
    -- 시스템 이벤트
    "FOXCHAT_INITIALIZED",           -- 애드온 초기화 완료
    "FOXCHAT_SHUTDOWN",              -- 애드온 종료
    "FOXCHAT_CONFIG_LOADED",         -- 설정 로드 완료
    "FOXCHAT_CONFIG_SAVED",          -- 설정 저장 완료
    "FOXCHAT_SLASH_COMMAND",         -- 슬래시 명령어 입력

    -- 기능 이벤트
    "FOXCHAT_KEYWORD_MATCHED",       -- 키워드 매치
    "FOXCHAT_MESSAGE_FILTERED",      -- 메시지 필터링
    "FOXCHAT_PREFIX_SUFFIX_APPLIED", -- 말머리/말꼬리 적용
    "FOXCHAT_TRADE_COMPLETED",       -- 거래 완료
    "FOXCHAT_PARTY_MEMBER_JOINED",   -- 파티원 참가
    "FOXCHAT_ROLL_STARTED",          -- 주사위 시작
    "FOXCHAT_ROLL_COMPLETED",        -- 주사위 완료

    -- UI 이벤트
    "FOXCHAT_CONFIG_SHOW",           -- 설정창 표시
    "FOXCHAT_CONFIG_HIDE",           -- 설정창 숨김
    "FOXCHAT_TAB_CHANGED",           -- 탭 변경
    "FOXCHAT_TOAST_SHOW",            -- 토스트 표시
    "FOXCHAT_MINIMAP_CLICKED",       -- 미니맵 버튼 클릭
}