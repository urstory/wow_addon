local addonName, addon = ...

-- 토스트 알림 시스템
FoxChat = FoxChat or {}
FoxChat.UI = FoxChat.UI or {}
FoxChat.UI.Toast = {}

local Toast = FoxChat.UI.Toast
local L = addon.L

-- 토스트 관련 변수
local activeToasts = {}      -- 현재 활성화된 토스트 목록
local toastPool = {}         -- 재사용 가능한 토스트 프레임 풀
local authorCooldowns = {}   -- 사용자별 쿨다운 추적
local MAX_TOASTS = 3         -- 최대 토스트 개수

-- 초기화
function Toast:Initialize()
    activeToasts = {}
    toastPool = {}
    authorCooldowns = {}

    -- 이벤트 등록
    if FoxChat.Events then
        FoxChat.Events:Register("FOXCHAT_TOAST_REPOSITION", function()
            self:RepositionAll()
        end)
    end
end

-- 활성화된 토스트들의 위치를 재정렬
function Toast:RepositionAll()
    local xOffset = 0
    local baseYOffset = -320

    -- 설정에서 위치 가져오기
    if FoxChatDB and FoxChatDB.toastPosition then
        xOffset = FoxChatDB.toastPosition.x or xOffset
        baseYOffset = FoxChatDB.toastPosition.y or baseYOffset
    end

    for i, f in ipairs(activeToasts) do
        f:ClearAllPoints()
        -- 첫 번째 토스트는 설정된 위치에, 나머지는 위로 쌓임
        local yOffset = baseYOffset + ((i - 1) * (f:GetHeight() + 5))
        f:SetPoint("CENTER", UIParent, "CENTER", xOffset, yOffset)
    end
end

-- 토스트 프레임을 풀에서 가져오거나 새로 생성
function Toast:GetFrame()
    local f = table.remove(toastPool)
    if f then
        return f
    end

    -- 새 프레임 생성
    f = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    f:SetWidth(450)  -- 고정 너비, 높이는 동적으로 조정

    local xOffset = 0
    local yOffset = -320

    if FoxChatDB and FoxChatDB.toastPosition then
        xOffset = FoxChatDB.toastPosition.x or xOffset
        yOffset = FoxChatDB.toastPosition.y or yOffset
    end

    f:SetPoint("CENTER", UIParent, "CENTER", xOffset, yOffset)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(100)
    f:Hide()
    f:EnableMouse(true)
    f:RegisterForClicks("LeftButtonUp")

    -- 배경
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0, 0, 0, 0.8)

    -- 테두리
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        f:SetBackdropColor(0, 0, 0, 0.8)
        f:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end

    -- 작성자 텍스트
    f.author = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.author:SetPoint("TOPLEFT", 15, -10)
    f.author:SetPoint("TOPRIGHT", -15, -10)
    f.author:SetJustifyH("LEFT")
    f.author:SetWordWrap(false)

    -- 메시지 텍스트
    f.message = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.message:SetPoint("TOPLEFT", f.author, "BOTTOMLEFT", 0, -5)
    f.message:SetPoint("TOPRIGHT", f.author, "BOTTOMRIGHT", 0, -5)
    f.message:SetJustifyH("LEFT")
    f.message:SetJustifyV("TOP")
    f.message:SetTextColor(1, 1, 1)
    f.message:SetWordWrap(true)
    f.message:SetMaxLines(4)  -- 최대 4줄까지 표시

    -- 애니메이션 그룹
    f.animIn = f:CreateAnimationGroup()
    local fadeIn = f.animIn:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.3)
    fadeIn:SetSmoothing("OUT")

    f.animOut = f:CreateAnimationGroup()
    local fadeOut = f.animOut:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(0.5)
    fadeOut:SetSmoothing("IN")
    fadeOut:SetStartDelay(3)  -- 3초 대기 후 페이드 아웃

    f.animOut:SetScript("OnFinished", function(self)
        local frame = self:GetParent()
        frame:Hide()
        frame.currentAuthor = nil  -- 현재 저자 초기화

        -- activeToasts에서 제거
        for i, toast in ipairs(activeToasts) do
            if toast == frame then
                table.remove(activeToasts, i)
                break
            end
        end

        -- 프레임을 풀에 반환
        table.insert(toastPool, frame)

        -- 모든 토스트 위치 재정렬
        Toast:RepositionAll()
    end)

    -- 토스트 클릭 시 귓속말 열기
    f:SetScript("OnClick", function(self, button)
        if button == "LeftButton" and self.currentAuthor then
            -- 채팅창에 /w 닉네임 설정
            ChatFrame_OpenChat("/w " .. self.currentAuthor .. " ", DEFAULT_CHAT_FRAME)
        end
    end)

    -- 마우스 오버 시 커서 변경
    f:SetScript("OnEnter", function(self)
        if self.currentAuthor then
            SetCursor("Interface\\Cursor\\Speak")
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine("클릭하면 " .. self.currentAuthor .. "님에게 귓속말", 1, 1, 1)
            GameTooltip:Show()
        end
    end)

    f:SetScript("OnLeave", function(self)
        SetCursor(nil)
        GameTooltip:Hide()
    end)

    return f
end

