# FoxChat 거래 자동 귓속말 기능 문제 분석

## 문제 상황
WoW 클래식 1.15 환경에서 거래 완료 시 상대방에게 자동으로 거래 내역을 귓속말로 보내는 기능이 작동하지 않음

## 현재 구현된 코드

### 1. 전역 변수 및 초기화
```lua
-- 거래 완료 시 자동 귓속말
local tradePartnerName = nil
local tradePlayerAccepted = false
local tradeTargetAccepted = false
local tradeWillComplete = false  -- 거래 성공 예정 플래그
local tradeSnapshot = { givenItems = {}, gotItems = {}, givenMoney = 0, gotMoney = 0 }
```

### 2. 돈 포맷 함수
```lua
-- 도우미: 동전(코퍼) → 골드/실버/코퍼 문자열
local function FormatMoney(copper)
    copper = copper or 0
    if copper == 0 then return "" end

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local c = copper % 100

    local parts = {}
    if gold > 0 then table.insert(parts, string.format("%d골드", gold)) end
    if silver > 0 then table.insert(parts, string.format("%d실버", silver)) end
    if c > 0 then table.insert(parts, string.format("%d코퍼", c)) end

    if #parts == 0 then return "" end
    return table.concat(parts, " ")
end
```

### 3. 거래 상대 이름 확인
```lua
-- 파트너 이름 얻기
local function ResolvePartnerName()
    -- TradeFrameRecipientNameText가 가장 정확
    if TradeFrameRecipientNameText and TradeFrameRecipientNameText:GetText() then
        local name = TradeFrameRecipientNameText:GetText()
        if name and name ~= "" then
            return name
        end
    end

    -- 대체 방법: NPC가 아닌 타겟
    local targetName = UnitName("target")
    if targetName and targetName ~= UnitName("player") and UnitIsPlayer("target") then
        return targetName
    end

    return nil
end
```

### 4. 거래 데이터 스냅샷
```lua
-- 거래 정보 스냅샷 (TRADE_CLOSED 시점에 정보가 사라질 수 있으므로 미리 저장)
local function SnapshotTradeData()
    tradeSnapshot.givenItems = {}
    tradeSnapshot.gotItems = {}

    local MAX_TRADE_ITEMS = MAX_TRADE_ITEMS or 6  -- 클래식은 보통 6개 슬롯

    -- 내가 준 아이템들
    for i = 1, MAX_TRADE_ITEMS do
        local name, texture, quantity, quality, isUsable, enchant = GetTradePlayerItemInfo(i)
        local link = GetTradePlayerItemLink(i)
        if name then
            local label = link or name
            if (quantity or 1) > 1 then
                table.insert(tradeSnapshot.givenItems, string.format("%s(%d)", label, quantity))
            else
                table.insert(tradeSnapshot.givenItems, label)
            end
        end
    end

    -- 내가 받은 아이템들
    for i = 1, MAX_TRADE_ITEMS do
        local name, texture, quantity, quality, isUsable, enchant = GetTradeTargetItemInfo(i)
        local link = GetTradeTargetItemLink(i)
        if name then
            local label = link or name
            if (quantity or 1) > 1 then
                table.insert(tradeSnapshot.gotItems, string.format("%s(%d)", label, quantity))
            else
                table.insert(tradeSnapshot.gotItems, label)
            end
        end
    end

    -- 금액 (문자열로 반환될 수 있으므로 숫자로 변환)
    local givenMoney = GetPlayerTradeMoney()
    local gotMoney = GetTargetTradeMoney()

    -- 문자열이면 숫자로 변환, nil이면 0
    if type(givenMoney) == "string" then
        tradeSnapshot.givenMoney = tonumber(givenMoney) or 0
    else
        tradeSnapshot.givenMoney = givenMoney or 0
    end

    if type(gotMoney) == "string" then
        tradeSnapshot.gotMoney = tonumber(gotMoney) or 0
    else
        tradeSnapshot.gotMoney = gotMoney or 0
    end
end
```

