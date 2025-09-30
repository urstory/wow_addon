local addonName, addon = ...

-- 거래 자동 기능 모듈
FoxChat = FoxChat or {}
FoxChat.Features = FoxChat.Features or {}
FoxChat.Features.AutoTrade = {}

local AutoTrade = FoxChat.Features.AutoTrade
local L = addon.L

-- 거래 정보 저장
local tradePartnerName = nil
local tradeSnapshot = {
    givenItems = {},
    gotItems = {},
    givenMoney = 0,
    gotMoney = 0
}

-- 초기화
function AutoTrade:Initialize()
    -- 이벤트 등록
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("TRADE_SHOW")
    frame:RegisterEvent("TRADE_UPDATE")
    frame:RegisterEvent("TRADE_ACCEPT_UPDATE")
    frame:RegisterEvent("TRADE_CLOSED")

    frame:SetScript("OnEvent", function(self, event, ...)
        AutoTrade:OnEvent(event, ...)
    end)

    -- FoxChat 이벤트 등록
    if FoxChat.Events then
        FoxChat.Events:Register("FOXCHAT_CONFIG_LOADED", function()
            -- 설정이 로드되면 기능 업데이트
        end)
    end

    FoxChat:Debug("AutoTrade 모듈 초기화 완료")
end

-- WoW 이벤트 처리
function AutoTrade:OnEvent(event, ...)
    if event == "TRADE_SHOW" then
        self:OnTradeShow()
    elseif event == "TRADE_UPDATE" then
        self:OnTradeUpdate()
    elseif event == "TRADE_ACCEPT_UPDATE" then
        self:OnTradeAcceptUpdate(...)
    elseif event == "TRADE_CLOSED" then
        self:OnTradeClosed()
    end
end

-- 거래창 열림
function AutoTrade:OnTradeShow()
    -- 파트너 이름 얻기
    tradePartnerName = self:ResolvePartnerName()
    FoxChat:Debug("거래 시작:", tradePartnerName or "Unknown")
end

-- 거래 업데이트
function AutoTrade:OnTradeUpdate()
    -- 파트너 이름 재확인
    if not tradePartnerName then
        tradePartnerName = self:ResolvePartnerName()
    end
end

-- 거래 수락 업데이트
function AutoTrade:OnTradeAcceptUpdate(player, target)
    -- 둘 다 수락했으면 스냅샷
    if player == 1 and target == 1 then
        self:SnapshotTradeData()
    end
end

-- 거래창 닫힘
function AutoTrade:OnTradeClosed()
    -- 자동 귓속말 기능 활성화 확인
    if not self:IsEnabled() then
        return
    end

    -- 거래가 완료된 경우 메시지 전송
    if tradePartnerName and (next(tradeSnapshot.givenItems) or next(tradeSnapshot.gotItems) or
       tradeSnapshot.givenMoney > 0 or tradeSnapshot.gotMoney > 0) then

        local message = self:FormatTradeMessage()
        if message then
            self:SendWhisper(tradePartnerName, message)
        end
    end

    -- 초기화
    self:ClearTradeData()
end

-- 파트너 이름 얻기
function AutoTrade:ResolvePartnerName()
    -- TradeFrameRecipientNameText가 가장 정확
    if TradeFrameRecipientNameText and TradeFrameRecipientNameText:GetText() then
        local name = TradeFrameRecipientNameText:GetText()
        if name and name ~= "" then
            return self:NormalizeName(name)
        end
    end

    -- NPC 타겟 체크
    local npcTarget = UnitName("NPC")
    if npcTarget and npcTarget ~= "" then
        if npcTarget ~= UnitName("player") then
            return self:NormalizeName(npcTarget)
        end
    end

    -- 대체 방법: 타겟
    local targetName = UnitName("target")
    if targetName and targetName ~= UnitName("player") then
        return self:NormalizeName(targetName)
    end

    return nil
end

-- 이름 정규화
function AutoTrade:NormalizeName(name)
    if not name or name == "" then
        return nil
    end

    -- Ambiguate 함수가 있으면 서버명 제거
    if Ambiguate then
        name = Ambiguate(name, "none")
    else
        -- 수동으로 서버명 제거
        name = name:gsub("%-.+$", "")
    end

    -- 색코드 제거
    name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")

    -- 앞뒤 공백 제거
    name = name:match("^%s*(.-)%s*$")

    return name ~= "" and name or nil
end

-- 거래 정보 스냅샷
function AutoTrade:SnapshotTradeData()
    tradeSnapshot.givenItems = {}
    tradeSnapshot.gotItems = {}

    local TRADE_SLOTS = MAX_TRADE_ITEMS or 6

    -- 내가 준 아이템들
    for i = 1, TRADE_SLOTS do
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
    for i = 1, TRADE_SLOTS do
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

    -- 금액
    local givenMoney = GetPlayerTradeMoney()
    local gotMoney = GetTargetTradeMoney()

    -- 문자열이면 숫자로 변환
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

    FoxChat:Debug("거래 스냅샷 완료")
end

-- 금액 포맷
function AutoTrade:FormatMoney(copper)
    if FoxChat.Utils and FoxChat.Utils.Common then
        return FoxChat.Utils.Common:FormatMoney(copper)
    end

    -- 폴백
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

