local addonName, addon = ...
local L = addon.L

-- FoxChat 자동 탭 새로운 UI 구현
-- 좌측 메뉴 + 우측 컨텐츠 방식

local function CreateAutoTab(tab4, configFrame, FoxChatDB, CreateTextArea, CreateSeparator)
    -- =============================================
    -- Phase 1: UI 프레임워크 구축
    -- =============================================

    -- 좌측 메뉴 패널 생성
    local leftMenuPanel = CreateFrame("Frame", nil, tab4, "BackdropTemplate")
    leftMenuPanel:SetSize(100, 450)
    leftMenuPanel:SetPoint("TOPLEFT", tab4, "TOPLEFT", 5, -5)
    leftMenuPanel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 1,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })
    leftMenuPanel:SetBackdropColor(0.1, 0.1, 0.1, 0.3)

    -- 우측 컨텐츠 패널 생성
    local rightContentPanel = CreateFrame("Frame", nil, tab4)
    rightContentPanel:SetSize(540, 430)
    rightContentPanel:SetPoint("TOPLEFT", leftMenuPanel, "TOPRIGHT", 5, 0)

    -- 메뉴 데이터 구조
    local menuItems = {
        {id = "trade", name = "거래", selected = true},
        {id = "greet", name = "인사", selected = false},
        {id = "reply", name = "응답", selected = false},
        {id = "roll", name = "주사위", selected = false},
        {id = "chatlog", name = "채팅로그", selected = false}
    }

    -- 메뉴 버튼들과 컨텐츠 프레임 저장
    local menuButtons = {}
    local contentFrames = {}
    local currentMenuId = "trade"

    -- 메뉴 버튼 생성 함수
    local function CreateMenuButton(parent, menuItem, index)
        local button = CreateFrame("Button", nil, parent)
        button:SetSize(96, 30)
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", 2, -10 - (index-1) * 35)

        -- 버튼 텍스트
        local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("CENTER", 0, 0)
        text:SetText(menuItem.name)
        button.text = text

        -- 하이라이트 텍스처
        local highlight = button:CreateTexture(nil, "BACKGROUND")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 1, 1, 0.1)
        highlight:Hide()
        button.highlight = highlight

        -- 선택 텍스처
        local selected = button:CreateTexture(nil, "BACKGROUND")
        selected:SetAllPoints()
        selected:SetColorTexture(0.8, 0.6, 0.2, 0.3)
        selected:Hide()
        button.selected = selected

        -- 호버 효과
        button:SetScript("OnEnter", function(self)
            if currentMenuId ~= menuItem.id then
                self.highlight:Show()
            end
        end)

        button:SetScript("OnLeave", function(self)
            self.highlight:Hide()
        end)

        -- 클릭 이벤트
        button:SetScript("OnClick", function(self)
            -- 모든 버튼 초기화
            for id, btn in pairs(menuButtons) do
                btn.selected:Hide()
                btn.text:SetTextColor(1, 1, 1, 1)
            end

            -- 현재 버튼 선택
            self.selected:Show()
            self.text:SetTextColor(1, 0.82, 0, 1)

            -- 컨텐츠 전환
            for id, frame in pairs(contentFrames) do
                frame:Hide()
            end
            if contentFrames[menuItem.id] then
                contentFrames[menuItem.id]:Show()
            end

            currentMenuId = menuItem.id
        end)

        return button
    end

    -- 메뉴 버튼들 생성
    for i, menuItem in ipairs(menuItems) do
        local button = CreateMenuButton(leftMenuPanel, menuItem, i)
        menuButtons[menuItem.id] = button

        if menuItem.selected then
            button.selected:Show()
            button.text:SetTextColor(1, 0.82, 0, 1)
        end
    end

    -- =============================================
    -- Phase 3: 각 메뉴별 컨텐츠 프레임 생성
    -- =============================================

    -- 1) 거래 컨텐츠 프레임
    local tradeContent = CreateFrame("Frame", nil, rightContentPanel)
    tradeContent:SetAllPoints()
    tradeContent:Show() -- 기본으로 표시
    contentFrames["trade"] = tradeContent

    -- 거래 자동 귓속말 체크박스
    local tradeAutoCheckbox = CreateFrame("CheckButton", nil, tradeContent)
    tradeAutoCheckbox:SetPoint("TOPLEFT", 20, -20)
    tradeAutoCheckbox:SetSize(24, 24)
    tradeAutoCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    tradeAutoCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    tradeAutoCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    tradeAutoCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

    local tradeAutoCheckLabel = tradeContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tradeAutoCheckLabel:SetPoint("LEFT", tradeAutoCheckbox, "RIGHT", 5, 0)
    tradeAutoCheckLabel:SetText("거래 완료 시 자동으로 거래 내역을 귓속말로 전송")

    -- 거래 도움말
    local tradeHelp = tradeContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tradeHelp:SetPoint("TOPLEFT", tradeAutoCheckbox, "BOTTOMLEFT", 5, -10)
    tradeHelp:SetText("거래가 완료되면 거래 상대에게 자동으로 거래 내역을 귓속말로 보냅니다.")
    tradeHelp:SetTextColor(0.7, 0.7, 0.7)
    tradeHelp:SetWordWrap(true)
    tradeHelp:SetWidth(400)

    -- 거래 설정값 로드
    if FoxChatDB and FoxChatDB.tradeAutoWhisper then
        tradeAutoCheckbox:SetChecked(true)
    end

    tradeAutoCheckbox:SetScript("OnClick", function(self)
        FoxChatDB = FoxChatDB or {}
        FoxChatDB.tradeAutoWhisper = self:GetChecked()
    end)

    -- 2) 인사 컨텐츠 프레임
    local greetContent = CreateFrame("Frame", nil, rightContentPanel)
    greetContent:SetAllPoints()
    greetContent:Hide()
    contentFrames["greet"] = greetContent

    -- 파티 자동인사 레이블
    local partyGreetLabel = greetContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    partyGreetLabel:SetPoint("TOPLEFT", 20, -20)
    partyGreetLabel:SetText("파티 자동인사")

    -- 왼쪽 열: 내가 참가할 때
    local myJoinCheckbox = CreateFrame("CheckButton", nil, greetContent)
    myJoinCheckbox:SetPoint("TOPLEFT", partyGreetLabel, "BOTTOMLEFT", 0, -15)
    myJoinCheckbox:SetSize(24, 24)
    myJoinCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    myJoinCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    myJoinCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    myJoinCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

    local myJoinCheckLabel = greetContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    myJoinCheckLabel:SetPoint("LEFT", myJoinCheckbox, "RIGHT", 5, 0)
    myJoinCheckLabel:SetText("내가 파티에 참가할 때 인사")

    -- 내가 참가 메시지 입력창 (너비 축소)
    local myJoinListLabel = greetContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    myJoinListLabel:SetPoint("TOPLEFT", myJoinCheckbox, "BOTTOMLEFT", 25, -10)
    myJoinListLabel:SetText("인사말 (한 줄에 하나씩, 랜덤):")
    myJoinListLabel:SetWidth(240)

    local myJoinBackground, myJoinEditBox = CreateTextArea(greetContent, 240, 75, 0)
    myJoinBackground:SetPoint("TOPLEFT", myJoinListLabel, "BOTTOMLEFT", 0, -5)

    -- 오른쪽 열: 다른 사람이 참가할 때 (위치 조정)
    local othersJoinCheckbox = CreateFrame("CheckButton", nil, greetContent)
    othersJoinCheckbox:SetPoint("TOPLEFT", myJoinCheckbox, "TOPLEFT", 260, 0)  -- 간격 줄임
    othersJoinCheckbox:SetSize(24, 24)
    othersJoinCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    othersJoinCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    othersJoinCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    othersJoinCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

    local othersJoinCheckLabel = greetContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    othersJoinCheckLabel:SetPoint("LEFT", othersJoinCheckbox, "RIGHT", 5, 0)
    othersJoinCheckLabel:SetText("다른 사람이 파티에 참가할 때")

    -- 다른 사람 참가 메시지 입력창 (너비 축소)
    local othersJoinListLabel = greetContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    othersJoinListLabel:SetPoint("TOPLEFT", othersJoinCheckbox, "BOTTOMLEFT", 25, -10)
    othersJoinListLabel:SetText("인사말 ({name}은 참가자 이름):")
    othersJoinListLabel:SetWidth(240)

    local othersJoinBackground, othersJoinEditBox = CreateTextArea(greetContent, 240, 75, 0)
    othersJoinBackground:SetPoint("TOPLEFT", othersJoinListLabel, "BOTTOMLEFT", 0, -5)

    -- =============================================
    -- 리더 전용 인사말 섹션
    -- =============================================

    -- 구분선 추가 (왼쪽 텍스트박스 기준으로 조정)
    local leaderSeparator = CreateSeparator(greetContent)
    leaderSeparator:SetPoint("TOPLEFT", myJoinBackground, "BOTTOMLEFT", -25, -15)
    leaderSeparator:SetPoint("RIGHT", greetContent, "RIGHT", -20, 0)

    -- 리더 전용 섹션 제목
    local leaderTitle = greetContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    leaderTitle:SetPoint("TOPLEFT", leaderSeparator, "BOTTOMLEFT", 0, -10)
    leaderTitle:SetText("리더 전용 인사말 (모든 줄이 순서대로 출력)")
    leaderTitle:SetTextColor(1, 0.8, 0)  -- 금색으로 강조

    -- 파티장 인사말 (전체 너비 사용)
    local partyLeaderLabel = greetContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    partyLeaderLabel:SetPoint("TOPLEFT", leaderTitle, "BOTTOMLEFT", 0, -10)
    partyLeaderLabel:SetText("내가 파티장일 때 다른 사람이 참가하면:")

    local partyLeaderBackground, partyLeaderEditBox = CreateTextArea(greetContent, 500, 75, 0)
    partyLeaderBackground:SetPoint("TOPLEFT", partyLeaderLabel, "BOTTOMLEFT", 0, -5)

    -- 공대장 인사말 (전체 너비 사용)
    local raidLeaderLabel = greetContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    raidLeaderLabel:SetPoint("TOPLEFT", partyLeaderBackground, "BOTTOMLEFT", 0, -10)
    raidLeaderLabel:SetText("내가 공대장일 때 다른 사람이 참가하면:")

    local raidLeaderBackground, raidLeaderEditBox = CreateTextArea(greetContent, 500, 75, 0)
    raidLeaderBackground:SetPoint("TOPLEFT", raidLeaderLabel, "BOTTOMLEFT", 0, -5)

    -- 인사 설정값 로드
    if FoxChatDB then
        myJoinCheckbox:SetChecked(FoxChatDB.autoGreetOnMyJoin)
        othersJoinCheckbox:SetChecked(FoxChatDB.autoGreetOnOthersJoin)
        myJoinEditBox:SetText(FoxChatDB.myJoinMessages or "안녕하세요!\n반갑습니다!")
        othersJoinEditBox:SetText(FoxChatDB.othersJoinMessages or "{name}님 환영합니다!\n{name}님 어서오세요!")
        -- 리더 전용 인사말 로드 (빈 값일 경우에만 예시 표시)
        if FoxChatDB.leaderGreetRaidMessages ~= nil then
            raidLeaderEditBox:SetText(FoxChatDB.leaderGreetRaidMessages)
        else
            raidLeaderEditBox:SetText("{name}님 환영합니다!\n공대장입니다.\n디스코드 참여해주세요!")
        end

        if FoxChatDB.leaderGreetPartyMessages ~= nil then
            partyLeaderEditBox:SetText(FoxChatDB.leaderGreetPartyMessages)
        else
            partyLeaderEditBox:SetText("{name}님 환영합니다!\n파티장입니다.")
        end
    end

    myJoinCheckbox:SetScript("OnClick", function(self)
        FoxChatDB = FoxChatDB or {}
        FoxChatDB.autoGreetOnMyJoin = self:GetChecked()
    end)

    othersJoinCheckbox:SetScript("OnClick", function(self)
        FoxChatDB = FoxChatDB or {}
        FoxChatDB.autoGreetOnOthersJoin = self:GetChecked()
    end)

    myJoinEditBox:SetScript("OnTextChanged", function(self)
        FoxChatDB = FoxChatDB or {}
        FoxChatDB.myJoinMessages = self:GetText()
    end)

    othersJoinEditBox:SetScript("OnTextChanged", function(self)
        FoxChatDB = FoxChatDB or {}
        FoxChatDB.othersJoinMessages = self:GetText()
    end)

    -- 리더 전용 인사말 저장 이벤트
    raidLeaderEditBox:SetScript("OnTextChanged", function(self)
        FoxChatDB = FoxChatDB or {}
        FoxChatDB.leaderGreetRaidMessages = self:GetText() or ""
    end)

    partyLeaderEditBox:SetScript("OnTextChanged", function(self)
        FoxChatDB = FoxChatDB or {}
        FoxChatDB.leaderGreetPartyMessages = self:GetText() or ""
    end)

    -- 3) 응답 컨텐츠 프레임
    local replyContent = CreateFrame("Frame", nil, rightContentPanel)
    replyContent:SetAllPoints()
    replyContent:Hide()
    contentFrames["reply"] = replyContent

    -- AFK/DND 자동응답 레이블
    local autoReplyLabel = replyContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    autoReplyLabel:SetPoint("TOPLEFT", 20, -20)
    autoReplyLabel:SetText("전투/인던 자동응답")

    -- 전투 중 자동응답
    local combatReplyCheckbox = CreateFrame("CheckButton", nil, replyContent)
    combatReplyCheckbox:SetPoint("TOPLEFT", autoReplyLabel, "BOTTOMLEFT", 0, -15)
    combatReplyCheckbox:SetSize(24, 24)
    combatReplyCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    combatReplyCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    combatReplyCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    combatReplyCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

    local combatReplyLabel = replyContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    combatReplyLabel:SetPoint("LEFT", combatReplyCheckbox, "RIGHT", 5, 0)
    combatReplyLabel:SetText("전투 중 자동응답 사용 (파티/공대원 제외)")

    -- 전투 메시지 입력
    local combatMsgLabel = replyContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    combatMsgLabel:SetPoint("TOPLEFT", combatReplyCheckbox, "BOTTOMLEFT", 25, -10)
    combatMsgLabel:SetText("전투 메시지:")

    local combatMsgBg = CreateFrame("Frame", nil, replyContent, "BackdropTemplate")
    combatMsgBg:SetSize(350, 25)
    combatMsgBg:SetPoint("TOPLEFT", combatMsgLabel, "BOTTOMLEFT", 0, -5)
    combatMsgBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    combatMsgBg:SetBackdropColor(0, 0, 0, 0.5)

    local combatMsgEditBox = CreateFrame("EditBox", nil, combatMsgBg)
    combatMsgEditBox:SetPoint("TOPLEFT", 5, -5)
    combatMsgEditBox:SetPoint("BOTTOMRIGHT", -5, 5)
    combatMsgEditBox:SetMultiLine(false)
    combatMsgEditBox:SetAutoFocus(false)
    combatMsgEditBox:SetFontObject("GameFontWhite")
    combatMsgEditBox:SetText(FoxChatDB and FoxChatDB.combatReplyMessage or "[자동응답] 전투 중입니다. 잠시 후 답변드리겠습니다.")

    -- 인던 중 자동응답
    local instanceReplyCheckbox = CreateFrame("CheckButton", nil, replyContent)
    instanceReplyCheckbox:SetPoint("TOPLEFT", combatMsgBg, "BOTTOMLEFT", -25, -15)
    instanceReplyCheckbox:SetSize(24, 24)
    instanceReplyCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    instanceReplyCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    instanceReplyCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    instanceReplyCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

    local instanceReplyLabel = replyContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instanceReplyLabel:SetPoint("LEFT", instanceReplyCheckbox, "RIGHT", 5, 0)
    instanceReplyLabel:SetText("인던 중 자동응답 사용 (파티/공대원 제외)")

    -- 인던 메시지 입력
    local instanceMsgLabel = replyContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instanceMsgLabel:SetPoint("TOPLEFT", instanceReplyCheckbox, "BOTTOMLEFT", 25, -10)
    instanceMsgLabel:SetText("인던 메시지:")

    local instanceMsgBg = CreateFrame("Frame", nil, replyContent, "BackdropTemplate")
    instanceMsgBg:SetSize(350, 25)
    instanceMsgBg:SetPoint("TOPLEFT", instanceMsgLabel, "BOTTOMLEFT", 0, -5)
    instanceMsgBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    instanceMsgBg:SetBackdropColor(0, 0, 0, 0.5)

    local instanceMsgEditBox = CreateFrame("EditBox", nil, instanceMsgBg)
    instanceMsgEditBox:SetPoint("TOPLEFT", 5, -5)
    instanceMsgEditBox:SetPoint("BOTTOMRIGHT", -5, 5)
    instanceMsgEditBox:SetMultiLine(false)
    instanceMsgEditBox:SetAutoFocus(false)
    instanceMsgEditBox:SetFontObject("GameFontWhite")
    instanceMsgEditBox:SetText(FoxChatDB and FoxChatDB.instanceReplyMessage or "[자동응답] 인스턴스 던전 진행 중입니다.")

    -- 쿨다운 설정
    local cooldownLabel = replyContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cooldownLabel:SetPoint("TOPLEFT", instanceMsgBg, "BOTTOMLEFT", -25, -20)
    cooldownLabel:SetText("쿨다운:")

    local cooldownBg = CreateFrame("Frame", nil, replyContent, "BackdropTemplate")
    cooldownBg:SetSize(50, 25)
    cooldownBg:SetPoint("LEFT", cooldownLabel, "RIGHT", 10, 0)
    cooldownBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    cooldownBg:SetBackdropColor(0, 0, 0, 0.5)

    local cooldownEditBox = CreateFrame("EditBox", nil, cooldownBg)
    cooldownEditBox:SetPoint("TOPLEFT", 5, -5)
    cooldownEditBox:SetPoint("BOTTOMRIGHT", -5, 5)
    cooldownEditBox:SetMultiLine(false)
    cooldownEditBox:SetAutoFocus(false)
    cooldownEditBox:SetFontObject("GameFontWhite")
    cooldownEditBox:SetNumeric(true)
    cooldownEditBox:SetMaxLetters(3)
    cooldownEditBox:SetText(FoxChatDB and FoxChatDB.autoReplyCooldown or "5")

    local cooldownMinuteLabel = replyContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cooldownMinuteLabel:SetPoint("LEFT", cooldownBg, "RIGHT", 5, 0)
    cooldownMinuteLabel:SetText("분 (같은 사람에게 재응답 대기시간)")

    -- 응답 도움말
    local autoReplyHelp = replyContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    autoReplyHelp:SetPoint("TOPLEFT", cooldownLabel, "BOTTOMLEFT", 0, -15)
    autoReplyHelp:SetText("• AFK/DND 상태일 때는 항상 자동으로 응답합니다.\n• 전투 중이거나 인스턴스 던전에 있을 때도 개별적으로 자동응답을 설정할 수 있습니다.\n• 전투 중이거나 인던 중일 때는 같은 파티/공대원에게는 자동응답하지 않습니다.\n• 같은 사람에게는 설정된 시간 동안 한 번만 응답합니다.")
    autoReplyHelp:SetTextColor(0.7, 0.7, 0.7)
    autoReplyHelp:SetWordWrap(true)
    autoReplyHelp:SetWidth(450)

    -- 응답 설정값 로드 및 저장
    if FoxChatDB then
        combatReplyCheckbox:SetChecked(FoxChatDB.autoReplyCombat)
        instanceReplyCheckbox:SetChecked(FoxChatDB.autoReplyInstance)
    end

    combatReplyCheckbox:SetScript("OnClick", function(self)
        FoxChatDB = FoxChatDB or {}
        FoxChatDB.autoReplyCombat = self:GetChecked()
    end)

    instanceReplyCheckbox:SetScript("OnClick", function(self)
        FoxChatDB = FoxChatDB or {}
        FoxChatDB.autoReplyInstance = self:GetChecked()
    end)

    combatMsgEditBox:SetScript("OnTextChanged", function(self)
        FoxChatDB = FoxChatDB or {}
        FoxChatDB.combatReplyMessage = self:GetText()
    end)

    instanceMsgEditBox:SetScript("OnTextChanged", function(self)
        FoxChatDB = FoxChatDB or {}
        FoxChatDB.instanceReplyMessage = self:GetText()
    end)

    cooldownEditBox:SetScript("OnTextChanged", function(self)
        FoxChatDB = FoxChatDB or {}
        local value = tonumber(self:GetText()) or 5
        FoxChatDB.autoReplyCooldown = value
    end)

    -- 4) 주사위 컨텐츠 프레임
    local rollContent = CreateFrame("Frame", nil, rightContentPanel)
    rollContent:SetAllPoints()
    rollContent:Hide()
    contentFrames["roll"] = rollContent

    -- 주사위 집계 레이블
    local rollTrackerLabel = rollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rollTrackerLabel:SetPoint("TOPLEFT", 20, -20)
    rollTrackerLabel:SetText("주사위 자동 집계")

    -- 주사위 집계 활성화
    local rollTrackerEnabledCheckbox = CreateFrame("CheckButton", nil, rollContent)
    rollTrackerEnabledCheckbox:SetPoint("TOPLEFT", rollTrackerLabel, "BOTTOMLEFT", 0, -15)
    rollTrackerEnabledCheckbox:SetSize(24, 24)
    rollTrackerEnabledCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    rollTrackerEnabledCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    rollTrackerEnabledCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    rollTrackerEnabledCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

    local rollTrackerEnabledLabel = rollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rollTrackerEnabledLabel:SetPoint("LEFT", rollTrackerEnabledCheckbox, "RIGHT", 5, 0)
    rollTrackerEnabledLabel:SetText("파티/공대 주사위 자동 집계 사용")

    -- 집계 시간 설정
    local rollWindowLabel = rollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rollWindowLabel:SetPoint("TOPLEFT", rollTrackerEnabledCheckbox, "BOTTOMLEFT", 25, -15)
    rollWindowLabel:SetText("집계 시간:")

    local rollWindowDropdown = CreateFrame("Frame", "FoxChatRollWindowDropdown", rollContent, "UIDropDownMenuTemplate")
    rollWindowDropdown:SetPoint("LEFT", rollWindowLabel, "RIGHT", -10, -2)
    UIDropDownMenu_SetWidth(rollWindowDropdown, 60)

    local function InitializeRollWindowDropdown(self)
        local times = {10, 15, 20, 30, 45, 60}

        for _, time in ipairs(times) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = time .. "초"
            info.value = time
            info.func = function()
                UIDropDownMenu_SetSelectedValue(rollWindowDropdown, time)
                FoxChatDB = FoxChatDB or {}
                FoxChatDB.rollWindow = time
            end
            UIDropDownMenu_AddButton(info)
        end
    end

    UIDropDownMenu_Initialize(rollWindowDropdown, InitializeRollWindowDropdown)
    UIDropDownMenu_SetSelectedValue(rollWindowDropdown, FoxChatDB and FoxChatDB.rollWindow or 10)

    -- 출력 채널 설정
    local rollChannelLabel = rollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rollChannelLabel:SetPoint("TOPLEFT", rollWindowLabel, "BOTTOMLEFT", 0, -15)
    rollChannelLabel:SetText("출력 채널:")

    local rollChannelDropdown = CreateFrame("Frame", "FoxChatRollChannelDropdown2", rollContent, "UIDropDownMenuTemplate")
    rollChannelDropdown:SetPoint("LEFT", rollChannelLabel, "RIGHT", 0, 0)
    UIDropDownMenu_SetWidth(rollChannelDropdown, 100)

    local function InitializeRollChannelDropdown(self)
        local channels = {
            {text = "파티/공대", value = "GROUP"},
            {text = "나에게만", value = "SELF"}
        }

        for _, channel in ipairs(channels) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = channel.text
            info.value = channel.value
            info.func = function()
                UIDropDownMenu_SetSelectedValue(rollChannelDropdown, channel.value)
                FoxChatDB = FoxChatDB or {}
                FoxChatDB.rollOutputChannel = channel.value
            end
            UIDropDownMenu_AddButton(info)
        end
    end

    UIDropDownMenu_Initialize(rollChannelDropdown, InitializeRollChannelDropdown)
    UIDropDownMenu_SetSelectedValue(rollChannelDropdown, FoxChatDB and FoxChatDB.rollOutputChannel or "SELF")

    -- 상위 N명 설정
    local rollTopKLabel = rollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rollTopKLabel:SetPoint("TOPLEFT", rollChannelLabel, "BOTTOMLEFT", 0, -15)
    rollTopKLabel:SetText("상위")

    local rollTopKBg = CreateFrame("Frame", nil, rollContent, "BackdropTemplate")
    rollTopKBg:SetSize(40, 25)
    rollTopKBg:SetPoint("LEFT", rollTopKLabel, "RIGHT", 5, 0)
    rollTopKBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    rollTopKBg:SetBackdropColor(0, 0, 0, 0.5)

    local rollTopKEditBox = CreateFrame("EditBox", nil, rollTopKBg)
    rollTopKEditBox:SetPoint("TOPLEFT", 5, -5)
    rollTopKEditBox:SetPoint("BOTTOMRIGHT", -5, 5)
    rollTopKEditBox:SetMultiLine(false)
    rollTopKEditBox:SetAutoFocus(false)
    rollTopKEditBox:SetFontObject("GameFontWhite")
    rollTopKEditBox:SetNumeric(true)
    rollTopKEditBox:SetMaxLetters(2)
    rollTopKEditBox:SetText(FoxChatDB and FoxChatDB.rollTopK or "1")

    local rollTopKHelp = rollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rollTopKHelp:SetPoint("LEFT", rollTopKBg, "RIGHT", 5, 0)
    rollTopKHelp:SetText("명만 표시 (0 = 전체)")

    -- 주사위 도움말
    local rollTrackerHelp = rollContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rollTrackerHelp:SetPoint("TOPLEFT", rollTopKLabel, "BOTTOMLEFT", 0, -20)
    rollTrackerHelp:SetText("• 파티원이 주사위를 굴리면 자동으로 집계합니다.\n• 설정된 시간이 지나면 결과를 선택한 채널에 출력합니다.\n• 상위 N명 설정으로 우승자만 표시하거나 상위권을 표시할 수 있습니다.")
    rollTrackerHelp:SetTextColor(0.7, 0.7, 0.7)
    rollTrackerHelp:SetWordWrap(true)
    rollTrackerHelp:SetWidth(450)

    -- 주사위 설정값 로드 및 저장
    if FoxChatDB then
        rollTrackerEnabledCheckbox:SetChecked(FoxChatDB.rollTrackerEnabled)
    end

    rollTrackerEnabledCheckbox:SetScript("OnClick", function(self)
        FoxChatDB = FoxChatDB or {}
        FoxChatDB.rollTrackerEnabled = self:GetChecked()
    end)


    rollTopKEditBox:SetScript("OnTextChanged", function(self)
        FoxChatDB = FoxChatDB or {}
        local value = tonumber(self:GetText()) or 1
        FoxChatDB.rollTopK = value
    end)

    -- =============================================
    -- 5) 채팅로그 컨텐츠 프레임
    -- =============================================
    local chatlogContent = CreateFrame("Frame", nil, rightContentPanel)
    chatlogContent:SetAllPoints()
    chatlogContent:Hide()
    contentFrames["chatlog"] = chatlogContent

    -- 로거 인스턴스 가져오기
    local Logger = addon.FoxChatLogger
    if not Logger then
        local errorLabel = chatlogContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        errorLabel:SetPoint("CENTER", 0, 0)
        errorLabel:SetText("채팅로그 시스템을 불러올 수 없습니다")
        return menuButtons, contentFrames
    end

    -- 설정 패널
    local settingsPanel = CreateFrame("Frame", nil, chatlogContent, "BackdropTemplate")
    settingsPanel:SetSize(540, 120)
    settingsPanel:SetPoint("TOPLEFT", 0, 0)
    settingsPanel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 1,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })
    settingsPanel:SetBackdropColor(0.1, 0.1, 0.1, 0.3)

    -- 설정 타이틀
    local settingsTitle = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    settingsTitle:SetPoint("TOPLEFT", 10, -10)
    settingsTitle:SetText("채팅로그 설정")

    -- 로그 활성화 체크박스
    local enabledCheckbox = CreateFrame("CheckButton", nil, settingsPanel)
    enabledCheckbox:SetPoint("TOPLEFT", settingsTitle, "BOTTOMLEFT", 0, -10)
    enabledCheckbox:SetSize(24, 24)
    enabledCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    enabledCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    enabledCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    enabledCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

    local enabledLabel = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enabledLabel:SetPoint("LEFT", enabledCheckbox, "RIGHT", 5, 0)
    enabledLabel:SetText("채팅로그 기록 활성화")

    -- 채널 선택 (가로 배치)
    local channelLabel = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    channelLabel:SetPoint("TOPLEFT", enabledCheckbox, "BOTTOMLEFT", 0, -10)
    channelLabel:SetText("기록할 채널:")

    local channelCheckboxes = {}
    local channels = {
        {key = "WHISPER", label = "귓속말"},
        {key = "PARTY", label = "파티"},
        {key = "RAID", label = "공대"},
        {key = "GUILD", label = "길드"},
    }

    local xOffset = 100
    for i, channel in ipairs(channels) do
        local cb = CreateFrame("CheckButton", nil, settingsPanel)
        cb:SetPoint("TOPLEFT", channelLabel, "TOPRIGHT", xOffset * (i-1) + 10, 0)
        cb:SetSize(20, 20)
        cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
        cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

        local label = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        label:SetText(channel.label)

        channelCheckboxes[channel.key] = cb

        -- 이벤트 핸들러
        cb:SetScript("OnClick", function(self)
            FoxChatDB.chatLogConfig.channels[channel.key] = self:GetChecked()
        end)
    end

    -- 보관 기간 설정
    local retentionLabel = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    retentionLabel:SetPoint("TOPLEFT", channelLabel, "BOTTOMLEFT", 0, -10)
    retentionLabel:SetText("로그 보관 기간:")

    local retentionDropdown = CreateFrame("Frame", "FoxChatLogRetentionDropdown", settingsPanel, "UIDropDownMenuTemplate")
    retentionDropdown:SetPoint("LEFT", retentionLabel, "RIGHT", -10, -2)
    UIDropDownMenu_SetWidth(retentionDropdown, 80)

    local function InitializeRetentionDropdown(self)
        local days = {3, 7, 14, 30}
        for _, day in ipairs(days) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = day .. "일"
            info.value = day
            info.func = function()
                UIDropDownMenu_SetSelectedValue(retentionDropdown, day)
                UIDropDownMenu_SetText(retentionDropdown, day .. "일")
                FoxChatDB.chatLogConfig.retentionDays = day
            end
            UIDropDownMenu_AddButton(info)
        end
    end

    UIDropDownMenu_Initialize(retentionDropdown, InitializeRetentionDropdown)

    -- 설정 로드
    local function LoadSettings()
        if FoxChatDB and FoxChatDB.chatLogConfig then
            enabledCheckbox:SetChecked(FoxChatDB.chatLogConfig.enabled)

            for key, cb in pairs(channelCheckboxes) do
                cb:SetChecked(FoxChatDB.chatLogConfig.channels[key])
            end

            local retentionDays = FoxChatDB.chatLogConfig.retentionDays or 7
            UIDropDownMenu_SetSelectedValue(retentionDropdown, retentionDays)
            UIDropDownMenu_SetText(retentionDropdown, retentionDays .. "일")
        end
    end

    -- 활성화 체크박스 이벤트
    enabledCheckbox:SetScript("OnClick", function(self)
        FoxChatDB.chatLogConfig.enabled = self:GetChecked()
        if self:GetChecked() then
            Logger:Enable()
        else
            Logger:Disable()
        end
    end)

    -- 설정 초기 로드
    C_Timer.After(0.1, LoadSettings)

    -- 구분선
    local settingsSeparator = settingsPanel:CreateTexture(nil, "BACKGROUND")
    settingsSeparator:SetHeight(1)
    settingsSeparator:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    settingsSeparator:SetPoint("BOTTOMLEFT", settingsPanel, "BOTTOMLEFT", 5, 5)
    settingsSeparator:SetPoint("BOTTOMRIGHT", settingsPanel, "BOTTOMRIGHT", -5, 5)

    -- 상단 컨트롤 패널
    local controlPanel = CreateFrame("Frame", nil, chatlogContent)
    controlPanel:SetSize(540, 35)
    controlPanel:SetPoint("TOPLEFT", settingsPanel, "BOTTOMLEFT", 0, -5)

    -- 날짜 레이블
    local dateLabel = controlPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    dateLabel:SetPoint("LEFT", 10, 0)
    dateLabel:SetText(date("%Y-%m-%d"))

    -- 이전 날짜 버튼
    local prevButton = CreateFrame("Button", nil, controlPanel, "UIPanelButtonTemplate")
    prevButton:SetSize(60, 22)
    prevButton:SetPoint("LEFT", dateLabel, "RIGHT", 10, 0)
    prevButton:SetText("이전")

    -- 다음 날짜 버튼
    local nextButton = CreateFrame("Button", nil, controlPanel, "UIPanelButtonTemplate")
    nextButton:SetSize(60, 22)
    nextButton:SetPoint("LEFT", prevButton, "RIGHT", 5, 0)
    nextButton:SetText("다음")

    -- 오늘 버튼
    local todayButton = CreateFrame("Button", nil, controlPanel, "UIPanelButtonTemplate")
    todayButton:SetSize(60, 22)
    todayButton:SetPoint("LEFT", nextButton, "RIGHT", 5, 0)
    todayButton:SetText("오늘")

    -- 날짜 선택 버튼
    local datePickerButton = CreateFrame("Button", nil, controlPanel, "UIPanelButtonTemplate")
    datePickerButton:SetSize(80, 22)
    datePickerButton:SetPoint("LEFT", todayButton, "RIGHT", 5, 0)
    datePickerButton:SetText("날짜선택")

    -- 내보내기 버튼
    local exportButton = CreateFrame("Button", nil, controlPanel, "UIPanelButtonTemplate")
    exportButton:SetSize(70, 22)
    exportButton:SetPoint("RIGHT", -85, 0)
    exportButton:SetText("내보내기")

    -- 새로고침 버튼
    local refreshButton = CreateFrame("Button", nil, controlPanel, "UIPanelButtonTemplate")
    refreshButton:SetSize(70, 22)
    refreshButton:SetPoint("RIGHT", -10, 0)
    refreshButton:SetText("새로고침")

    -- 구분선
    local separator = controlPanel:CreateTexture(nil, "BACKGROUND")
    separator:SetHeight(1)
    separator:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    separator:SetPoint("TOPLEFT", controlPanel, "BOTTOMLEFT", 0, -2)
    separator:SetPoint("TOPRIGHT", controlPanel, "BOTTOMRIGHT", 0, -2)

    -- 검색 패널을 먼저 생성 (messageFrame이 참조하기 때문)
    local searchPanel = CreateFrame("Frame", nil, chatlogContent)
    searchPanel:SetSize(540, 30)
    searchPanel:SetPoint("TOPLEFT", controlPanel, "BOTTOMLEFT", 0, -5)

    -- 메시지 표시 영역 (에디터창 스타일)
    local messageAreaBg, messageEditBox = CreateTextArea(chatlogContent, 540, 280, 0)
    messageAreaBg:SetPoint("TOPLEFT", searchPanel, "BOTTOMLEFT", 0, -5)

    -- 에디터창을 읽기 전용으로 설정
    messageEditBox:EnableMouse(true)
    messageEditBox:EnableKeyboard(false)
    messageEditBox:SetScript("OnEditFocusGained", function(self) self:ClearFocus() end)
    messageEditBox:SetTextColor(0.9, 0.9, 0.9)

    -- 전방 선언
    local UpdateMessageDisplay
    local channelFilterDropdown
    local selectedChannelFilter = "ALL"
    local searchBox
    local searchResultLabel
    local isSearchActive = false  -- 검색 활성화 상태
    local allMessages = {}  -- 원본 메시지 리스트
    local currentMessages = {}  -- 현재 표시 중인 메시지 리스트
    local selectedMessageIndex = nil  -- 선택된 메시지 인덱스

    -- 메시지 더블클릭 시 컨텍스트 팝업 표시
    messageEditBox:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and isSearchActive then
            -- 더블클릭 감지를 위한 간단한 처리
            local cursorPos = self:GetCursorPosition()
            local text = self:GetText()
            local lineStart, lineEnd = 1, 1
            local lineNum = 1

            -- 커서 위치에 해당하는 라인 찾기
            for i = 1, #text do
                if i == cursorPos then
                    break
                end
                if text:sub(i, i) == "\n" then
                    lineNum = lineNum + 1
                    lineStart = i + 1
                end
            end

            -- 해당 라인의 메시지 인덱스 찾기
            if currentMessages[lineNum] and currentMessages[lineNum].originalIndex then
                local originalIndex = currentMessages[lineNum].originalIndex

                -- 컨텍스트 팝업 생성
                local contextPopup = CreateFrame("Frame", "FoxChatContextPopup", UIParent, "BackdropTemplate")
                contextPopup:SetSize(500, 200)
                contextPopup:SetPoint("CENTER")
                contextPopup:SetBackdrop({
                    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                    edgeSize = 16,
                    insets = {left = 4, right = 4, top = 4, bottom = 4}
                })
                contextPopup:SetFrameStrata("FULLSCREEN_DIALOG")
                contextPopup:SetFrameLevel(1000)
                contextPopup:EnableMouse(true)
                contextPopup:SetMovable(true)
                contextPopup:RegisterForDrag("LeftButton")
                contextPopup:SetScript("OnDragStart", contextPopup.StartMoving)
                contextPopup:SetScript("OnDragStop", contextPopup.StopMovingOrSizing)

                -- 타이틀
                local title = contextPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                title:SetPoint("TOP", 0, -10)
                title:SetText("메시지 컨텍스트")

                -- 닫기 버튼
                local closeButton = CreateFrame("Button", nil, contextPopup, "UIPanelCloseButton")
                closeButton:SetPoint("TOPRIGHT", -5, -5)

                -- 텍스트 영역
                local textAreaBg, textAreaEditBox = CreateTextArea(contextPopup, 470, 150, 0)
                textAreaBg:SetPoint("TOP", title, "BOTTOM", 0, -10)

                -- 에디터창을 읽기 전용으로 설정
                textAreaEditBox:EnableKeyboard(false)
                textAreaEditBox:SetScript("OnEditFocusGained", function(self) self:ClearFocus() end)

                -- 컨텍스트 메시지 구성 (앞뒤 3줄)
                local contextLines = {}
                local startIdx = math.max(1, originalIndex - 3)
                local endIdx = math.min(#allMessages, originalIndex + 3)

                for i = startIdx, endIdx do
                    local msg = allMessages[i]
                    local timeStr = date("[%H:%M:%S]", msg.ts)
                    local channelName = Logger:GetChannelName(msg.ch)
                    local sender = msg.s or ""
                    local message = msg.m or ""

                    local line
                    if msg.o == 1 then
                        -- 발신 귀속말
                        line = string.format("%s[%s] 나→%s: %s",
                            timeStr, channelName, msg.t or "", message)
                    elseif msg.t then
                        -- 수신 귀속말
                        line = string.format("%s[%s] %s→나: %s",
                            timeStr, channelName, sender, message)
                    else
                        -- 일반 메시지
                        line = string.format("%s[%s] %s: %s",
                            timeStr, channelName, sender, message)
                    end

                    -- 현재 선택된 메시지는 하이라이트
                    if i == originalIndex then
                        line = "|cFFFFFF00>>> " .. line .. " <<<|r"
                    end

                    table.insert(contextLines, line)
                end

                textAreaEditBox:SetText(table.concat(contextLines, "\n"))
                contextPopup:Show()
            end
        end
    end)

    -- 데이터 관련 변수들
    local currentDate = date("%Y%m%d")
    local scrollOffset = 0

    -- 채널 색상 정의
    local channelColors = {
        W = {0.9, 0.5, 0.9},     -- 귓속말 (분홍)
        P = {0.6, 0.7, 1.0},     -- 파티 (파랑)
        R = {1.0, 0.5, 0.0},     -- 공대 (주황)
        G = {0.25, 1.0, 0.25},   -- 길드 (초록)
        Y = {1.0, 0.7, 0.7},     -- 외침 (밝은 빨강)
        S = {1.0, 1.0, 1.0},     -- 일반 (흰색)
    }

    -- 메시지 업데이트 함수 정의
    UpdateMessageDisplay = function()
        local displayText = {}

        for i, msg in ipairs(currentMessages) do
            local timeStr = date("[%H:%M:%S]", msg.ts)
            local channelName = Logger:GetChannelName(msg.ch)
            local sender = msg.s or ""
            local message = msg.m or ""
            local target = msg.t or ""

            -- 세션 구분
            if msg.sessionStart then
                table.insert(displayText, "\n|cFFFFFF00===== 새 세션 =====|r\n")
            end

            local line
            -- 채널 색상 적용
            local channelColor
            if msg.ch == "W" then
                channelColor = "FFE59FF6"  -- 귓속말 (분홍)
            elseif msg.ch == "P" then
                channelColor = "FF99B3FF"  -- 파티 (파랑)
            elseif msg.ch == "R" then
                channelColor = "FFFF8000"  -- 공대 (주황)
            elseif msg.ch == "G" then
                channelColor = "FF40FF40"  -- 길드 (초록)
            else
                channelColor = "FFFFFFFF"  -- 기타 (흰색)
            end

            if msg.o == 1 then
                -- 발신 귓속말
                line = string.format("|cFF999999%s|r |c%s[%s]|r |cFFFFD700나→%s:|r %s",
                    timeStr, channelColor, channelName, target, message)
            elseif msg.t then
                -- 수신 귓속말
                line = string.format("|cFF999999%s|r |c%s[%s]|r |cFF87CEEB%s→나:|r %s",
                    timeStr, channelColor, channelName, sender, message)
            else
                -- 일반 메시지
                line = string.format("|cFF999999%s|r |c%s[%s]|r |cFFE0E0E0%s:|r %s",
                    timeStr, channelColor, channelName, sender, message)
            end

            table.insert(displayText, line)
        end

        messageEditBox:SetText(table.concat(displayText, "\n"))
    end

    -- 날짜별 메시지 로드 함수
    local function LoadMessagesForDate(dateKey)
        currentDate = dateKey
        dateLabel:SetText(string.format("%s-%s-%s",
            string.sub(dateKey, 1, 4),
            string.sub(dateKey, 5, 6),
            string.sub(dateKey, 7, 8)))

        allMessages = Logger:GetMessagesForDate(dateKey) or {}
        currentMessages = allMessages
        isSearchActive = false

        -- 세션 구분 처리 및 원본 인덱스 추가
        local lastTime = 0
        for i, msg in ipairs(currentMessages) do
            msg.originalIndex = i  -- 원본 인덱스 저장
            if lastTime > 0 and (msg.ts - lastTime) > 1800 then
                msg.sessionStart = true
            end
            lastTime = msg.ts
        end

        UpdateMessageDisplay()
    end

    -- 날짜 네비게이션 함수들
    local function NavigateToPrevDay()
        local year = tonumber(string.sub(currentDate, 1, 4))
        local month = tonumber(string.sub(currentDate, 5, 6))
        local day = tonumber(string.sub(currentDate, 7, 8))

        local time = time({year = year, month = month, day = day})
        time = time - 86400
        local newDate = date("%Y%m%d", time)

        LoadMessagesForDate(newDate)
    end

    local function NavigateToNextDay()
        local year = tonumber(string.sub(currentDate, 1, 4))
        local month = tonumber(string.sub(currentDate, 5, 6))
        local day = tonumber(string.sub(currentDate, 7, 8))

        local time = time({year = year, month = month, day = day})
        time = time + 86400
        local newDate = date("%Y%m%d", time)

        LoadMessagesForDate(newDate)
    end

    local function NavigateToToday()
        local today = date("%Y%m%d")
        LoadMessagesForDate(today)
    end

    -- 내보내기 기능
    local function ExportCurrentDate()
        local exportText = {}
        table.insert(exportText, string.format("=== FoxChat 채팅로그 - %s ===\n",
            string.format("%s-%s-%s",
                string.sub(currentDate, 1, 4),
                string.sub(currentDate, 5, 6),
                string.sub(currentDate, 7, 8))))

        for i, msg in ipairs(currentMessages) do
            local timeStr = date("%H:%M:%S", msg.ts)
            local channelName = Logger:GetChannelName(msg.ch)
            local sender = msg.s or ""

            if msg.sessionStart then
                table.insert(exportText, string.format("\n===== 새 세션: %s =====\n", date("%H:%M", msg.ts)))
            end

            if msg.o == 1 then
                -- 발신 귓속말
                table.insert(exportText, string.format("[%s][%s] 나→%s: %s",
                    timeStr, channelName, msg.t or "", msg.m or ""))
            elseif msg.t then
                -- 수신 귓속말
                table.insert(exportText, string.format("[%s][%s] %s→나: %s",
                    timeStr, channelName, sender, msg.m or ""))
            else
                -- 일반 메시지
                table.insert(exportText, string.format("[%s][%s] %s: %s",
                    timeStr, channelName, sender, msg.m or ""))
            end
        end

        -- 내보내기 다이얼로그 생성
        local exportDialog = CreateFrame("Frame", "FoxChatExportDialog", UIParent, "BackdropTemplate")
        exportDialog:SetSize(500, 400)
        exportDialog:SetPoint("CENTER")
        exportDialog:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 16,
            insets = {left = 4, right = 4, top = 4, bottom = 4}
        })
        exportDialog:SetFrameStrata("FULLSCREEN_DIALOG")  -- 최상위 레이어로 변경
        exportDialog:SetFrameLevel(1000)  -- 높은 프레임 레벨 설정
        exportDialog:EnableMouse(true)
        exportDialog:SetMovable(true)
        exportDialog:RegisterForDrag("LeftButton")
        exportDialog:SetScript("OnDragStart", exportDialog.StartMoving)
        exportDialog:SetScript("OnDragStop", exportDialog.StopMovingOrSizing)

        -- 타이틀
        local title = exportDialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -10)
        title:SetText("채팅로그 내보내기")

        -- 설명
        local desc = exportDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        desc:SetPoint("TOP", title, "BOTTOM", 0, -5)
        desc:SetText("Ctrl+A로 전체 선택, Ctrl+C로 복사")

        -- CreateTextArea를 사용하여 텍스트 영역 생성
        local textAreaBg, textAreaEditBox = CreateTextArea(exportDialog, 470, 320, 0)
        textAreaBg:SetPoint("TOP", desc, "BOTTOM", 0, -10)

        -- 내용 설정 및 스타일 설정
        textAreaEditBox:SetText(table.concat(exportText, "\n"))
        textAreaEditBox:SetScript("OnEscapePressed", function() exportDialog:Hide() end)

        -- 닫기 버튼
        local closeButton = CreateFrame("Button", nil, exportDialog, "UIPanelButtonTemplate")
        closeButton:SetSize(80, 22)
        closeButton:SetPoint("BOTTOM", 0, 10)
        closeButton:SetText("닫기")
        closeButton:SetScript("OnClick", function() exportDialog:Hide() end)

        -- 포커스 설정
        textAreaEditBox:SetFocus()
        textAreaEditBox:HighlightText()

        exportDialog:Show()
    end

    -- 검색 패널 UI 요소 추가
    local searchLabel = searchPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLabel:SetPoint("LEFT", 10, 0)
    searchLabel:SetText("검색:")

    searchBox = CreateFrame("EditBox", nil, searchPanel, "InputBoxTemplate")
    searchBox:SetSize(150, 20)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 10, 0)
    searchBox:SetAutoFocus(false)

    -- 채널 필터 드롭다운
    channelFilterDropdown = CreateFrame("Frame", "FoxChatLogChannelFilter", searchPanel, "UIDropDownMenuTemplate")
    channelFilterDropdown:SetPoint("LEFT", searchBox, "RIGHT", -10, -2)
    UIDropDownMenu_SetWidth(channelFilterDropdown, 70)

    local searchButton = CreateFrame("Button", nil, searchPanel, "UIPanelButtonTemplate")
    searchButton:SetSize(50, 22)
    searchButton:SetPoint("LEFT", channelFilterDropdown, "RIGHT", -10, 2)
    searchButton:SetText("검색")

    local clearButton = CreateFrame("Button", nil, searchPanel, "UIPanelButtonTemplate")
    clearButton:SetSize(60, 22)
    clearButton:SetPoint("LEFT", searchButton, "RIGHT", 5, 0)
    clearButton:SetText("초기화")

    searchResultLabel = searchPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchResultLabel:SetPoint("LEFT", clearButton, "RIGHT", 10, 0)
    searchResultLabel:SetText("")

    -- 채널 필터 초기화
    local function InitializeChannelFilter(self)
        local filterOptions = {
            {text = "전체", value = "ALL"},
            {text = "귓속말", value = "W"},
            {text = "파티", value = "P"},
            {text = "공대", value = "R"},
            {text = "길드", value = "G"},
        }

        for _, option in ipairs(filterOptions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.func = function()
                selectedChannelFilter = option.value
                UIDropDownMenu_SetSelectedValue(channelFilterDropdown, option.value)
                UIDropDownMenu_SetText(channelFilterDropdown, option.text)
            end
            UIDropDownMenu_AddButton(info)
        end
    end

    UIDropDownMenu_Initialize(channelFilterDropdown, InitializeChannelFilter)
    UIDropDownMenu_SetSelectedValue(channelFilterDropdown, "ALL")
    UIDropDownMenu_SetText(channelFilterDropdown, "전체")

    -- 검색 기능
    local searchResults = {}
    local searchKeyword = ""
    local searchInProgress = false
    local searchTimer = nil

    -- 비동기 검색 함수 (프레임 드롭 방지)
    local function SearchAsync(entries, keyword, channelFilter, onProgress, onComplete)
        local i, n, step = 1, #entries, 300  -- 한 번에 300개씩 처리
        local results = {}
        local lowerKeyword = keyword ~= "" and string.lower(keyword) or nil

        local function tick()
            local stop = math.min(i + step - 1, n)
            for k = i, stop do
                local msg = entries[k]

                -- 채널 필터링
                local channelMatch = (channelFilter == "ALL") or (msg.ch == channelFilter)

                -- 키워드 검색
                local keywordMatch = true
                if lowerKeyword then
                    keywordMatch = (msg.m and string.find(string.lower(msg.m), lowerKeyword, 1, true)) or
                                 (msg.s and string.find(string.lower(msg.s), lowerKeyword, 1, true)) or
                                 (msg.t and string.find(string.lower(msg.t), lowerKeyword, 1, true))
                end

                if channelMatch and keywordMatch then
                    table.insert(results, msg)
                end
            end

            if onProgress then
                onProgress(stop / n)  -- 진행률 콜백
            end

            i = stop + 1
            if i <= n then
                searchTimer = C_Timer.After(0.01, tick)  -- 다음 프레임에 계속
            else
                searchInProgress = false
                searchTimer = nil
                if onComplete then
                    onComplete(results)
                end
            end
        end

        searchInProgress = true
        tick()
    end

    local function PerformSearch()
        -- 이전 검색 취소
        if searchTimer then
            searchTimer:Cancel()
            searchTimer = nil
        end

        searchKeyword = searchBox:GetText()
        if searchKeyword == "" and selectedChannelFilter == "ALL" then
            searchInProgress = false
            isSearchActive = false
            currentMessages = allMessages
            searchResultLabel:SetText("")

            UpdateMessageDisplay()
        else
            searchResultLabel:SetText("|cFFFFFF00검색중...|r")
            searchButton:SetEnabled(false)

            SearchAsync(allMessages, searchKeyword, selectedChannelFilter,
                function(progress)
                    -- 진행률 표시
                    searchResultLabel:SetText(string.format("|cFFFFFF00검색중... %d%%|r", math.floor(progress * 100)))
                end,
                function(results)
                    -- 검색 완료
                    searchButton:SetEnabled(true)
                    isSearchActive = true
                    currentMessages = results
                    searchResultLabel:SetText(string.format("검색결과: %d개", #results))

                    -- 세션 구분 재처리
                    local lastTime = 0
                    for i, msg in ipairs(currentMessages) do
                        if lastTime > 0 and (msg.ts - lastTime) > 1800 then
                            msg.sessionStart = true
                        else
                            msg.sessionStart = nil
                        end
                        lastTime = msg.ts
                    end

                    UpdateMessageDisplay()
                end
            )
        end
    end

    local function ClearSearch()
        -- 검색 취소
        if searchTimer then
            searchTimer:Cancel()
            searchTimer = nil
        end
        searchInProgress = false
        isSearchActive = false

        searchBox:SetText("")
        searchResultLabel:SetText("")
        selectedChannelFilter = "ALL"
        UIDropDownMenu_SetSelectedValue(channelFilterDropdown, "ALL")
        UIDropDownMenu_SetText(channelFilterDropdown, "전체")

        currentMessages = allMessages

        UpdateMessageDisplay()
    end

    searchButton:SetScript("OnClick", PerformSearch)
    clearButton:SetScript("OnClick", ClearSearch)
    searchBox:SetScript("OnEnterPressed", PerformSearch)

    -- 날짜 선택 팝업
    local datePicker = nil
    local function ShowDatePicker()
        if not datePicker then
            datePicker = CreateFrame("Frame", "FoxChatDatePicker", UIParent, "BackdropTemplate")
            datePicker:SetSize(200, 250)
            datePicker:SetPoint("CENTER")
            datePicker:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                edgeSize = 16,
                insets = {left = 4, right = 4, top = 4, bottom = 4}
            })
            datePicker:SetFrameStrata("FULLSCREEN_DIALOG")
            datePicker:SetFrameLevel(1000)
            datePicker:EnableMouse(true)
            datePicker:SetMovable(true)
            datePicker:RegisterForDrag("LeftButton")
            datePicker:SetScript("OnDragStart", datePicker.StartMoving)
            datePicker:SetScript("OnDragStop", datePicker.StopMovingOrSizing)

            -- 타이틀
            local title = datePicker:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            title:SetPoint("TOP", 0, -10)
            title:SetText("날짜 선택")

            -- 닫기 버튼
            local closeButton = CreateFrame("Button", nil, datePicker, "UIPanelCloseButton")
            closeButton:SetPoint("TOPRIGHT", -5, -5)

            -- 스크롤 프레임
            local scrollFrame = CreateFrame("ScrollFrame", nil, datePicker, "UIPanelScrollFrameTemplate")
            scrollFrame:SetPoint("TOPLEFT", 10, -35)
            scrollFrame:SetPoint("BOTTOMRIGHT", -30, 35)

            -- 콘텐츠 프레임
            local content = CreateFrame("Frame", nil, scrollFrame)
            content:SetSize(150, 20)
            scrollFrame:SetScrollChild(content)

            -- 날짜 목록 표시
            local function PopulateDates()
                local dates = Logger:GetAvailableDates()
                local yOffset = 0

                for _, dateKey in ipairs(dates) do
                    local button = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
                    button:SetSize(140, 22)
                    button:SetPoint("TOP", 0, yOffset)
                    button:SetText(string.format("%s-%s-%s",
                        string.sub(dateKey, 1, 4),
                        string.sub(dateKey, 5, 6),
                        string.sub(dateKey, 7, 8)))
                    button:SetScript("OnClick", function()
                        LoadMessagesForDate(dateKey)
                        datePicker:Hide()
                    end)

                    yOffset = yOffset - 25
                end

                content:SetHeight(math.abs(yOffset) + 20)
            end

            datePicker.PopulateDates = PopulateDates

            -- 취소 버튼
            local cancelButton = CreateFrame("Button", nil, datePicker, "UIPanelButtonTemplate")
            cancelButton:SetSize(80, 22)
            cancelButton:SetPoint("BOTTOM", 0, 10)
            cancelButton:SetText("취소")
            cancelButton:SetScript("OnClick", function()
                datePicker:Hide()
            end)
        end

        datePicker.PopulateDates()
        datePicker:Show()
    end

    -- 이벤트 핸들러 연결
    prevButton:SetScript("OnClick", NavigateToPrevDay)
    nextButton:SetScript("OnClick", NavigateToNextDay)
    todayButton:SetScript("OnClick", NavigateToToday)
    datePickerButton:SetScript("OnClick", ShowDatePicker)
    exportButton:SetScript("OnClick", ExportCurrentDate)
    refreshButton:SetScript("OnClick", function()
        LoadMessagesForDate(currentDate)
    end)


    -- 초기 로드
    LoadMessagesForDate(date("%Y%m%d"))

    return menuButtons, contentFrames
end

local configFrame = nil
local currentTab = 1  -- 현재 선택된 탭

-- 탭 시스템 변수
local tabs = {}
local tabContents = {}

-- EditBox 변수들 (각 탭에서 사용)
local keywordsEditBox = nil
local ignoreKeywordsEditBox = nil
-- 말머리/말꼬리 입력 필드 (이제 채널별로 관리됨)
local channelPrefixEditBoxes = {}
local suffixEditBox = nil
local adMessageEditBox = nil

-- 재사용 가능한 TextArea 생성 함수 (안정적인 버전)
local function CreateTextArea(parent, width, height, maxLetters)
    -- 배경 프레임
    local bg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bg:SetSize(width, height)
    bg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    bg:SetBackdropColor(0, 0, 0, 0.8)

    -- ScrollFrame 생성
    local scrollFrame = CreateFrame("ScrollFrame", nil, bg, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 8)

    -- EditBox 생성
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontHighlight)
    editBox:SetWidth(scrollFrame:GetWidth() - 5)
    editBox:SetHeight(2000)  -- 충분히 큰 고정 높이
    editBox:SetMaxLetters(maxLetters or 0)
    editBox:SetTextInsets(5, 5, 5, 25)  -- 하단 여백을 25로 증가

    -- 줄 간격 조정 (커서 위치 문제 해결)
    editBox:SetSpacing(0)  -- 줄 간격을 0으로 설정

    -- ScrollChild로 설정
    scrollFrame:SetScrollChild(editBox)

    -- ESC 키로 포커스 해제
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    -- 커서 위치 변경 시 자동 스크롤 (안전한 버전)
    editBox.isScrolling = false
    editBox:SetScript("OnCursorChanged", function(self, x, y, w, h)
        if self.isScrolling then return end  -- 재귀 방지

        local scrollOffset = scrollFrame:GetVerticalScroll()
        local scrollHeight = scrollFrame:GetHeight()
        local cursorTop = -y
        local cursorBottom = -y + h

        -- 커서가 화면 밖으로 나가는 것을 방지
        local maxScroll = self:GetHeight() - scrollHeight
        if maxScroll < 0 then maxScroll = 0 end

        -- 스크롤 업데이트가 필요한 경우만 처리
        if cursorTop < scrollOffset then
            self.isScrolling = true
            scrollFrame:SetVerticalScroll(math.max(0, cursorTop - 5))  -- 상단 여유 추가
            C_Timer.After(0.01, function() self.isScrolling = false end)
        elseif cursorBottom > (scrollOffset + scrollHeight - 40) then  -- 하단 여유를 40으로 증가
            self.isScrolling = true
            local newScroll = cursorBottom - scrollHeight + 40
            scrollFrame:SetVerticalScroll(math.min(maxScroll, math.max(0, newScroll)))  -- 최대 스크롤 범위 제한
            C_Timer.After(0.01, function() self.isScrolling = false end)
        end
    end)

    -- 배경 클릭 시 EditBox로 포커스
    bg:EnableMouse(true)
    bg:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            editBox:SetFocus()
        end
    end)

    -- 마우스 휠 스크롤
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local scrollStep = 20

        if delta > 0 then
            self:SetVerticalScroll(math.max(0, current - scrollStep))
        else
            self:SetVerticalScroll(math.min(maxScroll, current + scrollStep))
        end
    end)

    -- EditBox 크기를 실제로 맞추기 위한 지연 실행
    C_Timer.After(0.1, function()
        local w = scrollFrame:GetWidth()
        if w and w > 0 then
            editBox:SetWidth(w - 5)
        end
    end)

    bg.editBox = editBox
    bg.scrollFrame = scrollFrame

    return bg, editBox, scrollFrame