### 5. 거래 메시지 생성
```lua
-- 거래 메시지 생성
local function FormatTradeMessage()
    if not tradePartnerName then return nil end

    local myName = UnitName("player")
    local givenItemsStr = #tradeSnapshot.givenItems > 0 and table.concat(tradeSnapshot.givenItems, ", ") or "없음"
    local gotItemsStr = #tradeSnapshot.gotItems > 0 and table.concat(tradeSnapshot.gotItems, ", ") or "없음"
    local givenMoneyStr = FormatMoney(tradeSnapshot.givenMoney)
    local gotMoneyStr = FormatMoney(tradeSnapshot.gotMoney)

    -- 메시지 조합
    local givenParts = {}
    if givenItemsStr ~= "없음" then table.insert(givenParts, givenItemsStr) end
    if givenMoneyStr ~= "" then table.insert(givenParts, givenMoneyStr) end
    local givenTotal = #givenParts > 0 and table.concat(givenParts, ", ") or "없음"

    local gotParts = {}
    if gotItemsStr ~= "없음" then table.insert(gotParts, gotItemsStr) end
    if gotMoneyStr ~= "" then table.insert(gotParts, gotMoneyStr) end
    local gotTotal = #gotParts > 0 and table.concat(gotParts, ", ") or "없음"

    local message = string.format(
        "[거래] %s님에게 %s을(를) 받았고, 나(%s)는 %s을(를) 주었습니다.",
        tradePartnerName,
        gotTotal,
        myName,
        givenTotal
    )

    return message
end
```

### 6. 이벤트 핸들러
```lua
-- 이벤트 핸들러 추가
local autoEventFrame = CreateFrame("Frame")
autoEventFrame:RegisterEvent("TRADE_SHOW")
autoEventFrame:RegisterEvent("TRADE_ACCEPT_UPDATE")
autoEventFrame:RegisterEvent("TRADE_CLOSED")

autoEventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "TRADE_SHOW" then
        -- 거래창 열림: 상태 초기화 및 상대 이름 확보
        tradePlayerAccepted = false
        tradeTargetAccepted = false
        tradePartnerName = ResolvePartnerName()

        -- 디버그 메시지
        if FoxChatDB and FoxChatDB.autoTrade then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 거래 시작 - 상대: " .. (tradePartnerName or "알 수 없음"))
        end

    elseif event == "TRADE_ACCEPT_UPDATE" then
        local arg1, arg2 = ...  -- WoW 클래식에서는 arg1, arg2로 전달됨
        tradePlayerAccepted = (arg1 == 1)
        tradeTargetAccepted = (arg2 == 1)

        -- 디버그 메시지
        if FoxChatDB and FoxChatDB.autoTrade then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFF7D0A[FoxChat]|r 수락 상태 - Player: %d, Target: %d",
                arg1 or 0, arg2 or 0))
        end

        -- 양쪽 모두 수락 직전에 데이터 스냅샷
        if tradePlayerAccepted and tradeTargetAccepted then
            tradeWillComplete = true  -- 거래 성공 예정 플래그 설정
            SnapshotTradeData()
            if FoxChatDB and FoxChatDB.autoTrade then
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 거래 성공 예정 - 데이터 스냅샷 완료")
            end
        else
            tradeWillComplete = false
        end

    elseif event == "TRADE_CLOSED" then
        -- 디버그 메시지
        if FoxChatDB and FoxChatDB.autoTrade then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFF7D0A[FoxChat]|r 거래 종료 - 성공예정=%s, 파트너=%s",
                tostring(tradeWillComplete), tostring(tradePartnerName)))
        end

        -- 거래 성공 판단 (tradeWillComplete 플래그 확인)
        if tradeWillComplete and tradePartnerName then
            if FoxChatDB and FoxChatDB.autoTrade then
                local tradeMessage = FormatTradeMessage()
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 거래 성공!")
                if tradeMessage then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 전송 예정 메시지: " .. tradeMessage)
                    -- 즉시 전송 (딜레이 제거)
                    SendChatMessage(tradeMessage, "WHISPER", nil, tradePartnerName)
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r ✓ 귓속말 전송 완료: " .. tradePartnerName)
                else
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r ✗ 메시지 생성 실패")
                end
            end
        else
            if FoxChatDB and FoxChatDB.autoTrade then
                if not tradeWillComplete then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 거래 취소")
                elseif not tradePartnerName then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 상대 이름 식별 실패")
                end
            end
        end

        -- 상태 초기화
        tradePlayerAccepted = false
        tradeTargetAccepted = false
        tradeWillComplete = false
        tradePartnerName = nil
        tradeSnapshot = { givenItems = {}, gotItems = {}, givenMoney = 0, gotMoney = 0 }

    -- ... 다른 이벤트들
    end
end)
```

