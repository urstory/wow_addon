# WoW 거래 시 귓말 전송 시스템 분석

## 현재 구현 방식

### 1. 거래 상대 이름 획득 과정

FoxChat 애드온은 거래 시작부터 완료까지 다음과 같은 이벤트를 처리합니다:

- `TRADE_REQUEST`: 거래 요청 받을 때
- `TRADE_SHOW`: 거래창이 열릴 때
- `TRADE_ACCEPT_UPDATE`: 거래 수락 상태 변경
- `TRADE_CLOSED`: 거래창 닫힘
- `UI_INFO_MESSAGE`: 거래 완료 메시지

### 2. 거래 상대 이름 확인 방법 (`ResolvePartnerName()`)

```lua
local function ResolvePartnerName()
    -- 1순위: TradeFrameRecipientNameText (가장 정확)
    if TradeFrameRecipientNameText and TradeFrameRecipientNameText:GetText() then
        local name = TradeFrameRecipientNameText:GetText()
        if name and name ~= "" then
            return name
        end
    end

    -- 2순위: NPC 유닛
    local npcTarget = UnitName("NPC")
    if npcTarget and npcTarget ~= "" then
        if npcTarget ~= UnitName("player") then
            return npcTarget
        end
    end

    -- 3순위: 현재 타겟 (문제 발생 지점!)
    local targetName = UnitName("target")
    if targetName and targetName ~= UnitName("player") then
        return targetName
    end

    return nil
end
```

### 3. 발견된 문제점

**문제 상황:**
- 플레이어 A를 타겟팅한 상태에서 플레이어 B와 거래
- 거래 완료 시 B가 아닌 A에게 거래 메시지가 전송됨

**원인:**
- `TradeFrameRecipientNameText`가 제대로 작동하지 않을 경우
- 폴백으로 `UnitName("target")`을 사용하여 현재 선택한 대상의 이름을 가져옴
- 실제 거래 상대가 아닌 타겟의 이름으로 귓말 전송

### 4. 거래 메시지 전송 흐름

```lua
-- 거래 완료 감지 (TRADE_CLOSED 이벤트)
if tradeWillComplete and tradePartnerName then
    local tradeMessage = FormatTradeMessage()
    if tradeMessage then
        -- 문제: tradePartnerName이 잘못된 대상일 수 있음
        SendChatMessage(tradeMessage, "WHISPER", nil, tradePartnerName)
    end
end
```

### 5. 거래 데이터 스냅샷

거래 정보는 다음과 같이 저장됩니다:
```lua
tradeSnapshot = {
    givenItems = {},  -- 내가 준 아이템
    gotItems = {},    -- 받은 아이템
    givenMoney = 0,   -- 내가 준 골드
    gotMoney = 0      -- 받은 골드
}
```

## 개선 방안

### 1. 안전한 거래 상대 식별

```lua
-- 개선된 방법: target 폴백 제거
local function ResolvePartnerName()
    -- TradeFrameRecipientNameText만 사용
    if TradeFrameRecipientNameText and TradeFrameRecipientNameText:GetText() then
        local name = TradeFrameRecipientNameText:GetText()
        if name and name ~= "" then
            return name
        end
    end

    -- NPC 거래만 체크
    local npcTarget = UnitName("NPC")
    if npcTarget and npcTarget ~= "" then
        if npcTarget ~= UnitName("player") then
            return npcTarget
        end
    end

    -- target 폴백 제거 - 부정확한 결과 방지
    return nil
end
```

### 2. TRADE_SHOW에서 정확한 이름 캡처

```lua
-- TRADE_SHOW 이벤트 처리 시
if event == "TRADE_SHOW" then
    -- 거래창이 완전히 로드될 때까지 대기
    C_Timer.After(0.1, function()
        local resolvedName = ResolvePartnerName()
        if resolvedName then
            tradePartnerName = NormalizeName(resolvedName)
        end
    end)
end
```

### 3. 거래 요청자 정보 활용

```lua
-- TRADE_REQUEST 이벤트에서 요청자 저장
if event == "TRADE_REQUEST" then
    local requester = arg1  -- 거래 요청한 플레이어 이름
    if requester and requester ~= "" then
        tradePartnerName = NormalizeName(requester)
    end
end
```

## 정리

현재 FoxChat의 거래 귓말 시스템은 거래 상대를 식별할 때 `target` 유닛을 폴백으로 사용하여 잘못된 대상에게 메시지를 보낼 수 있는 버그가 있습니다.

**핵심 해결책:**
1. `UnitName("target")` 폴백 제거
2. `TradeFrameRecipientNameText` 의존도 높이기
3. `TRADE_REQUEST` 이벤트의 요청자 정보 적극 활용
4. 거래 상대를 확실히 식별할 수 없으면 메시지 전송하지 않기

이를 통해 엉뚱한 사람에게 거래 메시지가 가는 문제를 방지할 수 있습니다.