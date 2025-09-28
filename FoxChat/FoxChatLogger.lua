-- FoxChatLogger.lua
-- 채팅 로그 핵심 모듈 (Classic 1.15 성능 최적화 버전)

local addonName, addon = ...
addon.ChatLogger = addon.ChatLogger or {}
local CL = addon.ChatLogger

-- === 설정 기본값 ===
CL.cfg = {
    enabled = false,
    channels = {
        WHISPER = true,   -- 기본 ON
        PARTY = true,     -- 기본 ON
        RAID = false,     -- 기본 OFF (로그 폭증 방지)
        GUILD = false     -- 기본 OFF (로그 폭증 방지)
    },
    retentionDays = 7,    -- 1~30일
    sessionTimeout = 1800, -- 30분 (UI 표시용)
}

-- === 내부 상태 ===
-- SavedVariables 초기화
FoxChatDB = FoxChatDB or {}
FoxChatDB.chatLogs = FoxChatDB.chatLogs or {}
FoxChatDB.chatLogConfig = FoxChatDB.chatLogConfig or {}

-- 채널 코드 테이블 (저장 크기 최소화)
local CH = {
    WHISPER_IN    = 2,  -- 받은 귓말
    WHISPER_OUT   = 1,  -- 보낸 귓말
    PARTY         = 3,  -- 파티
    PARTY_LEADER  = 6,  -- 파티장
    RAID          = 4,  -- 공격대
    RAID_LEADER   = 7,  -- 공격대장
    GUILD         = 5,  -- 길드
}

-- 이벤트와 채널 코드 매핑
local EVENT2CODE = {
    CHAT_MSG_WHISPER        = CH.WHISPER_IN,
    CHAT_MSG_WHISPER_INFORM = CH.WHISPER_OUT,
    CHAT_MSG_PARTY          = CH.PARTY,
    CHAT_MSG_PARTY_LEADER   = CH.PARTY_LEADER,
    CHAT_MSG_RAID           = CH.RAID,
    CHAT_MSG_RAID_LEADER    = CH.RAID_LEADER,
    CHAT_MSG_GUILD          = CH.GUILD,
}

-- 날짜 키 캐싱 (핫패스 최적화)
local curDayKey, curDayStart

local function InitDayCache()
    local now = GetServerTime()
    curDayKey = date("%Y%m%d", now)
    local y = tonumber(curDayKey:sub(1,4))
    local m = tonumber(curDayKey:sub(5,6))
    local d = tonumber(curDayKey:sub(7,8))
    curDayStart = time{year=y, month=m, day=d, hour=0, min=0, sec=0}
end

-- 초기화
InitDayCache()

-- 채널 허용 확인 (빠른 분기)
local function ChannelAllowed(code)
    local config = FoxChatDB.chatLogConfig
    if not config or not config.channels then
        -- 설정이 없으면 기본값 사용
        config = CL.cfg
    end

    if code == CH.WHISPER_IN or code == CH.WHISPER_OUT then
        return config.channels.WHISPER
    elseif code == CH.PARTY or code == CH.PARTY_LEADER then
        return config.channels.PARTY
    elseif code == CH.RAID or code == CH.RAID_LEADER then
        return config.channels.RAID
    elseif code == CH.GUILD then
        return config.channels.GUILD
    end
    return false
end

-- 메시지 저장 (핫패스 최적화 - date 호출 제거)
local MAX_LINES_PER_DAY = 10000  -- 일별 최대 라인 수

local function SaveLog(ts, code, sender, target, msg, outgoing)
    -- 설정 확인
    local config = FoxChatDB.chatLogConfig
    if not config.enabled then return end
    if not ChannelAllowed(code) then return end

    -- curDayKey 사용 (date 호출 없음)
    local bucket = FoxChatDB.chatLogs[curDayKey]
    if not bucket then
        bucket = {}
        FoxChatDB.chatLogs[curDayKey] = bucket
    end

    -- 일별 최대 라인 수 제한
    if #bucket >= MAX_LINES_PER_DAY then
        table.remove(bucket, 1)  -- 가장 오래된 항목 제거
    end

    -- 축약 키로 저장
    bucket[#bucket+1] = {
        ts = ts,                    -- timestamp (epoch)
        ch = code,                  -- channel code
        s  = sender,                -- sender
        t  = target,                -- target (whisper)
        m  = msg,                   -- message
        o  = outgoing and 1 or 0,   -- outgoing flag
    }
