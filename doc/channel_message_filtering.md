# WoW Classic 1.12 채널 메시지 필터링 구현 가이드

## 개요
이 문서는 WoW Classic 1.12에서 특정 채널의 메시지를 필터링하고 처리하는 방법을 설명합니다.

## 1. 채널 메시지 이벤트 처리

### 이벤트 등록
```lua
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_CHANNEL")
```

### 이벤트 핸들러 구성
WoW Classic 1.12에서는 이벤트 파라미터가 함수 매개변수로 전달됩니다:

```lua
frame:SetScript("OnEvent", function(self, eventName, ...)
    local arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 = ...

    if eventName == "CHAT_MSG_CHANNEL" then
        -- arg1: 메시지 내용
        -- arg2: 발신자 (서버명 포함: "닉네임-서버명")
        -- arg3: 언어
        -- arg4: 채널 전체 이름 (예: "5. 파티찾기")
        -- arg5: 발신자 (서버명 제외)
        -- arg6: AFK/DND/GM 플래그
        -- arg7: 존 ID
        -- arg8: 채널 번호
        -- arg9: 채널 이름
    end
end)
```

## 2. 채널 필터링 구현

### 특정 채널 선택
```lua
local selectedChannel = 5  -- 파티찾기 채널 번호

if tonumber(arg8) == selectedChannel then
    -- 선택된 채널의 메시지 처리
end
```

### 채널 이름으로 필터링
```lua
local channelName = string.lower(arg9 or "")
if string.find(channelName, "파티찾기") then
    -- 파티찾기 채널 메시지 처리
end
```

## 3. 메시지 필터링

### 키워드 기반 필터링
```lua
function ShouldFilterMessage(message, filterKeywords, ignoreKeywords)
    local lowerMessage = string.lower(message)

    -- 무시 키워드 확인 (있으면 메시지 제외)
    for _, keyword in ipairs(ignoreKeywords) do
        if string.find(lowerMessage, keyword, 1, true) then
            return false
        end
    end

    -- 필터 키워드 확인 (없으면 모든 메시지 표시)
    if #filterKeywords == 0 then
        return true
    end

    -- 필터 키워드 중 하나라도 포함되면 표시
    for _, keyword in ipairs(filterKeywords) do
        if string.find(lowerMessage, keyword, 1, true) then
            return true
        end
    end

    return false
end
```

### 짧은 메시지 필터링
```lua
-- 5글자 이하 메시지 제거
if string.len(message) <= 5 then
    return
end
```

### 특정 단어 필터링
```lua
-- 위상 관련 메시지 제거
if string.find(message, "일위상") or
   string.find(message, "이위상") or
   string.find(message, "삼위상") then
    return
end
```

## 4. 메시지 저장 및 관리

### 메시지 중복 제거
```lua
local messages = {}

function AddMessage(author, message)
    -- 같은 작성자의 이전 메시지 제거
    for i, msg in ipairs(messages) do
        if msg.author == author then
            table.remove(messages, i)
            break
        end
    end

    -- 새 메시지 추가
    table.insert(messages, 1, {
        author = author,
        message = message,
        timestamp = time()
    })
end
```

### 시간 기반 자동 삭제
```lua
function CleanupOldMessages()
    local currentTime = time()
    for i = #messages, 1, -1 do
        if currentTime - messages[i].timestamp > 60 then
            table.remove(messages, i)
        end
    end
end
```

## 5. 채널 목록 가져오기

```lua
function GetChannelList()
    local channels = {}
    local channelList = {GetChannelList()}

    -- GetChannelList는 3개씩 그룹으로 반환
    for i = 1, table.getn(channelList), 3 do
        local id = channelList[i]        -- 채널 번호
        local name = channelList[i + 1]  -- 채널 이름
        local joined = channelList[i + 2] -- 참여 여부

        if type(id) == "number" and type(name) == "string" then
            table.insert(channels, {
                id = id,
                name = name,
                joined = joined
            })
        end
    end

    return channels
end
```

## 6. 주의사항

### WoW Classic 1.12 특이사항
1. **이벤트 파라미터**: 전역 변수가 아닌 함수 매개변수로 전달
2. **string.gsub**: boolean 파라미터 미지원 (4번째 인자로 true 사용 불가)
3. **PlaySound**: 숫자 ID 사용 (문자열 이름 미지원)
4. **SetBackdrop**: 미지원 (텍스처로 직접 구현)

### 성능 최적화
1. 메시지 개수 제한 (예: 최대 50개)
2. 정기적인 오래된 메시지 정리
3. 채널 번호로 먼저 필터링 후 내용 검사

## 예제 구현

```lua
-- 완전한 채널 메시지 처리 예제
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_CHANNEL")

local filteredMessages = {}
local selectedChannel = 5  -- 파티찾기

frame:SetScript("OnEvent", function(self, eventName, ...)
    if eventName == "CHAT_MSG_CHANNEL" then
        local arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 = ...

        local message = arg1
        local sender = arg2
        local channelNum = tonumber(arg8)

        -- 채널 확인
        if channelNum ~= selectedChannel then
            return
        end

        -- 메시지 길이 확인
        if string.len(message) <= 5 then
            return
        end

        -- 발신자 이름 정리
        local cleanSender = arg5 or sender
        local dashPos = string.find(cleanSender, "-")
        if dashPos then
            cleanSender = string.sub(cleanSender, 1, dashPos - 1)
        end

        -- 메시지 저장
        AddFilteredMessage(cleanSender, message)
    end
end)
```