end

-- 기본 설정값
local defaults = {
    enabled = true,
    keywords = L["DEFAULT_KEYWORDS"],
    ignoreKeywords = "",
    playSound = true,
    soundVolume = 0.5,
    highlightColors = {
        GUILD = {r = 0, g = 1, b = 0},
        PUBLIC = {r = 1, g = 1, b = 0},
        PARTY_RAID = {r = 0, g = 0.5, b = 1},
        LFG = {r = 1, g = 0.5, b = 0},
    },
    highlightStyle = "both",
    channelGroups = {
        GUILD = true,
        PUBLIC = true,
        PARTY_RAID = true,
        LFG = true,
    },
    prefix = "",
    suffix = "",
    prefixSuffixChannels = {
        SAY = true,
        YELL = false,
        PARTY = true,
        GUILD = true,
        RAID = true,
        INSTANCE_CHAT = true,
        WHISPER = false,
        CHANNEL = false,
    },
    lastTab = 1,  -- 마지막으로 선택된 탭 저장
}

-- =============================================
-- 유틸리티 함수들
-- =============================================

-- 구분선 생성 함수
local function CreateSeparator(parent)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    -- SetPoint는 호출하는 쪽에서 설정하도록 변경
    return line
end

-- =============================================
-- 탭 시스템 함수들
-- =============================================