end

-- 오래된 로그 삭제 (로그인/날짜 변경 시 1회)
function CL:CleanOldLogs()
    local config = FoxChatDB.chatLogConfig
    local keep = tonumber(config.retentionDays) or CL.cfg.retentionDays
    keep = math.max(1, math.min(30, keep))
    local now = GetServerTime()

    for dayKey in pairs(FoxChatDB.chatLogs) do
        -- dayKey "YYYYMMDD" → 해당 0시를 계산
        local y = tonumber(dayKey:sub(1,4))
        local m = tonumber(dayKey:sub(5,6))
        local d = tonumber(dayKey:sub(7,8))

        if y and m and d then
            local t0 = time{year=y, month=m, day=d, hour=0, min=0, sec=0}
            if t0 and (now - t0) > keep * 86400 then
                FoxChatDB.chatLogs[dayKey] = nil
            end
        end
    end
end

-- 자정 롤오버 감지 (캐시 사용)
local function MaybeRolloverCached()
    local now = GetServerTime()
    if not curDayStart or now - curDayStart >= 86400 then
        InitDayCache()  -- 날짜 키 재계산
        C_Timer.After(2, function() CL:CleanOldLogs() end)
    end
end

-- === 이벤트 핸들러 ===
local f = CreateFrame("Frame")
CL.frame = f

-- 귓속말 대상 추적
CL.lastWhisperTarget = nil
hooksecurefunc("SendChatMessage", function(msg, chatType, lang, target)
    if chatType == "WHISPER" and target and target ~= "" then
        -- 서버명 제거 및 정규화
        CL.lastWhisperTarget = Ambiguate(target, "none"):gsub("%-.+$","")
    end
end)

-- 통합 이벤트 핸들러
f:SetScript("OnEvent", function(self, event, msg, sender, language, channelString, targetName, flags, unknown, channelNumber, channelName, unknown2, counter, guid)
    -- 채팅 메시지가 아닌 이벤트 처리
    local code = EVENT2CODE[event]
    if not code then
        if event == "PLAYER_LOGIN" then
            -- 로그인 시 설정 초기화 및 청소
            C_Timer.After(2, function()
                CL:InitConfig()
                CL:CleanOldLogs()
                print("|cFF00FF00[FoxChat]|r 채팅 로그 모듈 준비 완료")
            end)
        elseif event == "ADDON_LOADED" and ... == addonName then
            -- 애드온 로드 시 설정 초기화
            CL:InitConfig()
        end
        return
    end

    -- 채팅 메시지 처리
    local ts = GetServerTime()
    local target, outgoing = nil, false

    -- 발신자 정규화
    if sender then
        sender = Ambiguate(sender, "none"):gsub("%-.+$", "")
    end

    -- 귓속말 처리
    if code == CH.WHISPER_OUT then
        outgoing = true
        target = CL.lastWhisperTarget  -- 훅에서 추적한 대상 사용
        sender = UnitName("player")  -- 발신자는 나
    elseif code == CH.WHISPER_IN then
        target = UnitName("player")  -- 수신자는 나
    end

    -- 로그 저장
    SaveLog(ts, code, sender, target, msg, outgoing)

    -- 자정 체크 (캐시 사용)
    MaybeRolloverCached()
end)

-- 이벤트 등록
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("CHAT_MSG_WHISPER")
f:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
f:RegisterEvent("CHAT_MSG_PARTY")
f:RegisterEvent("CHAT_MSG_PARTY_LEADER")
f:RegisterEvent("CHAT_MSG_RAID")
f:RegisterEvent("CHAT_MSG_RAID_LEADER")
f:RegisterEvent("CHAT_MSG_GUILD")

-- 5분마다 자정 체크 (채팅 없는 시간대 대비)
local ticker = C_Timer.NewTicker(300, MaybeRolloverCached)