## 디버그를 위한 체크리스트

### 1. 거래 시작 시
- [ ] "거래 시작 - 상대: [이름]" 메시지가 나오는가?
- [ ] 상대 이름이 올바르게 표시되는가? 아니면 "알 수 없음"인가?

### 2. 수락 버튼 클릭 시
- [ ] "수락 상태 - Player: X, Target: X" 메시지가 나오는가?
- [ ] 양쪽 모두 1이 되는가? (Player: 1, Target: 1)
- [ ] "거래 성공 예정 - 데이터 스냅샷 완료" 메시지가 나오는가?

### 3. 거래 완료 시
- [ ] "거래 종료 - 성공예정=true, 파트너=[이름]" 메시지가 나오는가?
- [ ] "거래 성공!" 메시지가 나오는가?
- [ ] "전송 예정 메시지: [내용]" 이 표시되는가?
- [ ] "✓ 귓속말 전송 완료: [이름]" 메시지가 나오는가?

## 가능한 문제점

### 1. TRADE_ACCEPT_UPDATE 이벤트 인자 문제
- WoW 클래식에서 인자가 다르게 전달될 수 있음
- `arg1`, `arg2` 대신 다른 형태일 가능성

### 2. TradeFrameRecipientNameText 문제
- 이 UI 요소가 클래식에서 없거나 다른 이름일 수 있음
- 상대 이름을 제대로 못 가져오고 있을 가능성

### 3. SendChatMessage 파라미터 문제
- 언어 파라미터(nil) 위치가 문제일 수 있음
- 상대 이름에 특수문자나 서버명이 포함되어 있을 가능성

### 4. FoxChatDB.autoTrade 설정값
- 설정이 false로 되어 있을 가능성
- DB 초기화 문제

## 추가 디버그 코드 제안

```lua
-- TRADE_ACCEPT_UPDATE 이벤트에 추가
DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFF7D0A[FoxChat]|r RAW 인자: arg1=%s, arg2=%s, type1=%s, type2=%s",
    tostring(arg1), tostring(arg2), type(arg1), type(arg2)))

-- SendChatMessage 직전에 추가
DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFF7D0A[FoxChat]|r SendChat 파라미터: msg길이=%d, channel=WHISPER, lang=nil, target=%s",
    string.len(tradeMessage or ""), tradePartnerName or "nil"))
```

## 질문 사항
1. 디버그 메시지 중 어디까지 표시되는지?
2. 상대 이름이 제대로 감지되는지?
3. 수락 상태 값이 1, 1로 제대로 바뀌는지?
4. FoxChatDB.autoTrade 설정이 켜져 있는지?
5. 오류 메시지가 나오는지? (/console scriptErrors 1)

## 파일 위치
- 애드온 경로: `/Users/toto/devel/wow/exam01/FoxChat/`
- 주요 파일: `FoxChat.lua` (라인 1744-2157)
- 설정 파일: `CLAUDE.md` 동일 경로