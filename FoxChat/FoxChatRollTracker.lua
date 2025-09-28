-- FoxChatRollTracker.lua
-- 파티/공대 주사위 자동 집계 모듈

local addonName, addon = ...
local L = addon.L

-- 모듈 초기화
addon.RollTracker = addon.RollTracker or {}
local RT = addon.RollTracker

-- 디버그 모드 초기화
addon.DebugMode = addon.DebugMode or false

-- 설정 기본값
RT.defaults = {
    enabled = false,           -- 주사위 집계 사용 여부
    windowSec = 10,            -- 집계 시간 (10/15/20/30/45/60) 기본값 10초
    topK = 1,                  -- 출력 등수 (1=우승자만, 2~40=상위 N명)
}

-- 상태 변수
RT.sessionActive = false
RT.sessionStart = 0
RT.timerHandle = nil
RT.rollMessages = {}       -- 주사위 메시지를 그대로 저장
RT.roster = {}             -- 그룹원 집합

-- 유틸리티: 메시지 정리 (토큰/공백 제거)
local function CleanMessage(msg)
    -- 조사 토큰 제거: |숫자...; 형태 전부 제거
    msg = msg:gsub("|%d+[^;]*;", "")
    -- 색코드 제거
    msg = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    -- 이중 공백을 단일 공백으로
    msg = msg:gsub("%s+", " ")
    -- 앞뒤 공백 제거
    msg = msg:match("^%s*(.-)%s*$") or msg
    return msg
end

-- 유틸리티: 이름 정규화
local function NormalizeName(name)
    if not name or name == "" then return nil end

    -- 디버그: 원본 이름
    local originalName = name

    -- Ambiguate 함수 사용 (WoW API - 서버명 제거)
    if Ambiguate then
        local before = name
        name = Ambiguate(name, "none")
        if addon.DebugMode and before ~= name then
            print("  Ambiguate:", before, "=>", name or "nil")
        end
    end

    -- 서버명 제거 (백업)
    name = name:gsub("%-.+$", "")

    -- 색상 코드 제거
    name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")

    -- 조사 토큰 제거 (수정된 패턴 - 세미콜론이 두 개 있는 경우만)
    name = name:gsub("|%d+[^;]*;[^;]*;", "")

    -- "님" 접미사 제거 (한국어)
    name = name:gsub("님$", "")

    -- 앞뒤 공백만 제거 (중간 공백은 유지)
    name = name:match("^%s*(.-)%s*$") or name

    -- 디버그 로그
    if addon.DebugMode then
        if name == "" or not name then
            print("[NormalizeName] 이름이 빈 문자열로 변환됨.")
            print("  원본:", originalName)
            print("  최종:", name)
        else
            print("[NormalizeName] 정규화 완료:", originalName, "=>", name)
        end
    end

    if not name or name == "" then return nil end
    return name
end

-- 그룹 채널로 메시지 전송
local function SendGroup(msg)
    -- rollOutputChannel 설정 확인 (기본값: SELF)
    local outputChannel = (FoxChatDB and FoxChatDB.rollOutputChannel) or "SELF"

    if addon.DebugMode then
        print("[SendGroup] OutputChannel:", outputChannel, "IsInRaid:", IsInRaid(), "IsInGroup:", IsInGroup())
    end

    if outputChannel == "SELF" then
        -- 나에게만 출력 (시스템 메시지로)
        if addon.DebugMode then
            print("[SendGroup] >>> 나에게만 출력:", msg)
        end
        -- 노란색 시스템 메시지로 출력
        print("|cFFFFFF00[주사위 집계]|r " .. msg)
    else
        -- 파티/공대 출력 (GROUP)
        if IsInRaid() then
            if addon.DebugMode then
                print("[SendGroup] >>> RAID 채널로 전송:", msg)
            end
            SendChatMessage(msg, "RAID")
        elseif IsInGroup() then
            if addon.DebugMode then
                print("[SendGroup] >>> PARTY 채널로 전송:", msg)
            end
            SendChatMessage(msg, "PARTY")
        else
            -- 솔로일 때는 로컬 채팅창에만 출력
            if addon.DebugMode then
                print("[SendGroup] >>> 로컬 채팅창으로 출력 (솔로):", msg)
            end
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[FoxChat 주사위]|r " .. msg)
        end
    end