-- === 설정 관리 ===
function CL:InitConfig()
    -- DB에 설정이 없으면 기본값으로 초기화
    if not FoxChatDB.chatLogConfig then
        FoxChatDB.chatLogConfig = {}
    end

    local config = FoxChatDB.chatLogConfig

    -- 각 설정 항목 초기화
    if config.enabled == nil then
        config.enabled = CL.cfg.enabled
    end

    if not config.channels then
        config.channels = {}
    end

    -- 채널 설정 초기화
    for ch, default in pairs(CL.cfg.channels) do
        if config.channels[ch] == nil then
            config.channels[ch] = default
        end
    end

    if not config.retentionDays then
        config.retentionDays = CL.cfg.retentionDays
    end

    if not config.sessionTimeout then
        config.sessionTimeout = CL.cfg.sessionTimeout
    end
end

-- === 세션 구분 로직 ===
CL.lastMessageTime = 0

function CL:CheckSessionGap(ts)
    local config = FoxChatDB.chatLogConfig
    local sessionTimeout = config.sessionTimeout or CL.cfg.sessionTimeout

    if CL.lastMessageTime > 0 and (ts - CL.lastMessageTime) > sessionTimeout then
        -- 세션 간격 초과 - UI에서 처리할 수 있도록 마커 추가
        return true
    end

    CL.lastMessageTime = ts
    return false
end

-- === API 함수 ===

-- 설정 변경
function CL:SetEnabled(enabled)
    FoxChatDB.chatLogConfig.enabled = not not enabled
    if enabled then
        print("|cFF00FF00[FoxChat]|r 채팅 로그 기록 시작")
    else
        print("|cFFFF0000[FoxChat]|r 채팅 로그 기록 중지")
    end
end

function CL:SetChannel(channel, enabled)
    if FoxChatDB.chatLogConfig.channels then
        FoxChatDB.chatLogConfig.channels[channel] = not not enabled
    end
end

function CL:SetRetentionDays(days)
    days = tonumber(days) or 7
    FoxChatDB.chatLogConfig.retentionDays = math.max(1, math.min(30, days))
end

-- 특정 날짜의 로그 가져오기 (세션 구분 포함)
function CL:GetLogsForDate(dayKey, withSession)
    local logs = FoxChatDB.chatLogs[dayKey] or {}

    if not withSession then
        return logs
    end

    -- 세션 구분을 위한 처리
    local result = {}
    local lastTs = 0
    local config = FoxChatDB.chatLogConfig
    local sessionTimeout = config.sessionTimeout or CL.cfg.sessionTimeout

    for i, log in ipairs(logs) do
        if lastTs > 0 and (log.ts - lastTs) > sessionTimeout then
            -- 세션 마커 추가
            table.insert(result, {
                ts = log.ts,
                session = true,
                time = date("%H:%M", log.ts)
            })
        end
        table.insert(result, log)
        lastTs = log.ts
    end

    return result
end

-- 저장된 날짜 목록 가져오기 (로그 수 포함)
function CL:GetAvailableDates()
    local dates = {}
    for dayKey, logs in pairs(FoxChatDB.chatLogs) do
        table.insert(dates, {
            key = dayKey,
            count = #logs,
            formatted = string.format("%s-%s-%s",
                dayKey:sub(1,4), dayKey:sub(5,6), dayKey:sub(7,8))
        })
    end
    table.sort(dates, function(a, b) return a.key > b.key end)  -- 최신 날짜 먼저
    return dates
end

-- 특정 날짜 로그 삭제
function CL:DeleteLogsForDate(dayKey)
    FoxChatDB.chatLogs[dayKey] = nil
end

-- 모든 로그 삭제
function CL:DeleteAllLogs()
    wipe(FoxChatDB.chatLogs)
end

-- 디버그 정보
function CL:GetDebugInfo()
    local totalLines = 0
    local totalDays = 0

    for dayKey, logs in pairs(FoxChatDB.chatLogs) do
        totalDays = totalDays + 1
        totalLines = totalLines + #logs
    end

    return {
        enabled = FoxChatDB.chatLogConfig.enabled,
        totalDays = totalDays,
        totalLines = totalLines,
        currentDayKey = curDayKey,
        retentionDays = FoxChatDB.chatLogConfig.retentionDays,
    }
end

-- UI용 헬퍼 메서드
function CL:GetMessagesForDate(dayKey)
    if not FoxChatDB.chatLogs[dayKey] then
        return {}
    end

    -- 메시지를 복사하여 반환 (원본 데이터 보호)
    local messages = {}
    for i, msg in ipairs(FoxChatDB.chatLogs[dayKey]) do
        messages[i] = {
            ts = msg.ts,
            ch = msg.ch,
            s = msg.s,
            t = msg.t,
            m = msg.m,
            o = msg.o
        }
    end

    return messages