-- 탭 버튼 생성 함수
local function CreateTabButton(parent, text, index)
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

    return button
end

-- 탭 컨텐츠 프레임 생성 함수
local function CreateTabContent(parent, index)
    local frame = CreateFrame("Frame", "FoxChatTabContent"..index, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -95)
    frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 55)
    frame:Hide()  -- 기본적으로 숨김

    -- 배경 (선택사항)
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0, 0, 0, 0.2)

    return frame
end

-- 탭 전환 함수
local function SwitchToTab(index)
    if not tabs[index] or not tabContents[index] then return end

    currentTab = index

    -- 탭 상태 저장
    if FoxChatDB then
        FoxChatDB.lastTab = index
    end

    -- 모든 탭 버튼과 컨텐츠 업데이트
    for i = 1, #tabs do
        local tab = tabs[i]
        local content = tabContents[i]

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

    -- 테스트 버튼 표시/숨김 (채팅 필터링 탭에서만 표시)
    local configFrame = tabs[1]:GetParent()
    if configFrame and configFrame.testButton then
        if index == 1 then  -- 채팅 필터링 탭
            configFrame.testButton:Show()
        else
            configFrame.testButton:Hide()
        end
    end

    -- 설정에 현재 탭 저장
    if FoxChatDB then
        FoxChatDB.lastTab = index
    end
