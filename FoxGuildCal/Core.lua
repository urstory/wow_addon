-- FoxGuildCal Core
local addonName, addon = ...
addon.name = addonName
addon.version = GetAddOnMetadata(addonName, "Version")

-- 기본 설정
addon.defaults = {
    minimap = {
        hide = false,
        minimapPos = 220,
        lock = false,
    },
    calendar = {
        x = 0,
        y = 0,
        width = 600,
        height = 500,
        scale = 1,
    },
    sync = {
        enabled = true,
        autoSync = true,
        syncInterval = 300, -- 5분
    },
}

-- 유틸리티 함수들
function addon:Print(msg)
    print("|cff00ff00[FoxGuildCal]|r " .. msg)
end

function addon:GetCurrentDate()
    local date = C_DateAndTime.GetCurrentCalendarTime()
    return {
        year = date.year,
        month = date.month,
        day = date.monthDay,
        hour = date.hour,
        minute = date.minute
    }
end

function addon:FormatDate(year, month, day)
    return string.format("%04d-%02d-%02d", year, month, day)
end

function addon:FormatDateTime(year, month, day, hour, minute)
    return string.format("%04d-%02d-%02d %02d:%02d", year, month, day, hour or 0, minute or 0)
end

function addon:GetMonthName(month)
    local months = {
        "1월", "2월", "3월", "4월", "5월", "6월",
        "7월", "8월", "9월", "10월", "11월", "12월"
    }
    return months[month] or tostring(month)
end

function addon:GetDaysInMonth(year, month)
    local days = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
    if month == 2 and ((year % 4 == 0 and year % 100 ~= 0) or year % 400 == 0) then
        return 29 -- 윤년
    end
    return days[month]
end

function addon:GetFirstDayOfWeek(year, month)
    -- WoW의 time 함수를 사용하여 정확한 요일 계산
    local timestamp = time({year = year, month = month, day = 1})
    local dateInfo = date("*t", timestamp)
    -- wday: 1=일요일, 2=월요일, ..., 7=토요일
    -- 캘린더도 일요일부터 시작하므로 그대로 사용
    return dateInfo.wday
end

function addon:GenerateEventId()
    local player = UnitName("player")
    local realm = GetRealmName()
    local timestamp = time()
    local random = math.random(1000, 9999)
    return string.format("%s-%s-%d-%d", player, realm, timestamp, random)
end

function addon:GetPlayerFullName()
    return UnitName("player") .. "-" .. GetRealmName()
end

function addon:GetGuildKey()
    local guildName = GetGuildInfo("player")
    if not guildName then return nil end
    return guildName .. "-" .. GetRealmName()
end

-- 이벤트 핸들러
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_GUILD_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- 전투 종료
frame:RegisterEvent("PLAYER_REGEN_DISABLED") -- 전투 시작

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            -- DB 초기화
            FoxGuildCalDB = FoxGuildCalDB or {}
            FoxGuildCalDB.settings = FoxGuildCalDB.settings or {}
            FoxGuildCalDB.events = FoxGuildCalDB.events or {}
            FoxGuildCalDB.personalEvents = FoxGuildCalDB.personalEvents or {}  -- 계정 공유 개인 일정
            
            -- 설정 병합 (중첩 테이블 처리)
            local function mergeDefaults(target, defaults)
                for k, v in pairs(defaults) do
                    if type(v) == "table" then
                        target[k] = target[k] or {}
                        mergeDefaults(target[k], v)
                    elseif target[k] == nil then
                        target[k] = v
                    end
                end
            end
            mergeDefaults(FoxGuildCalDB.settings, addon.defaults)
            
            addon.db = FoxGuildCalDB
            addon:Print("애드온이 로드되었습니다. 미니맵 버튼을 클릭하여 달력을 여세요.")
        end
    elseif event == "PLAYER_LOGIN" then
        -- 동기화 시작
        if addon.StartSync then
            addon:StartSync()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- 날짜 초기화 함수 호출
        if addon.InitializeDateVariables then
            addon:InitializeDateVariables()
        end
        -- 미니맵 버튼 초기화
        if addon.InitializeMinimapButton then
            C_Timer.After(0.5, function()
                addon.InitializeMinimapButton()
            end)
        end
    elseif event == "PLAYER_GUILD_UPDATE" then
        -- 길드 변경 시 처리
        local guildKey = addon:GetGuildKey()
        if guildKey then
            addon.db.events[guildKey] = addon.db.events[guildKey] or {}
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- 전투 시작
        addon.inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- 전투 종료
        addon.inCombat = false
    end
end)

-- 날짜 변수 초기화 함수
function addon:InitializeDateVariables()
    local today = C_DateAndTime.GetCurrentCalendarTime()
    if today and today.year and today.month and today.monthDay then
        -- Calendar.lua에 전역 변수를 설정하는 함수 호출
        if addon.SetDateVariables then
            addon:SetDateVariables(today.year, today.month, today.monthDay)
        end
    end
end

-- 버그로 인해 잘못된 데이터 정리 함수
function addon:CleanupBuggedEvents()
    local cleanedCount = 0
    local playerName = UnitName("player")
    local guildKey = addon:GetGuildKey()

    if guildKey then
        local events = addon.db.events[guildKey] or {}
        local personalEvents = addon.db.personalEvents or {}

        -- 길드 일정 중 실제로는 개인 일정인 것들을 찾아서 이동
        for id, event in pairs(events) do
            if not event.deleted then
                -- isShared가 false인 일정을 개인 일정으로 이동
                if event.isShared == false then
                    personalEvents[id] = event
                    events[id] = nil
                    cleanedCount = cleanedCount + 1
                    addon:Print("잘못된 개인 일정을 정리했습니다: " .. (event.title or "제목 없음"))
                end
            end
        end

        -- 중복된 일정 제거 (같은 ID가 개인과 길드 모두에 있는 경우)
        for id, event in pairs(personalEvents) do
            if events[id] and not events[id].deleted then
                -- 개인 일정을 우선시하고 길드 일정 삭제
                events[id] = nil
                cleanedCount = cleanedCount + 1
            end
        end
    end

    if cleanedCount > 0 then
        addon:Print(string.format("총 %d개의 잘못된 일정을 정리했습니다.", cleanedCount))
    else
        addon:Print("정리할 잘못된 일정이 없습니다.")
    end
end

-- 슬래시 명령어 추가
SLASH_FOXGUILDCAL1 = "/fgc"
SLASH_FOXGUILDCAL2 = "/foxguildcal"
SlashCmdList["FOXGUILDCAL"] = function(msg)
    if msg == "cleanup" then
        addon:CleanupBuggedEvents()
    elseif msg == "help" then
        addon:Print("명령어 목록:")
        addon:Print("/fgc - 캘린더 열기/닫기")
        addon:Print("/fgc cleanup - 버그로 인한 잘못된 일정 정리")
        addon:Print("/fgc help - 도움말")
    else
        addon:ToggleCalendar()
    end
end

addon.frame = frame