end

function CL:GetAvailableDates()
    local dates = {}
    for dayKey in pairs(FoxChatDB.chatLogs) do
        table.insert(dates, dayKey)
    end
    table.sort(dates, function(a, b) return a > b end)  -- 최신 날짜 먼저
    return dates
end

function CL:GetChannelName(code)
    local channelNames = {
        W = "귓말",
        P = "파티",
        R = "공대",
        G = "길드",
        Y = "외침",
        S = "일반"
    }
    return channelNames[code] or code
end

-- === 슬래시 명령어 ===
SLASH_FOXCHATLOG1 = "/fclog"
SlashCmdList["FOXCHATLOG"] = function(msg)
    local cmd, arg = strsplit(" ", msg, 2)
    cmd = (cmd or ""):lower()

    if cmd == "" or cmd == "help" then
        print("|cFF00FF00[FoxChat 로그]|r 명령어 목록:")
        print("  /fclog enable - 로그 기록 시작")
        print("  /fclog disable - 로그 기록 중지")
        print("  /fclog status - 현재 상태 확인")
        print("  /fclog test - 테스트 메시지 생성")
        print("  /fclog clean - 오래된 로그 정리")
        print("  /fclog dates - 저장된 날짜 목록")
        print("  /fclog clear [날짜] - 특정 날짜 또는 전체 로그 삭제")
        print("  /fclog export [날짜] - 로그 내보내기 (복사용)")

    elseif cmd == "enable" then
        CL:SetEnabled(true)

    elseif cmd == "disable" then
        CL:SetEnabled(false)

    elseif cmd == "status" then
        local info = CL:GetDebugInfo()
        print("|cFF00FF00[FoxChat 로그]|r 상태 정보:")
        print(string.format("  활성화: %s", info.enabled and "|cFF00FF00예|r" or "|cFFFF0000아니오|r"))
        print(string.format("  보관 기간: %d일", info.retentionDays))
        print(string.format("  저장된 날짜: %d개", info.totalDays))
        print(string.format("  전체 로그: %d줄", info.totalLines))
        print(string.format("  오늘 날짜: %s", info.currentDayKey))

        local config = FoxChatDB.chatLogConfig
        print("  채널 설정:")
        print(string.format("    귓속말: %s", config.channels.WHISPER and "ON" or "OFF"))
        print(string.format("    파티: %s", config.channels.PARTY and "ON" or "OFF"))
        print(string.format("    공격대: %s", config.channels.RAID and "ON" or "OFF"))
        print(string.format("    길드: %s", config.channels.GUILD and "ON" or "OFF"))

    elseif cmd == "test" then
        -- 테스트 메시지 생성
        print("|cFF00FF00[FoxChat 로그]|r 테스트 메시지 생성 중...")
        local ts = GetServerTime()

        -- 귓속말 테스트
        SaveLog(ts, CH.WHISPER_OUT, UnitName("player"), "테스트유저", "안녕하세요! 이것은 테스트 귓속말입니다.", true)
        SaveLog(ts+1, CH.WHISPER_IN, "테스트유저", UnitName("player"), "네, 안녕하세요!", false)

        -- 파티 테스트
        SaveLog(ts+2, CH.PARTY, "파티원1", nil, "던전 가실 분 있나요?", false)
        SaveLog(ts+3, CH.PARTY, UnitName("player"), nil, "저 갈게요!", false)

        -- 30분 후 세션 (세션 구분 테스트)
        SaveLog(ts+1805, CH.PARTY, "파티원2", nil, "퀘스트 같이 하실 분?", false)

        print("|cFF00FF00[FoxChat 로그]|r 테스트 메시지 5개 생성 완료")

    elseif cmd == "clean" then
        CL:CleanOldLogs()
        print("|cFF00FF00[FoxChat 로그]|r 오래된 로그 정리 완료")

    elseif cmd == "dates" then
        local dates = CL:GetAvailableDates()
        if #dates == 0 then
            print("|cFF00FF00[FoxChat 로그]|r 저장된 로그가 없습니다.")
        else
            print("|cFF00FF00[FoxChat 로그]|r 저장된 날짜 목록:")
            for i, dateInfo in ipairs(dates) do
                print(string.format("  %s: %d줄", dateInfo.formatted, dateInfo.count))
            end
        end

    elseif cmd == "clear" then
        if arg then
            -- 특정 날짜 삭제
            local dayKey = arg:gsub("-", "")
            if FoxChatDB.chatLogs[dayKey] then
                CL:DeleteLogsForDate(dayKey)
                print(string.format("|cFF00FF00[FoxChat 로그]|r %s 로그 삭제 완료", arg))
            else
                print(string.format("|cFFFF0000[FoxChat 로그]|r %s에 해당하는 로그가 없습니다.", arg))
            end
        else
            -- 전체 삭제 확인
            CL:DeleteAllLogs()
            print("|cFF00FF00[FoxChat 로그]|r 모든 로그 삭제 완료")
        end

    elseif cmd == "export" then
        local dayKey = arg and arg:gsub("-", "") or curDayKey
        local logs = CL:GetLogsForDate(dayKey, true)

        if #logs == 0 then
            print("|cFFFF0000[FoxChat 로그]|r 해당 날짜의 로그가 없습니다.")
            return
        end

        -- 로그를 텍스트로 변환
        local lines = {}
        table.insert(lines, string.format("=== FoxChat 로그: %s ===", dayKey))

        for _, log in ipairs(logs) do
            if log.session then
                table.insert(lines, string.format("\n===== 새 대화 세션: %s =====", log.time))
            else
                local chLabel = CL:GetChannelLabel(log.ch)
                local who = CL:FormatSender(log.ch, log.s, log.t, log.o)
                table.insert(lines, string.format("[%s][%s] %s: %s",
                    date("%H:%M:%S", log.ts), chLabel, who, log.m or ""))
            end
        end

        -- 결과를 EditBox에 표시 (복사 가능)
        CL:ShowExportDialog(table.concat(lines, "\n"))

    else
        print("|cFFFF0000[FoxChat 로그]|r 알 수 없는 명령어: " .. cmd)
    end