-- 메시지에서 색상 코드 및 링크 제거
function Toast:CleanMessage(message)
    if not message then return "" end

    local cleanMessage = message

    -- 퀘스트 링크 처리
    -- [[27D]격노(378)] -> 격노
    -- [[50+] 고대의 알] -> 고대의 알
    -- [뾰족부리 구출 (2994)] -> 뾰족부리 구출

    -- 더블 브라켓 형식: [[anything] quest name (number)]
    cleanMessage = string.gsub(cleanMessage, "%[%[[^%]]+%]%s*([^%(%)%[%]]+)%s*%(%d+%)%]", "%1")
    -- 더블 브라켓 형식 (괄호 없음): [[anything] quest name]
    cleanMessage = string.gsub(cleanMessage, "%[%[[^%]]+%]%s*([^%[%]]+)%]", "%1")
    -- 싱글 브라켓 형식: [quest name (number)]
    cleanMessage = string.gsub(cleanMessage, "%[([^%(%)%[%]]+)%s*%(%d+%)%]", "%1")

    -- 여분의 공백 정리
    cleanMessage = string.gsub(cleanMessage, "(%S)%s+(%S)", "%1 %2")

    -- 색상 코드 및 링크 제거
    cleanMessage = string.gsub(cleanMessage, "|c%x%x%x%x%x%x%x%x", "")
    cleanMessage = string.gsub(cleanMessage, "|r", "")
    cleanMessage = string.gsub(cleanMessage, "|H.-|h(.-)|h", "%1")

    -- 공백 정리
    cleanMessage = string.trim(cleanMessage)

    -- 메시지가 너무 길면 자르기
    if string.len(cleanMessage) > 200 then
        cleanMessage = string.sub(cleanMessage, 1, 197) .. "..."
    end

    return cleanMessage
end

-- 토스트 알림 표시
function Toast:Show(author, message, channelGroup, isTest)
    -- 동일 사용자 쿨다운 체크 (10초) - 테스트인 경우 스킵
    local currentTime = GetTime()
    if not isTest and author and authorCooldowns[author] then
        if currentTime - authorCooldowns[author] < 10 then
            return  -- 10초 이내에 동일 사용자 메시지는 무시
        end
    end

    -- 최대 토스트 개수 체크
    if #activeToasts >= MAX_TOASTS then
        -- 가장 오래된 토스트 제거
        local oldestToast = activeToasts[1]
        if oldestToast and oldestToast.animOut then
            oldestToast.animOut:Stop()
            oldestToast:Hide()
            table.remove(activeToasts, 1)
            table.insert(toastPool, oldestToast)
            self:RepositionAll()
        end
    end

    -- 쿨다운 업데이트 (테스트가 아닌 경우에만)
    if not isTest and author then
        authorCooldowns[author] = currentTime
        -- 30초 후에 쿨다운 데이터 제거 (메모리 관리)
        C_Timer.After(30, function()
            if authorCooldowns[author] and GetTime() - authorCooldowns[author] >= 30 then
                authorCooldowns[author] = nil
            end
        end)
    end

    -- 토스트 프레임 가져오기
    local f = self:GetFrame()

    -- 채널별 색상 설정
    local color = nil
    if FoxChatDB and FoxChatDB.highlightColors and FoxChatDB.highlightColors[channelGroup] then
        color = FoxChatDB.highlightColors[channelGroup]
    elseif channelGroup == "GUILD" then
        color = {r = 0, g = 1, b = 0}
    elseif channelGroup == "PUBLIC" then
        color = {r = 1, g = 1, b = 0}
    elseif channelGroup == "PARTY_RAID" then
        color = {r = 0, g = 0.5, b = 1}
    elseif channelGroup == "LFG" then
        color = {r = 1, g = 0.5, b = 0}
    end

    if color then
        f.bg:SetColorTexture(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.9)
        f.author:SetTextColor(color.r, color.g, color.b)
    end

    -- 작성자 설정 (서버명 제거)
    local displayAuthor = author or "Unknown"
    displayAuthor = string.gsub(displayAuthor, "%-[^%-]+$", "")
    f.author:SetText(displayAuthor)
    f.currentAuthor = displayAuthor

    -- 메시지 정리 및 설정
    f.message:SetText(self:CleanMessage(message))

    -- 프레임 높이 자동 조절
    local messageHeight = f.message:GetStringHeight()
    local totalHeight = 10 + f.author:GetStringHeight() + 5 + messageHeight + 10
    f:SetHeight(math.max(60, totalHeight))

    -- activeToasts에 추가
    table.insert(activeToasts, f)

    -- 모든 토스트 위치 재정렬
    self:RepositionAll()

    -- 표시
    f:Show()
    f.animIn:Play()
    f.animOut:Play()

    -- 이벤트 발생
    if FoxChat.Events then
        FoxChat.Events:Trigger("FOXCHAT_TOAST_SHOW", author, message, channelGroup)
    end
end

-- 모든 토스트 제거
function Toast:ClearAll()
    for i = #activeToasts, 1, -1 do
        local toast = activeToasts[i]
        if toast.animOut then
            toast.animOut:Stop()
        end
        if toast.animIn then
            toast.animIn:Stop()
        end
        toast:Hide()
        table.insert(toastPool, toast)
    end
    activeToasts = {}
end

-- 설정 위치로 이동
function Toast:UpdatePosition(x, y)
    if FoxChatDB then
        FoxChatDB.toastPosition = FoxChatDB.toastPosition or {}
        FoxChatDB.toastPosition.x = x or 0
        FoxChatDB.toastPosition.y = y or -320
    end
    self:RepositionAll()
end

-- 테스트 토스트 표시
function Toast:ShowTest()
    self:Show("테스트", "이것은 토스트 알림 테스트 메시지입니다.", "GUILD", true)
end