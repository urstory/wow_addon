local addonName, addon = ...

-- 설정창 메인 프레임 모듈
FoxChat = FoxChat or {}
FoxChat.UI = FoxChat.UI or {}
FoxChat.UI.Config = {}

local Config = FoxChat.UI.Config
local L = addon.L

-- 설정창 프레임
local configFrame = nil

-- 초기화
function Config:Initialize()
    -- 이벤트 등록
    if FoxChat.Events then
        FoxChat.Events:Register("FOXCHAT_CONFIG_SHOW", function()
            self:Show()
        end)

        FoxChat.Events:Register("FOXCHAT_CONFIG_HIDE", function()
            self:Hide()
        end)
    end

    FoxChat:Debug("Config 모듈 초기화 완료")
end

-- 설정창 생성
function Config:CreateFrame()
    if configFrame then return configFrame end

    -- 메인 프레임 생성
    configFrame = CreateFrame("Frame", "FoxChatConfigFrame", UIParent, "BackdropTemplate")
    configFrame:SetSize(700, 620)
    configFrame:SetPoint("CENTER")
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetScript("OnDragStart", configFrame.StartMoving)
    configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)
    configFrame:SetFrameStrata("DIALOG")
    configFrame:SetFrameLevel(999)
    configFrame:SetToplevel(true)

    -- ESC 키로 닫기
    tinsert(UISpecialFrames, "FoxChatConfigFrame")

    -- 배경
    configFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    configFrame:SetBackdropColor(0, 0, 0, 1)

    -- 제목
    local title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    title:SetText("FoxChat " .. L["CONFIG_TITLE"])
    title:SetTextColor(1, 0.82, 0)

    -- 버전 정보
    local version = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    version:SetPoint("TOP", title, "BOTTOM", 0, -3)
    version:SetText("Version " .. (FoxChat.version or "Unknown"))
    version:SetTextColor(0.7, 0.7, 0.7)

    -- 닫기 버튼
    local closeButton = CreateFrame("Button", nil, configFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        Config:Hide()
    end)

    -- 초기화 버튼
    local resetButton = CreateFrame("Button", nil, configFrame, "GameMenuButtonTemplate")
    resetButton:SetSize(100, 25)
    resetButton:SetPoint("BOTTOMLEFT", 20, 20)
    resetButton:SetText(L["RESET_SETTINGS"])
    resetButton:SetScript("OnClick", function()
        Config:ResetSettings()
    end)

    -- 저장 버튼
    local saveButton = CreateFrame("Button", nil, configFrame, "GameMenuButtonTemplate")
    saveButton:SetSize(100, 25)
    saveButton:SetPoint("BOTTOMRIGHT", -130, 20)
    saveButton:SetText(L["SAVE"])
    saveButton:SetScript("OnClick", function()
        Config:SaveSettings()
        Config:Hide()
    end)

    -- 적용 버튼
    local applyButton = CreateFrame("Button", nil, configFrame, "GameMenuButtonTemplate")
    applyButton:SetSize(100, 25)
    applyButton:SetPoint("BOTTOMRIGHT", -20, 20)
    applyButton:SetText(L["APPLY"])
    applyButton:SetScript("OnClick", function()
        Config:SaveSettings()
    end)

    -- 테스트 버튼 (채팅 필터링 탭에서만 표시)
    local testButton = CreateFrame("Button", nil, configFrame, "GameMenuButtonTemplate")
    testButton:SetSize(100, 25)
    testButton:SetPoint("BOTTOM", 0, 20)
    testButton:SetText(L["TEST_HIGHLIGHT"])
    testButton:Hide()
    testButton:SetScript("OnClick", function()
        Config:TestHighlight()
    end)
    configFrame.testButton = testButton

    -- 탭 시스템 초기화
    self:InitializeTabs(configFrame)

    -- SelectTab 메서드 추가 (하위 호환성)
    configFrame.SelectTab = function(self, index)
        if FoxChat.UI.TabSystem then
            FoxChat.UI.TabSystem:SelectTab(index)
        end
    end

    configFrame:Hide()
    return configFrame
end