end

-- 255바이트 경계 안전 자르기
local function TrimToChatLimit(s, limit)
    limit = limit or 255
    if #s <= limit then return s end
    local i = limit
    while i > 0 do
        local b = s:byte(i)
        if b < 0x80 or b >= 0xC0 then
            return s:sub(1, i)
        end
        i = i - 1
    end
    return ""
end

-- 긴 메시지를 여러 줄로 분할 전송
local function SendGroupChunked(prefix, list, suffix)
    local base = prefix
    for idx, part in ipairs(list) do
        local candidate = (base == "" and part or (base .. (base ~= "" and ", " or "") .. part))
        if #candidate > 250 then
            SendGroup(TrimToChatLimit(candidate))
            base = ""
        else
            base = candidate
        end
    end
    local final = base
    if suffix and suffix ~= "" then
        final = (final ~= "" and (final .. " " .. suffix) or suffix)
    end
    if final ~= "" then SendGroup(TrimToChatLimit(final)) end
end

-- RANDOM_ROLL_RESULT 패턴 빌드 (한국어/영어 클라이언트 대응)
local function BuildRollPattern()
    local fmt = _G.RANDOM_ROLL_RESULT or "%s rolls %d (%d-%d)"

    -- 디버그 로그: 현재 클라이언트의 RANDOM_ROLL_RESULT 확인
    if addon.DebugMode then
        print("[FoxChatRollTracker] RANDOM_ROLL_RESULT format:", fmt)
    end

    -- 루아 패턴 예약문자 이스케이프
    fmt = fmt:gsub("([%%%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
    -- 토큰 대체
    fmt = fmt:gsub("%%s", "(.+)")
    fmt = fmt:gsub("%%d", "(%%d+)")
    return "^" .. fmt .. "$"
end

-- 한국어 클라이언트용 추가 패턴들
local function GetKoreanRollPatterns()
    return {
        -- 가장 정확한 패턴들 (토큰 제거 후) - 이름 뒤 공백 처리
        "^(.-)%s+주사위 굴리기를 하여 (%d+) 나왔습니다%. %((%d+)%-(%d+)%)$",
        "^(.-)%s+주사위 굴리기를 하여 (%d+)이 나왔습니다%. %((%d+)%-(%d+)%)$",
        "^(.-)%s+주사위 굴리기를 하여 (%d+)가 나왔습니다%. %((%d+)%-(%d+)%)$",
        -- 공백/마침표 변형 허용
        "^(.-)%s*주사위%s*굴리기를%s*하여%s*(%d+)%s*나왔습니다%.?%s*%((%d+)%-(%d+)%)$",
        -- 더 유연한 패턴
        "(.-)%s*주사위.-(%d+).-%((%d+)%-(%d+)%)",
        -- 축약형 (최소/최대 없는 경우)
        "^(.-)%s*주사위.-하여%s*(%d+)",
        -- 기존 패턴들 호환성
        "(.+) 주사위를 굴려 (%d+)%. 나왔습니다%. %((%d+)%-(%d+)%)",
        "(.+) 주사위를 굴려 (%d+)가 나왔습니다%. %((%d+)%-(%d+)%)",
        -- 영어 패턴
        "^(.+) rolls (%d+) %((%d+)%-(%d+)%)$"
    }
end

local ROLL_PATTERN = BuildRollPattern()
local KOREAN_PATTERNS = GetKoreanRollPatterns()

-- 그룹 로스터 재구축
function RT:RebuildRoster()
    wipe(self.roster)
    local count = 0

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name = GetRaidRosterInfo(i)
            name = NormalizeName(name)
            if name then
                self.roster[name] = true
                count = count + 1
            end
        end
    elseif IsInGroup() then
        local myName = NormalizeName(UnitName("player"))
        if myName then
            self.roster[myName] = true
            count = count + 1
        end

        for i = 1, 4 do
            local u = "party" .. i
            if UnitExists(u) then
                local nm = NormalizeName(UnitName(u))
                if nm then
                    self.roster[nm] = true
                    count = count + 1
                end
            end
        end
    else
        local myName = NormalizeName(UnitName("player"))
        if myName then
            self.roster[myName] = true
            count = count + 1
        end
    end

    if addon.DebugMode then
        print("[RT:RebuildRoster] 로스터 재구축 완료. 인원:", count)
        for name, _ in pairs(self.roster) do
            print("  - " .. name)
        end
    end
end

-- 세션 시작
function RT:StartSession()
    if self.sessionActive or not (FoxChatDB and FoxChatDB.rollTrackerEnabled) then
        if addon.DebugMode then
            print("[RT:StartSession] 세션 시작 실패 - sessionActive:", self.sessionActive, "enabled:", FoxChatDB and FoxChatDB.rollTrackerEnabled)
        end
        return
    end
    self.sessionActive = true
    self.sessionStart = GetTime()
    wipe(self.rollMessages)

    -- Fix B: 타이머를 C_Timer.After로 단순화 + 워치독 추가
    local sec = tonumber(FoxChatDB.rollTrackerWindowSec) or 20
    sec = math.max(5, math.min(120, sec))

    -- 주 타이머
    self.deadline = GetTime() + sec
    C_Timer.After(sec, function()
        if RT.sessionActive then
            RT:FinishSession()
        end
    end)

    -- 워치독 1프레임 타이밍 (더 확실한 보장)
    if not RT._watch then
        RT._watch = CreateFrame("Frame")
        RT._watch:SetScript("OnUpdate", function()
            if RT.sessionActive and RT.deadline and GetTime() >= RT.deadline then
                RT:FinishSession()
            end
        end)
    end

    if addon.DebugMode then
        print("[RT:StartSession] 세션 시작! " .. sec .. "초 후 결과 출력 예정")
    end
end

-- 상위 N 산출 (경계 동점 포함)
local function BuildTopN(rec, N)
    local entries = {}
    for name, roll in pairs(rec.lastByPlayer or {}) do
        table.insert(entries, {name = name, roll = roll})
    end
    table.sort(entries, function(a, b)
        if a.roll ~= b.roll then return a.roll > b.roll end
        return a.name < b.name
    end)
    if #entries == 0 then return {}, 0 end

    N = N or 1
    local cutoffIndex = math.min(N, #entries)
    local cutoffRoll = entries[cutoffIndex].roll
    local out = {}
    for _, e in ipairs(entries) do
        if #out < N or e.roll == cutoffRoll then
            table.insert(out, e)
        else
            break
        end
    end
    return out, entries[1].roll
end

-- 세션 종료
function RT:FinishSession()
    if addon.DebugMode then
        print("[RT:FinishSession] 세션 종료 시작")
        print("  세션 지속 시간:", math.floor(GetTime() - self.sessionStart), "초")
        print("  저장된 메시지 수:", #self.rollMessages)
        print("  집계 사용 설정:", FoxChatDB and FoxChatDB.rollTrackerEnabled and "켜짐" or "꺼짐")
    end

    if not self.sessionActive then
        if addon.DebugMode then
            print("  세션이 활성화되어 있지 않음")
        end
        return
    end
    self.sessionActive = false
    self.deadline = nil  -- 워치독 타이머 클리어

    -- 집계 사용이 꺼져있으면 출력하지 않음
    if not (FoxChatDB and FoxChatDB.rollTrackerEnabled) then
        if addon.DebugMode then
            print("  [RT:FinishSession] 집계 사용이 꺼져있어 결과를 출력하지 않음")
        end
        -- 저장된 메시지 초기화
        wipe(self.rollMessages)
        return
    end

    -- 저장된 메시지들에서 최고값 찾기
    if #self.rollMessages > 0 then
        local rollsByRange = {}  -- 범위별로 플레이어 주사위 값 저장

        -- 각 메시지에서 이름과 값, 범위 추출
        for _, msg in ipairs(self.rollMessages) do
            local name, roll, minVal, maxVal

            -- 범위 정보 포함 패턴들 시도
            -- 패턴 1: "우르사 주사위 굴리기를 하여 68 나왔습니다. (1-100)"
            name, roll, minVal, maxVal = msg:match("^(.+)%s+주사위%s+굴리기를%s+하여%s+(%d+).-%((%d+)%-(%d+)%)")

            -- 패턴 2: 더 유연한 한국어 패턴
            if not name then
                name, roll, minVal, maxVal = msg:match("^(.-)%s*주사위.-(%d+).-나왔.-%((%d+)%-(%d+)%)")
            end

            -- 패턴 3: 영어 패턴
            if not name then
                name, roll, minVal, maxVal = msg:match("^(.-)%s+rolls%s+(%d+)%s*%((%d+)%-(%d+)%)")
            end

            -- 범위 정보가 없는 경우 (기본값으로 처리)
            if not name then
                -- 패턴 4: 범위 없는 한국어
                name, roll = msg:match("^(.+)%s+주사위%s+굴리기를%s+하여%s+(%d+)")
                if name then
                    minVal, maxVal = "1", "100"  -- 기본값
                end
            end

            if not name then
                -- 패턴 5: 더 유연한 패턴 (범위 없음)
                name, roll = msg:match("^(.-)%s*주사위.-(%d+).-나왔")
                if name then
                    minVal, maxVal = "1", "100"  -- 기본값
                end
            end

            if not name then
                -- 패턴 6: 영어 (범위 없음)
                name, roll = msg:match("^(.-)%s+rolls%s+(%d+)")
                if name then
                    minVal, maxVal = "1", "100"  -- 기본값
                end
            end

            -- 패턴 7: 최소한 이름과 숫자만 찾기
            if not name then
                name = msg:match("^(%S+)")
                roll = msg:match("(%d+)")
                if name and roll then
                    minVal, maxVal = "1", "100"  -- 기본값
                end
            end

            if addon.DebugMode then
                print("[파싱]", msg)
                print("  -> name:", name or "nil", "roll:", roll or "nil", "range:", (minVal or "?") .. "-" .. (maxVal or "?"))
            end

            if name and roll then
                -- 이름 끝의 공백 제거
                name = name:match("^%s*(.-)%s*$")
                roll = tonumber(roll)
                minVal = tonumber(minVal) or 1
                maxVal = tonumber(maxVal) or 100

                if roll then
                    -- 범위 키 생성 (예: "1-100", "1-60")
                    local rangeKey = minVal .. "-" .. maxVal

                    -- 해당 범위 테이블이 없으면 생성
                    if not rollsByRange[rangeKey] then
                        rollsByRange[rangeKey] = {
                            players = {},
                            min = minVal,
                            max = maxVal,
                            count = 0
                        }
                    end

                    -- 같은 사람이 여러번 굴린 경우 마지막 값으로 덮어씀
                    rollsByRange[rangeKey].players[name] = roll
                    rollsByRange[rangeKey].count = rollsByRange[rangeKey].count + 1

                    if addon.DebugMode then
                        print("  -> 저장:", name, "=", roll, "범위:", rangeKey)
                    end
                end
            end
        end

        if addon.DebugMode then
            print("[범위별 주사위 값]")
            for range, data in pairs(rollsByRange) do
                print("  범위", range, ":")
                for name, roll in pairs(data.players) do
                    print("    ", name, ":", roll)
                end
            end
        end

        -- 각 범위별로 우승자 찾고 출력
        local resultMessages = {}
        local totalRolls = #self.rollMessages

        for rangeKey, rangeData in pairs(rollsByRange) do
            local maxRoll = 0
            local winners = {}
            local rangeRollCount = 0

            -- 해당 범위에서 최고값 찾기
            for name, roll in pairs(rangeData.players) do
                rangeRollCount = rangeRollCount + 1
                if roll > maxRoll then
                    maxRoll = roll
                    winners = {name}
                elseif roll == maxRoll then
                    table.insert(winners, name)
                end
            end

            -- 결과 메시지 생성
            if #winners > 0 then
                local resultText
                if #winners == 1 then
                    if rangeKey == "1-100" then
                        -- 기본 범위는 범위 표시 생략
                        resultText = string.format("총 %d개의 주사위가 굴려졌고 우승은 %s(%d) 입니다.",
                                                   rangeData.count, winners[1], maxRoll)
                    else
                        -- 특수 범위는 범위 표시
                        resultText = string.format("[%s] 총 %d개의 주사위가 굴려졌고 우승은 %s(%d) 입니다.",
                                                   rangeKey, rangeData.count, winners[1], maxRoll)
                    end
                else
                    if rangeKey == "1-100" then
                        resultText = string.format("총 %d개의 주사위가 굴려졌고 공동 우승은 %s(%d) 입니다.",
                                                   rangeData.count, table.concat(winners, ", "), maxRoll)
                    else
                        resultText = string.format("[%s] 총 %d개의 주사위가 굴려졌고 공동 우승은 %s(%d) 입니다.",
                                                   rangeKey, rangeData.count, table.concat(winners, ", "), maxRoll)
                    end
                end
                table.insert(resultMessages, {range = rangeKey, text = resultText, max = rangeData.max})
            end
        end

        -- 범위 크기 순으로 정렬 (큰 범위부터)
        table.sort(resultMessages, function(a, b)
            return a.max > b.max
        end)

        -- 결과 출력
        if #resultMessages > 0 then
            for _, msg in ipairs(resultMessages) do
                SendGroup(msg.text)
            end
        else
            if addon.DebugMode then
                print("[경고] 우승자를 찾을 수 없음. 주사위 파싱 실패일 수 있습니다.")
            end
            SendGroup("집계된 주사위가 없습니다.")
        end
    else
        SendGroup("집계된 주사위가 없습니다.")
    end

    if addon.DebugMode then
        print(string.format("[RT:FinishSession] 세션 종료 완료 @ %.1f", GetTime()))
    end
end

-- 주사위 메시지 저장
function RT:AddRollMessage(msg)
    -- 집계 사용이 꺼져있으면 저장하지 않음
    if not (FoxChatDB and FoxChatDB.rollTrackerEnabled) then
        if addon.DebugMode then
            print("[RT:AddRollMessage] 집계 사용이 꺼져있어 메시지를 저장하지 않음")
        end
        return
    end

    if addon.DebugMode then
        print("[RT:AddRollMessage] 메시지 저장:", msg)
    end

    -- 1) 세션은 무조건 먼저 보장 (타이머 꼭 돌게)
    if not self.sessionActive then
        self:StartSession()
    end

    -- 2) 메시지 저장
    table.insert(self.rollMessages, msg)

    if addon.DebugMode then
        print(string.format("[RT] 메시지 저장 완료. 현재 %d개", #self.rollMessages))
    end
end

-- 이벤트 프레임
RT.frame = RT.frame or CreateFrame("Frame")
RT.frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
        RT:RebuildRoster()
        return
    end
    if event == "CHAT_MSG_SYSTEM" and FoxChatDB and FoxChatDB.rollTrackerEnabled then
        local msg = ...

        -- 주사위 메시지인지 간단히 확인 (한국어/영어)
        if string.find(msg, "주사위") or string.find(msg, "roll") or string.find(msg, "굴리") or string.find(msg, "나왔습니다") then
            if addon.DebugMode then
                print("[RT] 주사위 메시지 감지:", msg)
            end

            -- 조사 토큰 제거하여 깔끔하게 저장
            local cleanMsg = CleanMessage(msg)

            RT:AddRollMessage(cleanMsg)
        end
        return
    end
end)

-- 이벤트 등록
RT.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
RT.frame:RegisterEvent("GROUP_ROSTER_UPDATE")
RT.frame:RegisterEvent("CHAT_MSG_SYSTEM")

-- 초기화 확인
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(1, function()
            print("|cFF00FF00[FoxChat]|r 주사위 집계 모듈 준비")
            print("  - 활성화: " .. ((FoxChatDB and FoxChatDB.rollTrackerEnabled) and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"))
            print("  - 사용법: /roll 또는 /random 1 100")
            print("  - 디버그: /fcroll debug on")
        end)
    elseif event == "ADDON_LOADED" and ... == addonName then
        -- 모듈이 로드될 때 초기화
        RT:RebuildRoster()
    end
end)

-- /주사위 명령어는 WoW 기본 명령어를 사용하도록 함
-- 한국어 클라이언트는 /roll 또는 /random 사용

-- 설정 함수들 (UI에서 호출)
function RT:SetEnabled(enabled)
    if FoxChatDB then
        FoxChatDB.rollTrackerEnabled = not not enabled
    end
end

function RT:SetWindowSec(seconds)
    if FoxChatDB then
        seconds = tonumber(seconds) or 20
        if seconds == 15 or seconds == 20 or seconds == 30 or seconds == 60 then
            FoxChatDB.rollTrackerWindowSec = seconds
        end
    end
end

function RT:SetTopK(n)
    if FoxChatDB then
        n = tonumber(n) or 1
        FoxChatDB.rollTrackerTopK = math.max(1, math.min(40, math.floor(n)))
    end
end

-- 슬래시 명령어 등록 (디버그 명령어만)
SLASH_FOXCHATROLL1 = "/fcroll"
SlashCmdList["FOXCHATROLL"] = function(arg)
    arg = (arg or ""):match("^%s*(.-)%s*$")
    local cmd, rest = arg:match("^(%S+)%s*(.-)$")

    if not cmd or cmd == "" then
        print("FoxChat Roll: /fcroll test | status | debug [on/off] | clear")
        print("  test - 테스트 메시지로 시뮬레이션")
        print("  status - 현재 상태 확인")
        print("  debug on/off - 디버그 모드 켜기/끄기")
        print("  clear - 저장된 메시지 초기화")
        return
    end
    cmd = cmd:lower()

    if cmd == "test" then
        -- 테스트 롤 시뮬레이션
        print("FoxChat Roll: 테스트 시작 (5초 후 결과)")

        -- 강제로 활성화
        if not FoxChatDB then FoxChatDB = {} end
        FoxChatDB.rollTrackerEnabled = true
        FoxChatDB.rollTrackerWindowSec = 5  -- 5초로 단축

        -- 세션 시작하고 테스트 메시지 추가
        RT.sessionActive = false  -- 리셋
        RT:StartSession()

        -- 테스트 메시지들 추가 (범위별로)
        C_Timer.After(0.5, function()
            RT:AddRollMessage("우르사 주사위 굴리기를 하여 95 나왔습니다. (1-100)")
            print("  테스트 메시지 추가: 우르사 - 95 (1-100)")
        end)

        C_Timer.After(1.0, function()
            RT:AddRollMessage("테스트유저 주사위 굴리기를 하여 45 나왔습니다. (1-60)")
            print("  테스트 메시지 추가: 테스트유저 - 45 (1-60)")
        end)

        C_Timer.After(1.5, function()
            RT:AddRollMessage("다른유저 주사위 굴리기를 하여 55 나왔습니다. (1-60)")
            print("  테스트 메시지 추가: 다른유저 - 55 (1-60)")
        end)

        C_Timer.After(2.0, function()
            RT:AddRollMessage("또다른유저 주사위 굴리기를 하여 72 나왔습니다. (1-100)")
            print("  테스트 메시지 추가: 또다른유저 - 72 (1-100)")
        end)

        C_Timer.After(2.5, function()
            RT:AddRollMessage("마지막유저 주사위 굴리기를 하여 50 나왔습니다. (1-60)")
            print("  테스트 메시지 추가: 마지막유저 - 50 (1-60)")
        end)

        C_Timer.After(3.0, function()
            RT:AddRollMessage("우르사 주사위 굴리기를 하여 98 나왔습니다. (1-100)")
            print("  테스트 메시지 추가: 우르사 - 98 (1-100, 다시)")
        end)
    elseif cmd == "testmsg" then
        -- 실제 메시지 테스트
        local testMsg = rest or "우르사|1이;가; 주사위 굴리기를 하여 100|4이;가; 나왔습니다. (1-100)"
        print("=====================================")
        print("테스트 메시지:", testMsg)

        -- 토큰 제거
        local cleanMsg = CleanMessage(testMsg)
        print("토큰 제거 후:", cleanMsg)
        print("")

        -- 기본 패턴 테스트
        print("1. 기본 패턴 테스트:")
        print("  사용 패턴:", ROLL_PATTERN)
        local n, r, mi, ma = testMsg:match(ROLL_PATTERN)
        if n and r and mi and ma then
            print("  원본 [성공] 이름:", n, "결과:", r, "범위:", mi .. "-" .. ma)
        else
            print("  원본 [실패]")
            n, r, mi, ma = cleanMsg:match(ROLL_PATTERN)
            if n and r and mi and ma then
                print("  정리 후 [성공] 이름:", n, "결과:", r, "범위:", mi .. "-" .. ma)
            else
                print("  정리 후 [실패]")
            end
        end

        -- 한국어 패턴 테스트 (정리된 메시지로)
        print("\n2. 한국어 패턴 테스트 (정리된 메시지):")
        local name, roll, minv, maxv
        local matchedPattern = nil
        for i, pattern in ipairs(KOREAN_PATTERNS) do
            name, roll, minv, maxv = cleanMsg:match(pattern)
            if name and roll then
                print("  패턴 #" .. i .. " [성공]")
                print("    패턴:", pattern)
                print("    이름:", name, "결과:", roll)
                if minv and maxv then
                    print("    범위:", minv .. "-" .. maxv)
                else
                    print("    범위: 없음 (기본값 사용)")
                end
                matchedPattern = i
                break
            else
                if i <= 3 then  -- 처음 3개만 상세 출력
                    print("  패턴 #" .. i .. " [실패]")
                end
            end
        end

        if matchedPattern then
            print("\n3. 정규화 테스트:")
            print("  원본 이름:", name)
            print("  이름 길이:", #name)
            print("  바이트 덤프:")
            for i = 1, #name do
                local byte = string.byte(name, i)
                print(string.format("    [%d] = %d (0x%02X) '%s'", i, byte, byte, string.char(byte)))
            end
            local normalizedName = NormalizeName(name)
            print("  정규화된 이름:", normalizedName or "nil")

            if not minv then
                minv, maxv = "1", "100"
            end

            -- AddRoll 테스트
            print("\n4. AddRoll 호출:")
            RT:AddRoll(normalizedName, tonumber(roll), tonumber(minv), tonumber(maxv))
            print("  완료")
        else
            print("\n매칭된 패턴 없음!")
            print("현재 테스트 가능한 메시지 예시:")
            print("  /fcroll testmsg 우르사|1이;가; 주사위 굴리기를 하여 32|1을;를; 나왔습니다. (1-100)")
            print("  /fcroll testmsg 우르사|1이;가; 주사위 굴리기를 하여 71|4이;가; 나왔습니다. (1-100)")
            print("  /fcroll testmsg 플레이어|1이;가; 주사위 굴리기를 하여 100|4이;가; 나왔습니다. (1-100)")
        end
        print("=====================================")
    elseif cmd == "status" then
        print("FoxChat Roll Status:")
        print("  Enabled:", FoxChatDB and FoxChatDB.rollTrackerEnabled and "Yes" or "No")
        print("  Window:", FoxChatDB and FoxChatDB.rollTrackerWindowSec or 20, "seconds")
        print("  Top K:", FoxChatDB and FoxChatDB.rollTrackerTopK or 1)
        print("  Session Active:", RT.sessionActive and "Yes" or "No")
        print("  Messages Stored:", #RT.rollMessages)
        print("  Debug Mode:", addon.DebugMode and "On" or "Off")
        print("  In Raid:", IsInRaid() and "Yes" or "No")
        print("  In Group:", IsInGroup() and "Yes" or "No")
        if #RT.rollMessages > 0 then
            print("  저장된 메시지:")
            for i, msg in ipairs(RT.rollMessages) do
                print("    " .. i .. ": " .. msg)
            end
        end
    elseif cmd == "testname" then
        -- 이름 정규화 테스트
        local testName = rest or "우르사"
        print("=== 이름 정규화 테스트 ===")
        print("입력:", testName)
        local result = NormalizeName(testName)
        print("결과:", result or "nil")
        print("========================")
    elseif cmd == "parse" then
        -- 현재 저장된 메시지 파싱 테스트
        if #RT.rollMessages > 0 then
            print("=== 파싱 테스트 ===")
            for _, msg in ipairs(RT.rollMessages) do
                local name, roll

                -- 패턴 1 시도
                name, roll = msg:match("^(.+)%s+주사위%s+굴리기를%s+하여%s+(%d+)")
                if name then
                    print("패턴1 성공:", msg)
                    print("  이름:", name, "값:", roll)
                else
                    -- 패턴 4 (폴백)
                    name = msg:match("^(%S+)")
                    roll = msg:match("(%d+)")
                    print("폴백 사용:", msg)
                    print("  이름:", name or "nil", "값:", roll or "nil")
                end
            end
        else
            print("저장된 메시지가 없습니다.")
        end
    elseif cmd == "clear" then
        -- 저장된 메시지 초기화
        wipe(RT.rollMessages)
        print("|cFF00FF00[FoxChat Roll] 저장된 메시지가 초기화되었습니다.|r")
    elseif cmd == "debug" then
        local mode = rest and rest:lower() or ""
        if mode == "on" then
            addon.DebugMode = true
            print("|cFF00FF00[FoxChat Roll] 디버그 모드 켜짐|r")
            print("이제 주사위를 굴리면 상세 정보가 출력됩니다.")
        elseif mode == "off" then
            addon.DebugMode = false
            print("|cFFFF0000[FoxChat Roll] 디버그 모드 꺼짐|r")
        else
            addon.DebugMode = not addon.DebugMode
            print("[FoxChat Roll] 디버그 모드:", addon.DebugMode and "|cFF00FF00켜짐|r" or "|cFFFF0000꺼짐|r")
            if addon.DebugMode then
                print("이제 주사위를 굴리면 상세 정보가 출력됩니다.")
            end
        end
    elseif cmd == "patterns" then
        print("FoxChat Roll Patterns:")
        print("  Default pattern:", ROLL_PATTERN)
        print("  Korean patterns:")
        for i, pattern in ipairs(KOREAN_PATTERNS) do
            print("    " .. i .. ":", pattern)
        end
    else
        print("FoxChat Roll: Unknown command:", cmd)
    end
end