-- 거래 메시지 생성
function AutoTrade:FormatTradeMessage()
    if not tradePartnerName then
        return nil
    end

    local myName = UnitName("player")
    local givenItemsStr = #tradeSnapshot.givenItems > 0 and table.concat(tradeSnapshot.givenItems, ", ") or "없음"
    local gotItemsStr = #tradeSnapshot.gotItems > 0 and table.concat(tradeSnapshot.gotItems, ", ") or "없음"
    local givenMoneyStr = self:FormatMoney(tradeSnapshot.givenMoney)
    local gotMoneyStr = self:FormatMoney(tradeSnapshot.gotMoney)

    -- 메시지 조합
    local givenParts = {}
    if givenItemsStr ~= "없음" then table.insert(givenParts, givenItemsStr) end
    if givenMoneyStr ~= "" then table.insert(givenParts, givenMoneyStr) end
    local givenTotal = #givenParts > 0 and table.concat(givenParts, ", ") or "없음"

    local gotParts = {}
    if gotItemsStr ~= "없음" then table.insert(gotParts, gotItemsStr) end
    if gotMoneyStr ~= "" then table.insert(gotParts, gotMoneyStr) end
    local gotTotal = #gotParts > 0 and table.concat(gotParts, ", ") or "없음"

    -- 거래 방향에 따른 메시지 분기
    local message
    if gotTotal ~= "없음" and givenTotal == "없음" then
        -- 받기만 한 경우
        message = string.format(
            "[거래] %s님께서 %s 주셨습니다.",
            tradePartnerName,
            gotTotal
        )
    elseif gotTotal == "없음" and givenTotal ~= "없음" then
        -- 주기만 한 경우
        message = string.format(
            "[거래] %s님께 %s 전달했습니다.",
            tradePartnerName,
            givenTotal
        )
    else
        -- 양방향 거래
        message = string.format(
            "[거래] %s님과 거래 완료! (받음: %s / 드림: %s)",
            tradePartnerName,
            gotTotal,
            givenTotal
        )

        -- 메시지가 너무 길면 축약
        if string.len(message) > 240 then
            message = self:ShortenTradeMessage()
        end
    end

    return message
end

-- 긴 메시지 축약
function AutoTrade:ShortenTradeMessage()
    local shortGotItems = {}
    local shortGivenItems = {}
    local gotMoneyStr = self:FormatMoney(tradeSnapshot.gotMoney)
    local givenMoneyStr = self:FormatMoney(tradeSnapshot.givenMoney)

    -- 받은 아이템 최대 3개까지만
    for i = 1, math.min(3, #tradeSnapshot.gotItems) do
        table.insert(shortGotItems, tradeSnapshot.gotItems[i])
    end
    if #tradeSnapshot.gotItems > 3 then
        table.insert(shortGotItems, string.format("외 %d개", #tradeSnapshot.gotItems - 3))
    end

    -- 준 아이템 최대 2개까지만
    for i = 1, math.min(2, #tradeSnapshot.givenItems) do
        table.insert(shortGivenItems, tradeSnapshot.givenItems[i])
    end
    if #tradeSnapshot.givenItems > 2 then
        table.insert(shortGivenItems, string.format("외 %d개", #tradeSnapshot.givenItems - 2))
    end

    -- 짧은 버전 조합
    local shortGotParts = {}
    if #shortGotItems > 0 then
        table.insert(shortGotParts, table.concat(shortGotItems, ", "))
    end
    if gotMoneyStr ~= "" then
        table.insert(shortGotParts, gotMoneyStr)
    end
    local shortGotTotal = #shortGotParts > 0 and table.concat(shortGotParts, ", ") or "없음"

    local shortGivenParts = {}
    if #shortGivenItems > 0 then
        table.insert(shortGivenParts, table.concat(shortGivenItems, ", "))
    end
    if givenMoneyStr ~= "" then
        table.insert(shortGivenParts, givenMoneyStr)
    end
    local shortGivenTotal = #shortGivenParts > 0 and table.concat(shortGivenParts, ", ") or "없음"

    return string.format(
        "[거래] %s님과 거래 완료! (받음: %s / 드림: %s)",
        tradePartnerName,
        shortGotTotal,
        shortGivenTotal
    )
end

-- 귓속말 전송
function AutoTrade:SendWhisper(target, message)
    if not target or not message then
        return
    end

    -- 메시지 길이 체크
    if FoxChat.Utils and FoxChat.Utils.UTF8 then
        message = FoxChat.Utils.UTF8:TrimByBytes(message, 255)
    elseif #message > 255 then
        message = string.sub(message, 1, 255)
    end

    SendChatMessage(message, "WHISPER", nil, target)
    FoxChat:Debug("거래 귓속말 전송:", target, message)

    -- 이벤트 발생
    if FoxChat.Events then
        FoxChat.Events:Trigger("FOXCHAT_TRADE_COMPLETED", target, message)
    end
end

-- 거래 데이터 초기화
function AutoTrade:ClearTradeData()
    tradePartnerName = nil
    tradeSnapshot.givenItems = {}
    tradeSnapshot.gotItems = {}
    tradeSnapshot.givenMoney = 0
    tradeSnapshot.gotMoney = 0
end

-- 활성화 여부
function AutoTrade:IsEnabled()
    return FoxChatDB and FoxChatDB.autoTrade
end

function AutoTrade:Enable()
    if FoxChatDB then
        FoxChatDB.autoTrade = true
        FoxChat:Print("거래 자동 귓속말이 활성화되었습니다.")
    end
end

function AutoTrade:Disable()
    if FoxChatDB then
        FoxChatDB.autoTrade = false
        FoxChat:Print("거래 자동 귓속말이 비활성화되었습니다.")
    end
end

function AutoTrade:Toggle()
    if self:IsEnabled() then
        self:Disable()
    else
        self:Enable()
    end
end