-- 탭 시스템 초기화
function Config:InitializeTabs(parent)
    if not FoxChat.UI.TabSystem then
        FoxChat:Print("탭 시스템이 로드되지 않았습니다.")
        return
    end

    -- 탭 데이터
    local tabData = {
        {
            text = L["TAB_BASIC"],
            initialize = function(content)
                if FoxChat.UI.Tabs and FoxChat.UI.Tabs.Basic then
                    FoxChat.UI.Tabs.Basic:Initialize(content)
                end
            end,
            callback = function()
                -- 기본 탭에서는 테스트 버튼 표시
                if parent.testButton then
                    parent.testButton:Show()
                end
            end
        },
        {
            text = L["TAB_HIGHLIGHT"],
            initialize = function(content)
                if FoxChat.UI.Tabs and FoxChat.UI.Tabs.Highlight then
                    FoxChat.UI.Tabs.Highlight:Initialize(content)
                end
            end,
            callback = function()
                -- 하이라이트 탭에서는 테스트 버튼 숨김
                if parent.testButton then
                    parent.testButton:Hide()
                end
            end
        },
        {
            text = L["TAB_ADVERTISEMENT"],
            initialize = function(content)
                if FoxChat.UI.Tabs and FoxChat.UI.Tabs.Advertisement then
                    FoxChat.UI.Tabs.Advertisement:Initialize(content)
                end
            end,
            callback = function()
                if parent.testButton then
                    parent.testButton:Hide()
                end
            end
        },
        {
            text = L["TAB_AUTO"],
            initialize = function(content)
                if FoxChat.UI.Tabs and FoxChat.UI.Tabs.Auto then
                    FoxChat.UI.Tabs.Auto:Initialize(content)
                end
            end,
            callback = function()
                if parent.testButton then
                    parent.testButton:Hide()
                end
            end
        }
    }

    -- 탭 시스템 초기화
    FoxChat.UI.TabSystem:Initialize(parent, tabData)
end

-- 설정창 표시
function Config:Show()
    if not configFrame then
        self:CreateFrame()
    end

    if configFrame then
        -- 설정 로드
        self:LoadSettings()

        configFrame:Show()
        configFrame:Raise()

        -- 마지막 탭 복원
        if FoxChat.UI.TabSystem then
            local lastTab = (FoxChatDB and FoxChatDB.lastTab) or 1
            FoxChat.UI.TabSystem:SelectTab(lastTab)
        end

        -- 이벤트 발생
        if FoxChat.Events then
            FoxChat.Events:Trigger("FOXCHAT_CONFIG_OPENED")
        end
    end
end

-- 설정창 숨기기
function Config:Hide()
    if configFrame then
        configFrame:Hide()

        -- 이벤트 발생
        if FoxChat.Events then
            FoxChat.Events:Trigger("FOXCHAT_CONFIG_CLOSED")
        end
    end
end

-- 설정창 토글
function Config:Toggle()
    if configFrame and configFrame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-- 설정 로드
function Config:LoadSettings()
    -- 각 탭에 설정 로드 요청
    if FoxChat.Events then
        FoxChat.Events:Trigger("FOXCHAT_LOAD_SETTINGS")
    end
end

-- 설정 저장
function Config:SaveSettings()
    -- 각 탭에 설정 저장 요청
    if FoxChat.Events then
        FoxChat.Events:Trigger("FOXCHAT_SAVE_SETTINGS")
    end

    -- 저장 완료 메시지
    FoxChat:Print(L["SETTINGS_SAVED"])
end

-- 설정 초기화
function Config:ResetSettings()
    -- 확인 다이얼로그
    StaticPopupDialogs["FOXCHAT_RESET_CONFIRM"] = {
        text = "모든 FoxChat 설정을 초기화하시겠습니까?",
        button1 = "예",
        button2 = "아니오",
        OnAccept = function()
            -- 설정 초기화
            FoxChatDB = nil
            FoxChatCharDB = nil

            -- UI 재로드
            ReloadUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    StaticPopup_Show("FOXCHAT_RESET_CONFIRM")
end

-- 테스트 하이라이트
function Config:TestHighlight()
    if FoxChat.TestHighlight then
        FoxChat:TestHighlight()
    else
        -- 테스트 메시지 출력
        local testMessages = {
            "[공개] [테스트]: 이것은 테스트 메시지입니다.",
            "[길드] [테스트]: 키워드가 포함된 메시지입니다.",
            "[파티] [테스트]: 하이라이트 테스트 중입니다.",
            "[파티찾기] [테스트]: 색상과 스타일을 확인하세요."
        }

        for _, msg in ipairs(testMessages) do
            DEFAULT_CHAT_FRAME:AddMessage(msg)
        end

        -- 토스트 테스트
        if FoxChat.UI and FoxChat.UI.Toast then
            FoxChat.UI.Toast:ShowTest()
        end
    end
end

-- 설정창 프레임 가져오기
function Config:GetFrame()
    return configFrame
end

-- 설정창이 열려있는지 확인
function Config:IsShown()
    return configFrame and configFrame:IsShown()
end