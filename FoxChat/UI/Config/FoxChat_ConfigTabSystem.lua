local addonName, addon = ...

-- 탭 시스템 모듈
FoxChat = FoxChat or {}
FoxChat.UI = FoxChat.UI or {}
FoxChat.UI.TabSystem = {}

local TabSystem = FoxChat.UI.TabSystem
local L = addon.L

-- 탭 관련 변수
TabSystem.tabs = {}
TabSystem.tabContents = {}
TabSystem.currentTab = 1

-- 탭 버튼 생성
function TabSystem:CreateTabButton(parent, text, index)
    local button = CreateFrame("Button", "FoxChatTab"..index, parent)
    button:SetSize(150, 35)

    -- 위치 설정 (가로로 나열)
    local xOffset = 20 + ((index - 1) * 155)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, -50)

    -- 배경 텍스처 (기본 상태)
    button.normalTexture = button:CreateTexture(nil, "BACKGROUND")
    button.normalTexture:SetAllPoints()
    button.normalTexture:SetColorTexture(0.15, 0.15, 0.15, 0.9)

    -- 선택됨 텍스처
    button.selectedTexture = button:CreateTexture(nil, "ARTWORK")
    button.selectedTexture:SetAllPoints()
    button.selectedTexture:SetColorTexture(0.4, 0.35, 0.1, 1)
    button.selectedTexture:Hide()

    -- 하이라이트 텍스처
    button.highlightTexture = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlightTexture:SetAllPoints()
    button.highlightTexture:SetColorTexture(0.3, 0.3, 0.3, 0.5)

    -- 테두리
    button.border = CreateFrame("Frame", nil, button, "BackdropTemplate")
    button.border:SetAllPoints()
    button.border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    button.border:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)

    -- 텍스트
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.text:SetPoint("CENTER")
    button.text:SetText(text)
    button.text:SetTextColor(0.8, 0.8, 0.8)

    -- 탭 인덱스 저장
    button.tabIndex = index
    button.isSelected = false

    -- 클릭 이벤트
    button:SetScript("OnClick", function(self)
        TabSystem:SwitchToTab(self.tabIndex)
    end)

    return button
end

-- 탭 컨텐츠 프레임 생성
function TabSystem:CreateTabContent(parent, index)
    local frame = CreateFrame("Frame", "FoxChatTabContent"..index, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -95)
    frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 55)
    frame:Hide()  -- 기본적으로 숨김

    -- 배경
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0, 0, 0, 0.2)

    return frame
end

-- 탭 전환
function TabSystem:SwitchToTab(index)
    if not self.tabs[index] or not self.tabContents[index] then return end

    self.currentTab = index

    -- 탭 상태 저장
    if FoxChatDB then
        FoxChatDB.lastTab = index
    end

    -- 모든 탭 버튼과 컨텐츠 업데이트
    for i = 1, #self.tabs do
        local tab = self.tabs[i]
        local content = self.tabContents[i]

        if i == index then
            -- 선택된 탭
            tab.isSelected = true
            tab.normalTexture:Hide()
            tab.selectedTexture:Show()
            tab.text:SetTextColor(1, 0.82, 0)  -- 황금색
            tab.border:SetBackdropBorderColor(0.8, 0.65, 0, 1)
            content:Show()
        else
            -- 선택되지 않은 탭
            tab.isSelected = false
            tab.normalTexture:Show()
            tab.selectedTexture:Hide()
            tab.text:SetTextColor(0.8, 0.8, 0.8)  -- 회색
            tab.border:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
            content:Hide()
        end
    end

    -- 탭 변경 이벤트 발생
    if FoxChat.Events then
        FoxChat.Events:Trigger("FOXCHAT_TAB_CHANGED", index)
    end

    -- 특정 탭 콜백 실행
    if self.tabCallbacks and self.tabCallbacks[index] then
        self.tabCallbacks[index]()
    end
end

-- 탭 시스템 초기화
function TabSystem:Initialize(parent, tabData)
    self.tabs = {}
    self.tabContents = {}
    self.tabCallbacks = {}

    for i, data in ipairs(tabData) do
        -- 탭 버튼 생성
        local tabButton = self:CreateTabButton(parent, data.text, i)
        self.tabs[i] = tabButton

        -- 탭 컨텐츠 생성
        local tabContent = self:CreateTabContent(parent, i)
        self.tabContents[i] = tabContent

        -- 콜백 저장
        if data.callback then
            self.tabCallbacks[i] = data.callback
        end

        -- 컨텐츠 초기화 함수 실행
        if data.initialize then
            data.initialize(tabContent)
        end
    end

    -- 첫 번째 탭 선택
    local lastTab = (FoxChatDB and FoxChatDB.lastTab) or 1
    if lastTab > #self.tabs then
        lastTab = 1
    end
    self:SwitchToTab(lastTab)
end

-- 현재 선택된 탭 가져오기
function TabSystem:GetCurrentTab()
    return self.currentTab
end

-- 특정 탭 선택
function TabSystem:SelectTab(index)
    self:SwitchToTab(index)
end

-- 탭 활성화/비활성화
function TabSystem:EnableTab(index, enabled)
    if self.tabs[index] then
        if enabled then
            self.tabs[index]:Enable()
            self.tabs[index].text:SetTextColor(0.8, 0.8, 0.8)
        else
            self.tabs[index]:Disable()
            self.tabs[index].text:SetTextColor(0.4, 0.4, 0.4)
        end
    end
end

-- 탭 표시/숨김
function TabSystem:ShowTab(index, show)
    if self.tabs[index] then
        if show then
            self.tabs[index]:Show()
        else
            self.tabs[index]:Hide()
            -- 숨긴 탭이 현재 선택된 탭이면 다른 탭으로 전환
            if self.currentTab == index then
                for i = 1, #self.tabs do
                    if i ~= index and self.tabs[i]:IsShown() then
                        self:SwitchToTab(i)
                        break
                    end
                end
            end
        end
    end
end

-- 탭 텍스트 업데이트
function TabSystem:SetTabText(index, text)
    if self.tabs[index] then
        self.tabs[index].text:SetText(text)
    end
end

-- 모든 탭 제거
function TabSystem:Clear()
    for i, tab in ipairs(self.tabs) do
        tab:Hide()
        tab:SetParent(nil)
    end
    for i, content in ipairs(self.tabContents) do
        content:Hide()
        content:SetParent(nil)
    end
    self.tabs = {}
    self.tabContents = {}
    self.tabCallbacks = {}
    self.currentTab = 1
end