end

-- =============================================
-- 메인 설정창 함수
-- =============================================

function FoxChat:ShowConfig()
    if configFrame then
        configFrame:Show()
        configFrame:Raise()
        -- 마지막 탭 복원
        local lastTab = (FoxChatDB and FoxChatDB.lastTab) or 1
        SwitchToTab(lastTab)
        return
    end

    -- =============================================
    -- 메인 프레임 생성
    -- =============================================
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

    -- 배경
    configFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    -- 제목
    local title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", configFrame, "TOP", 0, -20)
    title:SetText(L["CONFIG_TITLE"])
    title:SetTextColor(1, 0.82, 0)

    -- =============================================
    -- 탭 생성
    -- =============================================

    -- 탭 버튼들 생성
    tabs[1] = CreateTabButton(configFrame, "채팅 필터링", 1)
    tabs[2] = CreateTabButton(configFrame, "말머리/말꼬리", 2)
    tabs[3] = CreateTabButton(configFrame, "광고 설정", 3)
    tabs[4] = CreateTabButton(configFrame, "자동", 4)

    -- 탭 컨텐츠 프레임들 생성
    tabContents[1] = CreateTabContent(configFrame, 1)
    tabContents[2] = CreateTabContent(configFrame, 2)
    tabContents[3] = CreateTabContent(configFrame, 3)
    tabContents[4] = CreateTabContent(configFrame, 4)

    -- 탭 버튼 클릭 이벤트
    for i, tab in ipairs(tabs) do
        tab:SetScript("OnClick", function()
            SwitchToTab(i)
        end)
    end

    -- 탭 구분선
    local tabSeparator = CreateSeparator(configFrame)
    tabSeparator:SetPoint("TOPLEFT", tabs[1], "BOTTOMLEFT", -20, -5)
    tabSeparator:SetPoint("RIGHT", configFrame, "RIGHT", 20, 0)

    -- =============================================
    -- 탭 1: 채팅 필터링
    -- =============================================
    local tab1 = tabContents[1]

    -- 상단 체크박스들 (한 줄로 배치)
    local filterEnabledCheckbox = CreateFrame("CheckButton", nil, tab1)
    filterEnabledCheckbox:SetSize(24, 24)
    filterEnabledCheckbox:SetPoint("TOPLEFT", tab1, "TOPLEFT", 10, -10)
    filterEnabledCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    filterEnabledCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    filterEnabledCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    filterEnabledCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    filterEnabledCheckbox:SetChecked(FoxChatDB and FoxChatDB.filterEnabled)

    local filterEnabledLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    filterEnabledLabel:SetPoint("LEFT", filterEnabledCheckbox, "RIGHT", 5, 0)
    filterEnabledLabel:SetText(L["FILTER_ENABLE"])

    filterEnabledCheckbox:SetScript("OnClick", function(self)
        if FoxChatDB then
            FoxChatDB.filterEnabled = self:GetChecked()
        end
    end)

    local soundCheckbox = CreateFrame("CheckButton", nil, tab1)
    soundCheckbox:SetSize(24, 24)
    soundCheckbox:SetPoint("LEFT", filterEnabledLabel, "RIGHT", 30, 0)
    soundCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    soundCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    soundCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    soundCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    soundCheckbox:SetChecked(FoxChatDB and FoxChatDB.playSound)

    local soundLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    soundLabel:SetPoint("LEFT", soundCheckbox, "RIGHT", 5, 0)
    soundLabel:SetText(L["PLAY_SOUND"])

    soundCheckbox:SetScript("OnClick", function(self)
        if FoxChatDB then
            FoxChatDB.playSound = self:GetChecked()
        end
    end)

    local minimapCheckbox = CreateFrame("CheckButton", nil, tab1)
    minimapCheckbox:SetSize(24, 24)
    minimapCheckbox:SetPoint("LEFT", soundLabel, "RIGHT", 30, 0)
    minimapCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    minimapCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    minimapCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    minimapCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    minimapCheckbox:SetChecked(FoxChatDB and FoxChatDB.minimapButton and not FoxChatDB.minimapButton.hide)

    local minimapLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    minimapLabel:SetPoint("LEFT", minimapCheckbox, "RIGHT", 5, 0)
    minimapLabel:SetText(L["SHOW_MINIMAP_BUTTON"])

    minimapCheckbox:SetScript("OnClick", function(self)
        if FoxChatDB and FoxChatDB.minimapButton then
            FoxChatDB.minimapButton.hide = not self:GetChecked()
            if FoxChatDB.minimapButton.hide then
                if _G["FoxChatMinimapButton"] then
                    _G["FoxChatMinimapButton"]:Hide()
                end
            else
                if _G["FoxChatMinimapButton"] then
                    _G["FoxChatMinimapButton"]:Show()
                end
            end
        end
    end)

    -- 구분선
    local separator1 = CreateSeparator(tab1)
    separator1:SetPoint("TOPLEFT", filterEnabledCheckbox, "BOTTOMLEFT", -10, -15)
    separator1:SetPoint("RIGHT", tab1, "RIGHT", -10, 0)

    -- 필터링 키워드 (왼쪽)
    local keywordsLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    keywordsLabel:SetPoint("TOPLEFT", separator1, "BOTTOMLEFT", 10, -10)
    keywordsLabel:SetText(L["KEYWORDS_LABEL"])

    local keywordsHelp = tab1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    keywordsHelp:SetPoint("TOPLEFT", keywordsLabel, "BOTTOMLEFT", 0, -3)
    keywordsHelp:SetText(L["KEYWORDS_HELP"])

    -- 필터링 키워드 입력창 (CreateTextArea 사용)
    local keywordsBackground
    keywordsBackground, keywordsEditBox = CreateTextArea(tab1, 260, 120, 0)
    keywordsBackground:SetPoint("TOPLEFT", keywordsHelp, "BOTTOMLEFT", 0, -5)

    -- 텍스트 변경 시 DB 저장
    keywordsEditBox:HookScript("OnTextChanged", function(self, user)
        if FoxChatDB then
            local text = self:GetText() or ""
            local keywords = {}

            -- 쉼표로만 구분
            for keyword in string.gmatch(text, "[^,]+") do
                local trimmed = string.gsub(keyword, "^%s*(.-)%s*$", "%1")
                if trimmed ~= "" then
                    table.insert(keywords, trimmed)
                end
            end

            FoxChatDB.keywords = keywords
            if FoxChat and FoxChat.UpdateKeywords then
                FoxChat:UpdateKeywords()
            end
        end
    end)

    -- 키워드 배열을 문자열로 변환 (쉼표로 구분)
    local keywordText = ""
    if FoxChatDB and FoxChatDB.keywords then
        if type(FoxChatDB.keywords) == "table" then
            keywordText = table.concat(FoxChatDB.keywords, ", ")
        else
            keywordText = tostring(FoxChatDB.keywords)
        end
    end
    keywordsEditBox:SetText(keywordText)

    -- 무시 키워드 (오른쪽)
    local ignoreLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ignoreLabel:SetPoint("TOPLEFT", keywordsLabel, "TOPLEFT", 280, 0)
    ignoreLabel:SetText(L["IGNORE_KEYWORDS_LABEL"])

    local ignoreHelp = tab1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ignoreHelp:SetPoint("TOPLEFT", ignoreLabel, "BOTTOMLEFT", 0, -3)
    ignoreHelp:SetText(L["IGNORE_KEYWORDS_HELP"])

    -- 무시 키워드 입력창 (CreateTextArea 사용)
    local ignoreBackground
    ignoreBackground, ignoreKeywordsEditBox = CreateTextArea(tab1, 260, 120, 0)
    ignoreBackground:SetPoint("TOPLEFT", ignoreHelp, "BOTTOMLEFT", 0, -5)

    -- 텍스트 변경 시 DB 저장
    ignoreKeywordsEditBox:HookScript("OnTextChanged", function(self, user)
        if FoxChatDB then
            local text = self:GetText() or ""
            local keywords = {}

            -- 쉼표로만 구분
            for keyword in string.gmatch(text, "[^,]+") do
                local trimmed = string.gsub(keyword, "^%s*(.-)%s*$", "%1")
                if trimmed ~= "" then
                    table.insert(keywords, trimmed)
                end
            end

            FoxChatDB.ignoreKeywords = keywords
            if FoxChat and FoxChat.UpdateIgnoreKeywords then
                FoxChat:UpdateIgnoreKeywords()
            end
        end
    end)
    -- 무시 키워드 배열을 문자열로 변환 (쉼표로 구분)
    local ignoreText = ""
    if FoxChatDB and FoxChatDB.ignoreKeywords then
        if type(FoxChatDB.ignoreKeywords) == "table" then
            ignoreText = table.concat(FoxChatDB.ignoreKeywords, ", ")
        else
            ignoreText = tostring(FoxChatDB.ignoreKeywords)
        end
    end
    ignoreKeywordsEditBox:SetText(ignoreText)

    -- 하이라이트 스타일
    local styleLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    styleLabel:SetPoint("TOPLEFT", keywordsBackground, "BOTTOMLEFT", 0, -15)
    styleLabel:SetText(L["HIGHLIGHT_STYLE"])

    local styles = {
        {value = "bold", text = L["STYLE_BOLD"], x = 0},
        {value = "color", text = L["STYLE_COLOR"], x = 120},
        {value = "both", text = L["STYLE_BOTH"], x = 240},
    }

    local styleButtons = {}
    for i, style in ipairs(styles) do
        local radioButton = CreateFrame("CheckButton", nil, tab1)
        radioButton:SetSize(20, 20)
        radioButton:SetPoint("TOPLEFT", styleLabel, "BOTTOMLEFT", style.x, -5)
        radioButton:SetNormalTexture("Interface\\Buttons\\UI-RadioButton")
        radioButton:GetNormalTexture():SetTexCoord(0, 0.25, 0, 1)
        radioButton:SetPushedTexture("Interface\\Buttons\\UI-RadioButton")
        radioButton:GetPushedTexture():SetTexCoord(0.5, 0.75, 0, 1)
        radioButton:SetHighlightTexture("Interface\\Buttons\\UI-RadioButton")
        radioButton:GetHighlightTexture():SetTexCoord(0, 0.25, 0, 1)
        radioButton:GetHighlightTexture():SetBlendMode("ADD")
        radioButton:SetCheckedTexture("Interface\\Buttons\\UI-RadioButton")
        radioButton:GetCheckedTexture():SetTexCoord(0.25, 0.5, 0, 1)

        local label = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", radioButton, "RIGHT", 3, 0)
        label:SetText(style.text)

        radioButton.value = style.value
        radioButton:SetChecked(FoxChatDB and FoxChatDB.highlightStyle == style.value)

        radioButton:SetScript("OnClick", function(self)
            for _, btn in ipairs(styleButtons) do
                btn:SetChecked(false)
            end
            self:SetChecked(true)
            if FoxChatDB then
                FoxChatDB.highlightStyle = self.value
            end
        end)

        styleButtons[i] = radioButton
    end

    -- 채널별 색상 및 모니터링 설정
    local colorLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colorLabel:SetPoint("TOPLEFT", styleLabel, "BOTTOMLEFT", 0, -35)
    colorLabel:SetText(L["CHANNELS_AND_COLORS"])

    local colorSwatches = {}
    local channelCheckboxes = {}
    local channelGroupOptions = {
        {key = "GUILD", text = L["CHANNEL_GROUP_GUILD"], x = 0, y = 0},
        {key = "PUBLIC", text = L["CHANNEL_GROUP_PUBLIC"], x = 140, y = 0},
        {key = "PARTY_RAID", text = L["CHANNEL_GROUP_PARTY_RAID"], x = 280, y = 0},
        {key = "LFG", text = L["CHANNEL_GROUP_LFG"], x = 420, y = 0},
    }

    for i, group in ipairs(channelGroupOptions) do
        -- 체크박스
        local checkbox = CreateFrame("CheckButton", nil, tab1)
        checkbox:SetSize(20, 20)
        checkbox:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", group.x, -20 + group.y)
        checkbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        checkbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        checkbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
        checkbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
        checkbox:SetChecked(FoxChatDB and FoxChatDB.channelGroups and FoxChatDB.channelGroups[group.key])

        checkbox:SetScript("OnClick", function(self)
            if FoxChatDB then
                if not FoxChatDB.channelGroups then
                    FoxChatDB.channelGroups = {}
                end
                FoxChatDB.channelGroups[group.key] = self:GetChecked()
            end
        end)

        channelCheckboxes[group.key] = checkbox

        -- 채널 이름
        local groupLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        groupLabel:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
        groupLabel:SetText(group.text)

        -- 색상 선택 버튼
        local colorSwatch = CreateFrame("Button", nil, tab1)
        colorSwatch:SetSize(16, 16)
        colorSwatch:SetPoint("LEFT", groupLabel, "RIGHT", 5, 0)

        local colorTexture = colorSwatch:CreateTexture(nil, "ARTWORK")
        colorTexture:SetAllPoints()
        local color = (FoxChatDB and FoxChatDB.highlightColors and FoxChatDB.highlightColors[group.key]) or defaults.highlightColors[group.key]
        colorTexture:SetColorTexture(color.r, color.g, color.b)

        local colorBorder = colorSwatch:CreateTexture(nil, "OVERLAY")
        colorBorder:SetTexture("Interface\\ChatFrame\\ChatFrameColorSwatch")
        colorBorder:SetAllPoints()

        colorSwatches[group.key] = {texture = colorTexture, color = color}

        colorSwatch:SetScript("OnClick", function()
            local groupKey = group.key
            local function OnColorSelect()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                if FoxChatDB then
                    if not FoxChatDB.highlightColors then
                        FoxChatDB.highlightColors = {}
                    end
                    FoxChatDB.highlightColors[groupKey] = {r = r, g = g, b = b}
                    colorTexture:SetColorTexture(r, g, b)
                    colorSwatches[groupKey].color = {r = r, g = g, b = b}
                end
            end

            ColorPickerFrame.func = OnColorSelect
            ColorPickerFrame.cancelFunc = function(previousValues)
                if previousValues and FoxChatDB then
                    FoxChatDB.highlightColors[groupKey] = previousValues
                    colorTexture:SetColorTexture(previousValues.r, previousValues.g, previousValues.b)
                end
            end
            ColorPickerFrame.previousValues = color
            ColorPickerFrame:SetColorRGB(color.r, color.g, color.b)
            ColorPickerFrame:Show()
        end)
    end

    -- 토스트 위치 설정
    local toastPosLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toastPosLabel:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -50)
    toastPosLabel:SetText("토스트 위치:")

    local toastPosDesc = tab1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    toastPosDesc:SetPoint("LEFT", toastPosLabel, "RIGHT", 10, 0)
    toastPosDesc:SetText("(0, 0)이 화면 정중앙")

    -- X 위치
    local toastXLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    toastXLabel:SetPoint("TOPLEFT", toastPosLabel, "BOTTOMLEFT", 0, -10)
    toastXLabel:SetText("X:")

    local toastXEditBox = CreateFrame("EditBox", nil, tab1)
    toastXEditBox:SetSize(60, 20)
    toastXEditBox:SetPoint("LEFT", toastXLabel, "RIGHT", 5, 0)
    toastXEditBox:SetAutoFocus(false)
    toastXEditBox:SetMaxLetters(6)
    toastXEditBox:SetFontObject(GameFontHighlight)
    toastXEditBox:SetText(tostring((FoxChatDB and FoxChatDB.toastPosition and FoxChatDB.toastPosition.x) or 0))

    local toastXBg = CreateFrame("Frame", nil, tab1, "BackdropTemplate")
    toastXBg:SetPoint("TOPLEFT", toastXEditBox, -5, 5)
    toastXBg:SetPoint("BOTTOMRIGHT", toastXEditBox, 5, -5)
    toastXBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    toastXBg:SetBackdropColor(0, 0, 0, 0.8)

    toastXEditBox:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText())
        if value and FoxChatDB then
            if not FoxChatDB.toastPosition then
                FoxChatDB.toastPosition = {x = 0, y = -320}
            end
            FoxChatDB.toastPosition.x = value
        end
    end)

    -- Y 위치
    local toastYLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    toastYLabel:SetPoint("LEFT", toastXBg, "RIGHT", 15, 0)
    toastYLabel:SetText("Y:")

    local toastYEditBox = CreateFrame("EditBox", nil, tab1)
    toastYEditBox:SetSize(60, 20)
    toastYEditBox:SetPoint("LEFT", toastYLabel, "RIGHT", 5, 0)
    toastYEditBox:SetAutoFocus(false)
    toastYEditBox:SetMaxLetters(6)
    toastYEditBox:SetFontObject(GameFontHighlight)
    toastYEditBox:SetText(tostring((FoxChatDB and FoxChatDB.toastPosition and FoxChatDB.toastPosition.y) or -320))

    local toastYBg = CreateFrame("Frame", nil, tab1, "BackdropTemplate")
    toastYBg:SetPoint("TOPLEFT", toastYEditBox, -5, 5)
    toastYBg:SetPoint("BOTTOMRIGHT", toastYEditBox, 5, -5)
    toastYBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    toastYBg:SetBackdropColor(0, 0, 0, 0.8)

    toastYEditBox:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText())
        if value and FoxChatDB then
            if not FoxChatDB.toastPosition then
                FoxChatDB.toastPosition = {x = 0, y = -320}
            end
            FoxChatDB.toastPosition.y = value
        end
    end)

    -- 토스트 테스트 버튼
    local toastTestBtn = CreateFrame("Button", nil, tab1, "UIPanelButtonTemplate")
    toastTestBtn:SetSize(100, 22)
    toastTestBtn:SetPoint("LEFT", toastYBg, "RIGHT", 15, 0)
    toastTestBtn:SetText("토스트 테스트")
    toastTestBtn:SetScript("OnClick", function()
        if FoxChat and FoxChat.ShowToast then
            FoxChat.ShowToast("테스트 사용자", "토스트 위치 테스트 메시지입니다.", "GUILD", true)
        end
    end)

    -- =============================================
    -- 탭 2: 말머리/말꼬리
    -- =============================================
    local tab2 = tabContents[2]

    -- 채널별 말머리 입력창들을 저장할 테이블
    local prefixEditBoxes = {}
    local channelLabels = {
        {"일반 말머리", "SAY"},           -- /say 일반 대화
        {"공개 말머리", "YELL"},          -- /yell 외치기
        {"파티찾기 말머리", "LFG"},       -- 파티찾기 채널
        {"거래 말머리", "TRADE"},         -- 거래 채널
        {"길드 말머리", "GUILD"},         -- 길드 채팅
        {"파티+공대 말머리", "GROUP"},    -- 파티/공격대
        {"귓속말 말머리", "WHISPER"}      -- 귓속말
    }

    -- 말머리/말꼬리 활성화 체크박스
    local prefixSuffixEnabledCheckbox = CreateFrame("CheckButton", nil, tab2)
    prefixSuffixEnabledCheckbox:SetSize(24, 24)
    prefixSuffixEnabledCheckbox:SetPoint("TOPLEFT", tab2, "TOPLEFT", 10, -10)
    prefixSuffixEnabledCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    prefixSuffixEnabledCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    prefixSuffixEnabledCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    prefixSuffixEnabledCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    prefixSuffixEnabledCheckbox:SetChecked(FoxChatDB and FoxChatDB.prefixSuffixEnabled == true)

    local prefixSuffixEnabledLabel = tab2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    prefixSuffixEnabledLabel:SetPoint("LEFT", prefixSuffixEnabledCheckbox, "RIGHT", 5, 0)
    prefixSuffixEnabledLabel:SetText("말머리/말꼬리 사용")

    prefixSuffixEnabledCheckbox:SetScript("OnClick", function(self)
        if FoxChatDB then
            local isChecked = self:GetChecked()
            -- WoW Classic에서 GetChecked()는 1 또는 nil을 반환할 수 있음
            FoxChatDB.prefixSuffixEnabled = (isChecked == 1 or isChecked == true) and true or false

            -- 항상 출력 (디버그 확인용)
            print(string.format("|cFFFF7D0A[FoxChat]|r 말머리/말꼬리 설정 변경: 체크값=%s, 저장값=%s",
                tostring(isChecked), tostring(FoxChatDB.prefixSuffixEnabled)))
        end
    end)

    -- 설명 텍스트
    local prefixSuffixHelp = tab2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    prefixSuffixHelp:SetPoint("TOPLEFT", prefixSuffixEnabledCheckbox, "BOTTOMLEFT", 0, -5)
    prefixSuffixHelp:SetText("내 메시지 앞뒤에 자동으로 텍스트를 추가합니다.")

    -- 구분선
    local separator1 = CreateSeparator(tab2)
    separator1:SetPoint("TOPLEFT", prefixSuffixHelp, "BOTTOMLEFT", -10, -10)
    separator1:SetPoint("RIGHT", tab2, "RIGHT", -10, 0)

    -- 각 채널별 말머리 입력 필드 생성
    local yOffset = -15
    for i, channelInfo in ipairs(channelLabels) do
        local label = tab2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", separator1, "BOTTOMLEFT", 10, yOffset)
        label:SetText(channelInfo[1] .. ":")
        label:SetWidth(120)
        label:SetJustifyH("LEFT")
        local editBg = CreateFrame("Frame", nil, tab2, "BackdropTemplate")
        editBg:SetSize(430, 22)
        editBg:SetPoint("LEFT", label, "RIGHT", 10, 0)
        editBg:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        editBg:SetBackdropColor(0, 0, 0, 0.8)

        local editBox = CreateFrame("EditBox", nil, editBg)
        editBox:SetSize(420, 18)
        editBox:SetPoint("LEFT", 5, 0)
        editBox:SetAutoFocus(false)
        editBox:SetMaxLetters(50)
        editBox:SetFontObject(GameFontHighlight)

        -- DB에서 값 로드
        if FoxChatDB and FoxChatDB.channelPrefixSuffix and FoxChatDB.channelPrefixSuffix[channelInfo[2]] then
            editBox:SetText(FoxChatDB.channelPrefixSuffix[channelInfo[2]].prefix or "")
        else
            editBox:SetText("")
        end

        editBox:SetScript("OnTextChanged", function(self)
            if FoxChatDB then
                if not FoxChatDB.channelPrefixSuffix then
                    FoxChatDB.channelPrefixSuffix = {}
                end
                if not FoxChatDB.channelPrefixSuffix[channelInfo[2]] then
                    FoxChatDB.channelPrefixSuffix[channelInfo[2]] = {}
                end
                FoxChatDB.channelPrefixSuffix[channelInfo[2]].prefix = self:GetText()
            end
        end)

        editBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)

        prefixEditBoxes[channelInfo[2]] = editBox
        yOffset = yOffset - 30
    end

    -- 구분선 2
    local separator2 = CreateSeparator(tab2)
    separator2:SetPoint("TOPLEFT", separator1, "BOTTOMLEFT", 0, yOffset - 10)
    separator2:SetPoint("RIGHT", tab2, "RIGHT", -10, 0)

    -- 공통 말꼬리 입력
    local suffixLabel = tab2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    suffixLabel:SetPoint("TOPLEFT", separator2, "BOTTOMLEFT", 10, -15)
    suffixLabel:SetText("공통 말꼬리:")
    suffixLabel:SetWidth(120)
    suffixLabel:SetJustifyH("LEFT")

    local suffixBg = CreateFrame("Frame", nil, tab2, "BackdropTemplate")
    suffixBg:SetSize(430, 22)
    suffixBg:SetPoint("LEFT", suffixLabel, "RIGHT", 10, 0)
    suffixBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    suffixBg:SetBackdropColor(0, 0, 0, 0.8)

    local suffixEditBox = CreateFrame("EditBox", nil, suffixBg)
    suffixEditBox:SetSize(420, 18)
    suffixEditBox:SetPoint("LEFT", 5, 0)
    suffixEditBox:SetAutoFocus(false)
    suffixEditBox:SetMaxLetters(50)
    suffixEditBox:SetFontObject(GameFontHighlight)

    -- DB에서 공통 말꼬리 값 로드
    if FoxChatDB and FoxChatDB.suffix then
        suffixEditBox:SetText(FoxChatDB.suffix or "")
    else
        suffixEditBox:SetText("")
    end

    suffixEditBox:SetScript("OnTextChanged", function(self)
        if FoxChatDB then
            FoxChatDB.suffix = self:GetText()
        end
    end)

    suffixEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    -- 구분선 3
    local separator3 = CreateSeparator(tab2)
    separator3:SetPoint("TOPLEFT", suffixBg, "BOTTOMLEFT", -10, -15)
    separator3:SetPoint("RIGHT", tab2, "RIGHT", -10, 0)

    -- 설명 텍스트
    local noteLabel = tab2:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    noteLabel:SetPoint("TOPLEFT", separator3, "BOTTOMLEFT", 10, -10)
    noteLabel:SetText("채널별 말머리는 각각 다르게 설정할 수 있고, 말꼬리는 모든 채널에 공통으로 적용됩니다.")
    noteLabel:SetJustifyH("LEFT")

    local noteLabel2 = tab2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    noteLabel2:SetPoint("TOPLEFT", noteLabel, "BOTTOMLEFT", 0, -5)
    noteLabel2:SetText("|cFFFF7F50※ 광고(공개+거래)시에는 말머리/말꼬리가 적용되지 않습니다|r")
    noteLabel2:SetJustifyH("LEFT")

    local tipLabel = tab2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tipLabel:SetPoint("TOPLEFT", noteLabel2, "BOTTOMLEFT", 0, -5)
    tipLabel:SetText("|cFFFFFF00팁:|r 위상 메시지(일위상, 이위상, 삼위상)는 자동으로 제외됩니다.")
    tipLabel:SetJustifyH("LEFT")

    -- =============================================
    -- 탭 3: 광고 설정
    -- =============================================
    local tab3 = tabContents[3]
    configFrame.tab3 = tab3  -- configFrame에 tab3 참조 저장

    -- 광고 메시지 레이블
    local adMessageLabel = tab3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    adMessageLabel:SetPoint("TOPLEFT", tab3, "TOPLEFT", 10, -10)
    adMessageLabel:SetText("광고 메시지:")

    -- 글자 수 표시 레이블
    local adCharCountLabel = tab3:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    adCharCountLabel:SetPoint("LEFT", adMessageLabel, "RIGHT", 10, 0)
    adCharCountLabel:SetText("(0/255)")

    -- 말머리/말꼬리 바이트 수 표시
    local adPrefixSuffixLabel = tab3:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    adPrefixSuffixLabel:SetPoint("LEFT", adCharCountLabel, "RIGHT", 10, 0)

    -- 말머리/말꼬리 바이트 수 계산 및 표시 함수
    local function UpdatePrefixSuffixBytes()
        -- 광고는 파티찾기(LFG) 또는 거래(TRADE) 채널의 말머리 사용 (광고 채널 설정에 따라)
        local adChannel = (FoxChatDB and FoxChatDB.adChannel) or "파티찾기"
        local prefix = ""
        if FoxChatDB and FoxChatDB.channelPrefixSuffix then
            if adChannel == "파티찾기" and FoxChatDB.channelPrefixSuffix.LFG then
                prefix = FoxChatDB.channelPrefixSuffix.LFG.prefix or ""
            elseif adChannel == "거래" and FoxChatDB.channelPrefixSuffix.TRADE then
                prefix = FoxChatDB.channelPrefixSuffix.TRADE.prefix or ""
            end
        end
        local suffix = (FoxChatDB and FoxChatDB.suffix) or ""
        local prefixBytes = GetUTF8ByteLength(prefix)
        local suffixBytes = GetUTF8ByteLength(suffix)

        if prefixBytes > 0 or suffixBytes > 0 then
            adPrefixSuffixLabel:SetText(string.format("말머리(%d), 말꼬리(%d)", prefixBytes, suffixBytes))
        else
            adPrefixSuffixLabel:SetText("")
        end
    end

    -- 초기 업데이트
    UpdatePrefixSuffixBytes()
    tab3.UpdatePrefixSuffixBytes = UpdatePrefixSuffixBytes

    local adMessageHelp = tab3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    adMessageHelp:SetPoint("TOPLEFT", adMessageLabel, "BOTTOMLEFT", 0, -3)
    adMessageHelp:SetText("Questie 퀘스트는 채팅창에 복사 후 아래에 붙여넣으면 편해요")

    -- 광고 메시지 입력 박스 (새로운 TextArea 사용)
    local adMessageBackground, adMessageEditBox = CreateTextArea(tab3, 260, 120, 0)  -- 255 제한 제거 (카운터로만 관리)
    adMessageBackground:SetPoint("TOPLEFT", adMessageHelp, "BOTTOMLEFT", 0, -5)

    -- 기존 텍스트 설정
    local adText = (FoxChatDB and FoxChatDB.adMessage) or ""
    adMessageEditBox:SetText(adText)

    -- 광고 카운터 업데이트 함수
    local function UpdateAdCounter()
        local adMsg = adMessageEditBox:GetText() or ""

        -- 실제 전송될 메시지 구성
        local suffix = ""
        local firstComeMsg = (FoxChatDB and FoxChatDB.firstComeMessage) or ""
        if firstComeMsg ~= "" then
            suffix = suffix .. " (" .. firstComeMsg .. ")"
        end

        -- 파티가 있을 때만 파티 정보 추가
        if IsInGroup() then
            local n = GetNumGroupMembers()
            local m = (FoxChatDB and FoxChatDB.partyMaxSize) or 5
            suffix = suffix .. " (" .. n .. "/" .. m .. ")"
        end

        local fullMessage = adMsg .. suffix
        local bytes = #fullMessage  -- UTF-8 바이트 수

        -- 레이블 업데이트
        if bytes > 255 then
            adCharCountLabel:SetText(string.format("|cFFFF0000(%d/255 : 전송불가)|r", bytes))
        else
            adCharCountLabel:SetText(string.format("(%d/255)", bytes))
        end

        -- 버튼 상태 업데이트
        if tab3.UpdateAdStartButton then
            tab3.UpdateAdStartButton()
        end
        if FoxChat and FoxChat.UpdateAdButton then
            FoxChat:UpdateAdButton()
        end
    end

    -- 텍스트 변경 시 DB 저장 및 카운터 업데이트
    adMessageEditBox:HookScript("OnTextChanged", function(self, user)
        if FoxChatDB then
            FoxChatDB.adMessage = self:GetText() or ""
        end
        UpdateAdCounter()
    end)

    -- 초기 카운터 업데이트
    C_Timer.After(0.1, UpdateAdCounter)

    -- 선입 메시지 레이블
    local firstComeLabel = tab3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    firstComeLabel:SetPoint("TOPLEFT", adMessageLabel, "TOPRIGHT", 280, 0)
    firstComeLabel:SetText("선입 메시지:")

    local firstComeHelp = tab3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    firstComeHelp:SetPoint("TOPLEFT", firstComeLabel, "BOTTOMLEFT", 0, -3)
    firstComeHelp:SetText("파티/공격대원에게 외칠 메시지")

    -- 선입 메시지 입력 박스 (새로운 TextArea 사용)
    local firstComeBackground, firstComeEditBox = CreateTextArea(tab3, 260, 120, 0)  -- 255 제한 제거
    firstComeBackground:SetPoint("LEFT", adMessageBackground, "RIGHT", 10, 0)

    -- 기존 텍스트 설정
    local firstComeText = (FoxChatDB and FoxChatDB.firstComeMessage) or ""
    firstComeEditBox:SetText(firstComeText)

    -- 텍스트 변경 시 DB 저장 및 광고 카운터 업데이트
    firstComeEditBox:HookScript("OnTextChanged", function(self, user)
        if FoxChatDB then
            FoxChatDB.firstComeMessage = self:GetText() or ""
        end

        -- 광고 메시지 카운터 재계산 (선입 메시지도 포함되므로)
        UpdateAdCounter()

        -- 선입 메시지 버튼 상태 업데이트
        if tab3.UpdateFirstComeStartButton then
            tab3.UpdateFirstComeStartButton()
        end
        if FoxChat and FoxChat.UpdateFirstComeButton then
            FoxChat:UpdateFirstComeButton()
        end
    end)

    -- 초기 글자 수 계산 함수
    local function UpdateCharCount()
        local adMsg = FoxChatDB and FoxChatDB.adMessage or ""
        local firstComeMsg = FoxChatDB and FoxChatDB.firstComeMessage or ""

        local fullMessage = adMsg
        if firstComeMsg ~= "" then
            fullMessage = fullMessage .. " (" .. firstComeMsg .. ")"
        end

        -- 파티가 있을 때만 파티 정보 추가
        if IsInGroup() then
            local numGroupMembers = GetNumGroupMembers()
            local maxMembers = FoxChatDB and FoxChatDB.partyMaxSize or 5
            fullMessage = fullMessage .. " (" .. numGroupMembers .. "/" .. maxMembers .. ")"
        end

        local byteCount = GetUTF8ByteLength(fullMessage)

        if byteCount > 255 then
            adCharCountLabel:SetText(string.format("|cFFFF0000(%d/255 : 전송불가)|r", byteCount))
        else
            adCharCountLabel:SetText(string.format("(%d/255)", byteCount))
        end
    end

    -- 초기 값 설정
    C_Timer.After(0.15, UpdateCharCount)

    -- 구분선
    local separator3 = CreateSeparator(tab3)
    separator3:SetPoint("TOPLEFT", adMessageBackground, "BOTTOMLEFT", -10, -15)
    separator3:SetPoint("RIGHT", tab3, "RIGHT", -10, 0)

    -- 광고 버튼 위치 설정
    local adPosLabel = tab3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    adPosLabel:SetPoint("TOPLEFT", separator3, "BOTTOMLEFT", 10, -15)
    adPosLabel:SetText("광고 버튼 위치:")

    local adPosDesc = tab3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    adPosDesc:SetPoint("LEFT", adPosLabel, "RIGHT", 10, 0)
    adPosDesc:SetText("(0, 0)이 화면 정중앙 | Shift+드래그로 버튼 이동 가능")

    -- X 위치
    local adXLabel = tab3:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    adXLabel:SetPoint("TOPLEFT", adPosLabel, "BOTTOMLEFT", 0, -15)
    adXLabel:SetText("X:")

    local adXEditBox = CreateFrame("EditBox", nil, tab3)
    adXEditBox:SetSize(60, 20)
    adXEditBox:SetPoint("LEFT", adXLabel, "RIGHT", 5, 0)
    adXEditBox:SetAutoFocus(false)
    adXEditBox:SetMaxLetters(6)
    adXEditBox:SetFontObject(GameFontHighlight)
    adXEditBox:SetNumeric(false)
    adXEditBox:SetText(tostring((FoxChatDB and FoxChatDB.adPosition and FoxChatDB.adPosition.x) or 350))
    configFrame.adXEditBox = adXEditBox  -- 참조 저장

    local adXBg = CreateFrame("Frame", nil, tab3, "BackdropTemplate")
    adXBg:SetPoint("TOPLEFT", adXEditBox, -5, 5)
    adXBg:SetPoint("BOTTOMRIGHT", adXEditBox, 5, -5)
    adXBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    adXBg:SetBackdropColor(0, 0, 0, 0.8)

    adXEditBox:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText())
        if value and FoxChatDB then
            if not FoxChatDB.adPosition then
                FoxChatDB.adPosition = {x = 350, y = -150}
            end
            FoxChatDB.adPosition.x = value
            if _G["FoxChatAdButton"] then
                _G["FoxChatAdButton"]:ClearAllPoints()
                _G["FoxChatAdButton"]:SetPoint("CENTER", UIParent, "CENTER", FoxChatDB.adPosition.x, FoxChatDB.adPosition.y)
            end
        end
    end)

    adXEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    -- Y 위치
    local adYLabel = tab3:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    adYLabel:SetPoint("LEFT", adXBg, "RIGHT", 15, 0)
    adYLabel:SetText("Y:")

    local adYEditBox = CreateFrame("EditBox", nil, tab3)
    adYEditBox:SetSize(60, 20)
    adYEditBox:SetPoint("LEFT", adYLabel, "RIGHT", 5, 0)
    adYEditBox:SetAutoFocus(false)
    adYEditBox:SetMaxLetters(6)
    adYEditBox:SetFontObject(GameFontHighlight)
    adYEditBox:SetNumeric(false)
    adYEditBox:SetText(tostring((FoxChatDB and FoxChatDB.adPosition and FoxChatDB.adPosition.y) or -150))
    configFrame.adYEditBox = adYEditBox  -- 참조 저장

    local adYBg = CreateFrame("Frame", nil, tab3, "BackdropTemplate")
    adYBg:SetPoint("TOPLEFT", adYEditBox, -5, 5)
    adYBg:SetPoint("BOTTOMRIGHT", adYEditBox, 5, -5)
    adYBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    adYBg:SetBackdropColor(0, 0, 0, 0.8)

    adYEditBox:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText())
        if value and FoxChatDB then
            if not FoxChatDB.adPosition then
                FoxChatDB.adPosition = {x = 350, y = -150}
            end
            FoxChatDB.adPosition.y = value
            if _G["FoxChatAdButton"] then
                _G["FoxChatAdButton"]:ClearAllPoints()
                _G["FoxChatAdButton"]:SetPoint("CENTER", UIParent, "CENTER", FoxChatDB.adPosition.x, FoxChatDB.adPosition.y)
            end
        end
    end)

    adYEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    -- 쿨타임 설정
    local cooldownLabel = tab3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cooldownLabel:SetPoint("TOPLEFT", adXLabel, "BOTTOMLEFT", 0, -20)
    cooldownLabel:SetText("쿨타임:")

    -- 쿨타임 드롭다운
    local cooldownDropdown = CreateFrame("Frame", "FoxChatCooldownDropdown", tab3, "UIDropDownMenuTemplate")
    cooldownDropdown:SetPoint("LEFT", cooldownLabel, "RIGHT", 0, -2)
    UIDropDownMenu_SetWidth(cooldownDropdown, 100)

    local cooldownOptions = {
        {value = 30, text = "30초"},
        {value = 45, text = "45초"},
        {value = 60, text = "60초"},
    }

    local function CooldownDropdown_Initialize(self)
        for _, option in ipairs(cooldownOptions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.func = function()
                UIDropDownMenu_SetSelectedValue(cooldownDropdown, option.value)
                UIDropDownMenu_SetText(cooldownDropdown, option.text)
                if FoxChatDB then
                    FoxChatDB.adCooldown = option.value
                end
                -- 안내 텍스트 업데이트
                if tab3.UpdateInfoText then
                    tab3.UpdateInfoText()
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end

    UIDropDownMenu_Initialize(cooldownDropdown, CooldownDropdown_Initialize)
    local currentCooldown = (FoxChatDB and FoxChatDB.adCooldown) or 30
    UIDropDownMenu_SetSelectedValue(cooldownDropdown, currentCooldown)
    UIDropDownMenu_SetText(cooldownDropdown, currentCooldown .. "초")

    -- 파티원 수 설정
    local partyMaxLabel = tab3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    partyMaxLabel:SetPoint("LEFT", cooldownDropdown, "RIGHT", 20, 2)
    partyMaxLabel:SetText("파티원수:")

    -- 파티원수 도움말 (0 설명 추가)
    local partyMaxHelp = tab3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    partyMaxHelp:SetPoint("TOPLEFT", partyMaxLabel, "BOTTOMLEFT", 0, -2)
    partyMaxHelp:SetText("|cFF808080(0=수동입력)|r")
    partyMaxHelp:SetTextColor(0.7, 0.7, 0.7)

    local partyMaxBackground = CreateFrame("Frame", nil, tab3, "BackdropTemplate")
    partyMaxBackground:SetSize(50, 24)
    partyMaxBackground:SetPoint("LEFT", partyMaxLabel, "RIGHT", 5, -2)
    if partyMaxBackground.SetBackdrop then
        partyMaxBackground:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        partyMaxBackground:SetBackdropColor(0, 0, 0, 0.8)
    end

    local partyMaxEditBox = CreateFrame("EditBox", nil, partyMaxBackground)
    partyMaxEditBox:SetSize(40, 20)
    partyMaxEditBox:SetPoint("LEFT", 5, 0)
    partyMaxEditBox:SetAutoFocus(false)
    partyMaxEditBox:SetMaxLetters(2)  -- 최대 2자리 숫자 (0-40)
    partyMaxEditBox:SetFontObject(GameFontHighlight)
    partyMaxEditBox:SetNumeric(false)  -- false로 변경하여 더 유연한 입력 허용
    partyMaxEditBox:SetText(tostring((FoxChatDB and FoxChatDB.partyMaxSize) or 5))

    local isSettingPartyMax = false
    partyMaxEditBox:SetScript("OnTextChanged", function(self)
        if isSettingPartyMax then return end  -- 재귀 방지

        local text = self:GetText()
        -- 숫자가 아닌 문자 제거
        local cleanText = text:gsub("%D", "")
        if cleanText ~= text then
            isSettingPartyMax = true
            self:SetText(cleanText)
            isSettingPartyMax = false
            return
        end

        local value = tonumber(cleanText)
        if value then
            -- 0부터 40까지 제한
            if value < 0 then
                value = 0
                isSettingPartyMax = true
                self:SetText("0")
                isSettingPartyMax = false
            elseif value > 40 then
                value = 40
                isSettingPartyMax = true
                self:SetText("40")
                isSettingPartyMax = false
            end
            if FoxChatDB then
                FoxChatDB.partyMaxSize = value
            end
        end
    end)

    partyMaxEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    partyMaxEditBox:SetScript("OnEditFocusLost", function(self)
        local value = tonumber(self:GetText())
        if not value or value < 0 or value > 40 then
            self:SetText(tostring((FoxChatDB and FoxChatDB.partyMaxSize) or 5))
        end
    end)

    -- 자동 중지 옵션 제거 (더 이상 사용하지 않음)

    -- 광고 채널 선택
    local channelLabel = tab3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    channelLabel:SetPoint("TOPLEFT", cooldownLabel, "BOTTOMLEFT", 0, -25)
    channelLabel:SetText("광고 채널:")

    -- 채널 드롭다운
    local channelDropdown = CreateFrame("Frame", "FoxChatChannelDropdown", tab3, "UIDropDownMenuTemplate")
    channelDropdown:SetPoint("LEFT", channelLabel, "RIGHT", 0, -2)
    UIDropDownMenu_SetWidth(channelDropdown, 150)

    local function ChannelDropdown_Initialize(self)
        -- 현재 참여 중인 채널 목록 가져오기
        local channels = {GetChannelList()}
        local addedChannels = {}

        for i = 1, #channels, 3 do
            local id, name = channels[i], channels[i+1]
            if name then
                -- 채널명 정리 (서버명 제거)
                local cleanName = name
                if string.find(name, "LookingForGroup") then
                    cleanName = "파티찾기"
                elseif string.find(name, "General") or string.find(name, "일반") then
                    cleanName = "공개"
                elseif string.find(name, "Trade") or string.find(name, "거래") then
                    cleanName = "거래"
                elseif string.find(name, "LocalDefense") or string.find(name, "지역방어") then
                    cleanName = "지역방어"
                else
                    -- 사용자 채널 (숫자. 채널명)
                    local customMatch = string.match(name, "%d+%.%s*(.+)")
                    if customMatch then
                        cleanName = customMatch
                    end
                end

                -- 중복 제거
                if not addedChannels[cleanName] then
                    addedChannels[cleanName] = true
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = cleanName
                    info.value = cleanName
                    info.func = function()
                        UIDropDownMenu_SetSelectedValue(channelDropdown, cleanName)
                        UIDropDownMenu_SetText(channelDropdown, cleanName)
                        if FoxChatDB then
                            FoxChatDB.adChannel = cleanName
                        end
                    end
                    UIDropDownMenu_AddButton(info)
                end
            end
        end
    end

    UIDropDownMenu_Initialize(channelDropdown, ChannelDropdown_Initialize)
    local currentChannel = (FoxChatDB and FoxChatDB.adChannel) or "파티찾기"
    UIDropDownMenu_SetSelectedValue(channelDropdown, currentChannel)
    UIDropDownMenu_SetText(channelDropdown, currentChannel)

    -- 광고 시작/중지 버튼
    local adStartButton = CreateFrame("Button", nil, tab3, "UIPanelButtonTemplate")
    adStartButton:SetSize(100, 25)
    adStartButton:SetPoint("LEFT", channelDropdown, "RIGHT", 20, 2)
    adStartButton:SetText((FoxChatDB and FoxChatDB.adEnabled) and "광고 중지" or "광고 시작")

    -- 선입 메시지 알림 활성화 버튼
    local firstComeStartButton = CreateFrame("Button", nil, tab3, "UIPanelButtonTemplate")
    firstComeStartButton:SetSize(170, 25)
    firstComeStartButton:SetPoint("LEFT", adStartButton, "RIGHT", 10, 0)
    firstComeStartButton:SetText((FoxChatDB and FoxChatDB.firstComeEnabled) and "선입 메시지 알림 비활성화" or "선입 메시지 알림 활성화")

    -- 버튼 상태 업데이트 함수
    local function UpdateAdStartButton()
        local message = FoxChatDB and FoxChatDB.adMessage or ""
        local isEmpty = not message or string.gsub(message, "%s+", "") == ""

        if isEmpty then
            -- 메시지가 비어있으면 버튼 비활성화
            adStartButton:Disable()
            adStartButton:SetText("광고 시작")
            if FoxChatDB and FoxChatDB.adEnabled then
                -- 광고가 실행 중이었다면 중단
                FoxChatDB.adEnabled = false
                if FoxChat and FoxChat.UpdateAdButton then
                    FoxChat:UpdateAdButton()
                end
            end
        else
            -- 메시지가 있으면 버튼 활성화
            adStartButton:Enable()
            if FoxChatDB and FoxChatDB.adEnabled then
                adStartButton:SetText("광고 중지")
            else
                adStartButton:SetText("광고 시작")
            end
        end
    end

    -- 초기 버튼 상태 설정
    UpdateAdStartButton()
    tab3.UpdateAdStartButton = UpdateAdStartButton  -- 참조 저장

    adStartButton:SetScript("OnClick", function(self)
        if FoxChatDB then
            -- 목표 인원 체크 제거 - 항상 광고 시작 가능

            FoxChatDB.adEnabled = not FoxChatDB.adEnabled

            -- 광고 시작 시 선입 메시지 알림도 자동 활성화
            if FoxChatDB.adEnabled then
                -- 선입 메시지가 있으면 선입 알림도 활성화
                local firstComeMessage = FoxChatDB.firstComeMessage or ""
                if firstComeMessage ~= "" and string.gsub(firstComeMessage, "%s+", "") ~= "" then
                    FoxChatDB.firstComeEnabled = true
                    -- 선입 버튼 상태 업데이트
                    if tab3.UpdateFirstComeStartButton then
                        tab3.UpdateFirstComeStartButton()
                    end
                    if FoxChat and FoxChat.UpdateFirstComeButton then
                        FoxChat:UpdateFirstComeButton()
                    end
                end
            else
                -- 광고 중지 시 쿨다운 초기화 (선입 알림은 유지)
                if FoxChat and FoxChat.ResetAdCooldown then
                    FoxChat:ResetAdCooldown()
                end
            end

            UpdateAdStartButton()
            if FoxChat and FoxChat.UpdateAdButton then
                FoxChat:UpdateAdButton()
            end
        end
    end)

    -- 선입 메시지 알림 버튼 상태 업데이트 함수
    local function UpdateFirstComeStartButton()
        local message = FoxChatDB and FoxChatDB.firstComeMessage or ""
        local isEmpty = not message or string.gsub(message, "%s+", "") == ""

        if isEmpty then
            -- 메시지가 비어있으면 버튼 비활성화
            firstComeStartButton:Disable()
            firstComeStartButton:SetText("선입 메시지 알림 활성화")
            if FoxChatDB and FoxChatDB.firstComeEnabled then
                -- 선입 알림이 실행 중이었다면 중단
                FoxChatDB.firstComeEnabled = false
                if FoxChat and FoxChat.UpdateFirstComeButton then
                    FoxChat:UpdateFirstComeButton()
                end
            end
        else
            -- 메시지가 있으면 버튼 활성화
            firstComeStartButton:Enable()
            if FoxChatDB and FoxChatDB.firstComeEnabled then
                firstComeStartButton:SetText("선입 메시지 알림 비활성화")
            else
                firstComeStartButton:SetText("선입 메시지 알림 활성화")
            end
        end
    end

    -- 초기 버튼 상태 설정
    UpdateFirstComeStartButton()
    tab3.UpdateFirstComeStartButton = UpdateFirstComeStartButton  -- 참조 저장

    firstComeStartButton:SetScript("OnClick", function(self)
        if FoxChatDB then
            FoxChatDB.firstComeEnabled = not FoxChatDB.firstComeEnabled
            UpdateFirstComeStartButton()
            if FoxChat and FoxChat.UpdateFirstComeButton then
                FoxChat:UpdateFirstComeButton()
            end
        end
    end)

    -- 안내 메시지
    local infoLabel = tab3:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoLabel:SetPoint("TOPLEFT", channelLabel, "BOTTOMLEFT", 0, -25)
    infoLabel:SetText("|cFFFFFF00안내:|r")

    local infoText = tab3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    infoText:SetPoint("TOPLEFT", infoLabel, "BOTTOMLEFT", 0, -5)
    infoText:SetWidth(540)
    infoText:SetHeight(80)
    infoText:SetJustifyH("LEFT")
    infoText:SetJustifyV("TOP")
    tab3.infoText = infoText  -- 참조 저장

    -- 안내 텍스트 업데이트 함수
    local function UpdateInfoText()
        local cooldown = (FoxChatDB and FoxChatDB.adCooldown) or 30
        infoText:SetText(
            "• 광고 버튼을 클릭하면 파티찾기 채널에 메시지가 전송됩니다.\n" ..
            "• " .. cooldown .. "초 쿨다운이 적용되어 스팸을 방지합니다.\n" ..
            "• 파티원수를 0으로 설정하면 (1/13) 같은 인원수를 직접 입력할 수 있습니다.\n" ..
            "• Blizzard EULA 준수: 자동화 없이 수동 클릭만 가능합니다.\n" ..
            "• 광고 버튼은 화면에서 Shift+드래그로 이동할 수 있습니다.\n" ..
            "• |cFFFF7D0A광고 메시지에는 말머리/말꼬리가 적용되지 않습니다.|r"
        )
    end

    -- 초기 텍스트 설정
    UpdateInfoText()
    tab3.UpdateInfoText = UpdateInfoText  -- 참조 저장

    -- =============================================
    -- 탭 4: 자동
    -- =============================================
    local tab4 = tabContents[4]
    configFrame.tab4 = tab4  -- configFrame에 tab4 참조 저장

    -- CreateAutoTab 함수 호출하여 자동 탭 내용 생성
    CreateAutoTab(tab4, configFrame, FoxChatDB, CreateTextArea, CreateSeparator)

    -- =============================================
    -- 하단 버튼들
    -- =============================================

    -- 닫기 버튼
    local closeButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    closeButton:SetSize(80, 25)
    closeButton:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -20, 20)
    closeButton:SetText(L["CLOSE_BUTTON"])
    closeButton:SetScript("OnClick", function()
        configFrame:Hide()
    end)

    -- 테스트 버튼 (채팅 필터링 탭에만 표시)
    local testButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    testButton:SetSize(80, 25)
    testButton:SetPoint("RIGHT", closeButton, "LEFT", -10, 0)
    testButton:SetText(L["TEST_BUTTON"])
    testButton:Hide()  -- 기본적으로 숨김
    testButton:SetScript("OnClick", function()
        -- 테스트 메시지 생성
        local testMsg = "[FoxChat 테스트] 하이라이트 테스트 메시지입니다."
        if FoxChatDB and FoxChatDB.keywords and type(FoxChatDB.keywords) == "table" and #FoxChatDB.keywords > 0 then
            testMsg = testMsg .. " 키워드: " .. FoxChatDB.keywords[1]
        end

        -- 채팅창에 테스트 메시지 표시
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A" .. testMsg .. "|r")

        -- 하이라이트 효과 테스트
        if FoxChat and FoxChat.TestHighlight then
            FoxChat:TestHighlight()
        end
    end)
    configFrame.testButton = testButton  -- 참조 저장

    -- 초기화 버튼
    local resetButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    resetButton:SetSize(80, 25)
    resetButton:SetPoint("RIGHT", testButton, "LEFT", -10, 0)
    resetButton:SetText(L["RESET_BUTTON"])
    resetButton:SetScript("OnClick", function()
        local tabName = {
            [1] = "채팅 필터링",
            [2] = "말머리/말꼬리",
            [3] = "광고 설정",
            [4] = "자동"
        }

        -- 초기화 확인 다이얼로그
        StaticPopupDialogs["FOXCHAT_RESET_CONFIRM"] = {
            text = tabName[currentTab] .. " 설정을 초기화하시겠습니까?\n해당 탭의 설정만 기본값으로 되돌아갑니다.",
            button1 = "확인",
            button2 = "취소",
            OnAccept = function()
                if not FoxChatDB then FoxChatDB = {} end

                -- 탭별로 초기화
                if currentTab == 1 then
                    -- 채팅 필터링 초기화
                    FoxChatDB.enabled = true
                    FoxChatDB.keywords = {}
                    FoxChatDB.ignoreKeywords = {}
                    FoxChatDB.soundEnabled = true
                    FoxChatDB.minimapButtonEnabled = true
                    FoxChatDB.highlightStyle = "both"
                    FoxChatDB.toastPosition = {x = 0, y = -320}
                    FoxChatDB.highlightColors = {
                        GUILD = {r = 0, g = 1, b = 0},
                        PUBLIC = {r = 1, g = 1, b = 0},
                        PARTY_RAID = {r = 0, g = 0.5, b = 1},
                        LFG = {r = 1, g = 0.5, b = 0},
                    }
                elseif currentTab == 2 then
                    -- 말머리/말꼬리 초기화
                    FoxChatDB.prefixSuffixEnabled = false
                    FoxChatDB.channelPrefixSuffix = {
                        SAY = {prefix = ""},       -- 일반 대화
                        YELL = {prefix = ""},      -- 외치기
                        LFG = {prefix = ""},       -- 파티찾기 채널
                        TRADE = {prefix = ""},     -- 거래 채널
                        GUILD = {prefix = ""},     -- 길드
                        GROUP = {prefix = ""},     -- 파티/공대
                        WHISPER = {prefix = ""}    -- 귓속말
                    }
                    FoxChatDB.suffix = ""
                    FoxChatDB.prefixSuffixChannels = {
                        SAY = true,
                        YELL = false,
                        PARTY = true,
                        GUILD = true,
                        RAID = true,
                        INSTANCE_CHAT = true,
                        WHISPER = false,
                        CHANNEL = false,
                    }
                elseif currentTab == 3 then
                    -- 광고 설정 초기화
                    FoxChatDB.adEnabled = false
                    FoxChatDB.adMessage = ""
                    FoxChatDB.adPosition = {x = 350, y = -150}
                    FoxChatDB.adCooldown = 15
                    FoxChatDB.adChannel = "파티찾기"
                elseif currentTab == 4 then
                    -- 자동 탭 초기화
                    FoxChatDB.autoTrade = true
                    FoxChatDB.autoPartyGreetMyJoin = false
                    FoxChatDB.autoPartyGreetOthersJoin = false
                    FoxChatDB.partyGreetMyJoinMessages = {
                        "안녕하세요! {me}입니다. 잘 부탁드려요!",
                        "반갑습니다~ 함께 모험해요!",
                        "파티 초대 감사합니다!"
                    }
                    FoxChatDB.partyGreetOthersJoinMessages = {
                        "{target}님 환영합니다!",
                        "{target}님 반갑습니다~",
                        "어서오세요 {target}님!"
                    }
                    -- AFK/DND 자동응답 초기화
                    FoxChatDB.autoReplyAFK = false
                    FoxChatDB.autoReplyCombat = false
                    FoxChatDB.autoReplyInstance = false
                    FoxChatDB.combatReplyMessage = "[자동응답] 전투 중입니다. 잠시 후 답변드리겠습니다!"
                    FoxChatDB.instanceReplyMessage = "[자동응답] 인던 중입니다. 나중에 답변드리겠습니다!"
                    FoxChatDB.autoReplyCooldown = 5
                    -- 주사위 집계 초기화
                    FoxChatDB.rollTrackerEnabled = false
                    FoxChatDB.rollSessionDuration = 20
                    FoxChatDB.rollTopK = 0
                end

                -- UI 업데이트
                if configFrame.RefreshUI then
                    configFrame:RefreshUI()
                end

                -- 메시지 표시
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r " .. tabName[currentTab] .. " 설정이 초기화되었습니다.")
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }
        StaticPopup_Show("FOXCHAT_RESET_CONFIRM")
    end)

    -- X 버튼 (우측 상단)
    local xButton = CreateFrame("Button", nil, configFrame, "UIPanelCloseButton")
    xButton:SetPoint("TOPRIGHT", configFrame, "TOPRIGHT", -5, -5)
    xButton:SetScript("OnClick", function()
        configFrame:Hide()
    end)

    -- ESC 키로 닫기
    tinsert(UISpecialFrames, "FoxChatConfigFrame")

    -- =============================================
    -- 초기 탭 선택
    -- =============================================
    local initialTab = (FoxChatDB and FoxChatDB.lastTab) or 1
    SwitchToTab(initialTab)

    -- UI 업데이트 함수
    local function RefreshUI()
        -- 탭 1 - 채팅 필터링 업데이트
        if filterEnabledCheckbox then
            filterEnabledCheckbox:SetChecked(FoxChatDB and FoxChatDB.enabled)
        end
        if soundEnabledCheckbox then
            soundEnabledCheckbox:SetChecked(FoxChatDB and FoxChatDB.soundEnabled)
        end
        if minimapButtonCheckbox then
            minimapButtonCheckbox:SetChecked(FoxChatDB and FoxChatDB.minimapButtonEnabled)
        end
        if keywordsEditBox then
            local keywordText = ""
            if FoxChatDB and FoxChatDB.keywords then
                if type(FoxChatDB.keywords) == "table" then
                    keywordText = table.concat(FoxChatDB.keywords, ", ")
                else
                    keywordText = tostring(FoxChatDB.keywords)
                end
            end
            keywordsEditBox:SetText(keywordText)
        end
        if ignoreKeywordsEditBox then
            local ignoreText = ""
            if FoxChatDB and FoxChatDB.ignoreKeywords then
                if type(FoxChatDB.ignoreKeywords) == "table" then
                    ignoreText = table.concat(FoxChatDB.ignoreKeywords, ", ")
                else
                    ignoreText = tostring(FoxChatDB.ignoreKeywords)
                end
            end
            ignoreKeywordsEditBox:SetText(ignoreText)
        end

        -- 탭 2 - 말머리/말꼬리 업데이트
        if prefixSuffixEnabledCheckbox then
            prefixSuffixEnabledCheckbox:SetChecked(FoxChatDB and FoxChatDB.prefixSuffixEnabled == true)
        end
        -- 채널별 말머리 업데이트는 각 EditBox의 초기화 시점에 처리됨
        -- 공통 말꼬리 업데이트
        if suffixEditBox then
            suffixEditBox:SetText((FoxChatDB and FoxChatDB.suffix) or "")
        end

        -- 탭 3 - 광고 설정 업데이트
        if adMessageEditBox then
            adMessageEditBox:SetText((FoxChatDB and FoxChatDB.adMessage) or "")
        end
        -- 쿨타임 드롭다운 업데이트
        local cooldownDropdown = _G["FoxChatCooldownDropdown"]
        if cooldownDropdown then
            local currentCooldown = (FoxChatDB and FoxChatDB.adCooldown) or 15
            UIDropDownMenu_SetSelectedValue(cooldownDropdown, currentCooldown)
            UIDropDownMenu_SetText(cooldownDropdown, currentCooldown .. "초")
        end
        -- 채널 드롭다운 업데이트
        local channelDropdown = _G["FoxChatChannelDropdown"]
        if channelDropdown then
            local currentChannel = (FoxChatDB and FoxChatDB.adChannel) or "파티찾기"
            UIDropDownMenu_SetSelectedValue(channelDropdown, currentChannel)
            UIDropDownMenu_SetText(channelDropdown, currentChannel)
        end
        -- 안내 텍스트 업데이트
        if tabContents and tabContents[3] and tabContents[3].UpdateInfoText then
            tabContents[3].UpdateInfoText()
        end

        -- 탭 4 - 자동 탭 업데이트
        -- 거래
        if configFrame.tradeAutoCheckbox then
            configFrame.tradeAutoCheckbox:SetChecked(FoxChatDB and FoxChatDB.autoTrade ~= false)
        end

        -- 인사
        if configFrame.myJoinCheckbox then
            configFrame.myJoinCheckbox:SetChecked(FoxChatDB and FoxChatDB.autoPartyGreetMyJoin)
        end
        if configFrame.othersJoinCheckbox then
            configFrame.othersJoinCheckbox:SetChecked(FoxChatDB and FoxChatDB.autoPartyGreetOthersJoin)
        end

        -- 응답
        if configFrame.autoReplyAFKCheckbox then
            configFrame.autoReplyAFKCheckbox:SetChecked(FoxChatDB and FoxChatDB.autoReplyAFK)
        end
        if configFrame.autoReplyCombatCheckbox then
            configFrame.autoReplyCombatCheckbox:SetChecked(FoxChatDB and FoxChatDB.autoReplyCombat)
        end
        if configFrame.combatMsgEditBox then
            configFrame.combatMsgEditBox:SetText((FoxChatDB and FoxChatDB.combatReplyMessage) or "[자동응답] 전투 중입니다. 잠시 후 답변드리겠습니다!")
        end
        if configFrame.autoReplyInstanceCheckbox then
            configFrame.autoReplyInstanceCheckbox:SetChecked(FoxChatDB and FoxChatDB.autoReplyInstance)
        end
        if configFrame.instanceMsgEditBox then
            configFrame.instanceMsgEditBox:SetText((FoxChatDB and FoxChatDB.instanceReplyMessage) or "[자동응답] 인던 중입니다. 나중에 답변드리겠습니다!")
        end
        if configFrame.autoReplyCooldownEditBox then
            configFrame.autoReplyCooldownEditBox:SetText((FoxChatDB and FoxChatDB.autoReplyCooldown) or "5")
        end

        -- 주사위
        if configFrame.rollTrackerEnabledCheckbox then
            configFrame.rollTrackerEnabledCheckbox:SetChecked(FoxChatDB and FoxChatDB.rollTrackerEnabled)
        end
        if configFrame.rollDurationEditBox then
            configFrame.rollDurationEditBox:SetText(tostring((FoxChatDB and FoxChatDB.rollSessionDuration) or 20))
        end
        if configFrame.rollWinnerOnlyRadio and configFrame.rollTopKRadio then
            if FoxChatDB and FoxChatDB.rollTopK and FoxChatDB.rollTopK > 0 then
                configFrame.rollTopKRadio:SetChecked(true)
                configFrame.rollWinnerOnlyRadio:SetChecked(false)
            else
                configFrame.rollWinnerOnlyRadio:SetChecked(true)
                configFrame.rollTopKRadio:SetChecked(false)
            end
        end
        if configFrame.rollTopKEditBox then
            configFrame.rollTopKEditBox:SetText(tostring((FoxChatDB and FoxChatDB.rollTopK) or 3))
        end
    end

    -- 초기 UI 업데이트
    configFrame.RefreshUI = RefreshUI
    RefreshUI()

    configFrame:Show()
end

-- 디버그용: 새 탭 UI 테스트 명령어
SLASH_FOXCHATTAB1 = "/fctab"
SlashCmdList["FOXCHATTAB"] = function(msg)
    FoxChat:ShowConfig()
end