end

-- === 유틸리티 함수 ===
function CL:GetChannelLabel(code)
    if code == CH.WHISPER_IN or code == CH.WHISPER_OUT then
        return "귓"
    elseif code == CH.PARTY or code == CH.PARTY_LEADER then
        return "파티"
    elseif code == CH.RAID or code == CH.RAID_LEADER then
        return "공대"
    elseif code == CH.GUILD then
        return "길드"
    else
        return "기타"
    end
end

function CL:FormatSender(code, sender, target, outgoing)
    if code == CH.WHISPER_OUT then
        return string.format("나 → %s", target or "?")
    elseif code == CH.WHISPER_IN then
        return string.format("%s → 나", sender or "?")
    else
        return sender or "?"
    end
end

-- 내보내기 다이얼로그 (간단한 복사용 EditBox)
function CL:ShowExportDialog(text)
    -- 기존 프레임이 있으면 재사용
    if not CL.exportFrame then
        local f = CreateFrame("Frame", "FoxChatLogExport", UIParent, "DialogBoxFrame")
        f:SetSize(600, 400)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")

        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        f.title:SetPoint("TOP", 0, -10)
        f.title:SetText("채팅 로그 내보내기")

        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 10, -30)
        scroll:SetPoint("BOTTOMRIGHT", -30, 40)

        local editBox = CreateFrame("EditBox", nil, scroll)
        editBox:SetMultiLine(true)
        editBox:SetFontObject(ChatFontNormal)
        editBox:SetWidth(550)
        editBox:SetAutoFocus(true)
        editBox:SetScript("OnEscapePressed", function() f:Hide() end)

        scroll:SetScrollChild(editBox)
        f.editBox = editBox
        CL.exportFrame = f
    end

    CL.exportFrame.editBox:SetText(text)
    CL.exportFrame.editBox:HighlightText()
    CL.exportFrame:Show()

    print("|cFF00FF00[FoxChat 로그]|r Ctrl+C로 복사하세요.")
end

-- 초기화 메시지
C_Timer.After(1, function()
    CL:InitConfig()
    if FoxChatDB.chatLogConfig.enabled then
        print("|cFF00FF00[FoxChat]|r 채팅 로그 모듈 활성화 (/fclog help)")
    else
        print("|cFFFFFF00[FoxChat]|r 채팅 로그 비활성화 상태 (/fclog enable로 시작)")
    end
end)