local addonName, addon = ...
local L = addon.L

-- 채팅 필터링 탭의 새로운 UI 구현 (채널별 필터링)
local function CreateChatFilterTab(tab1, FoxChatDB, CreateTextArea, CreateSeparator)
    -- =============================================
    -- Phase 1: 공통 설정 영역 (상단)
    -- =============================================

    -- 첫 번째 줄: 주요 체크박스들
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

    -- 두 번째 줄: 토스트 설정
    local toastLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toastLabel:SetPoint("TOPLEFT", filterEnabledCheckbox, "BOTTOMLEFT", 0, -20)
    toastLabel:SetText("토스트 위치:")

    -- X 좌표
    local toastXLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    toastXLabel:SetPoint("LEFT", toastLabel, "RIGHT", 10, 0)
    toastXLabel:SetText("X:")

    local toastXEdit = CreateFrame("EditBox", nil, tab1, "BackdropTemplate")
    toastXEdit:SetSize(60, 20)
    toastXEdit:SetPoint("LEFT", toastXLabel, "RIGHT", 5, 0)
    toastXEdit:SetFontObject("GameFontHighlight")
    toastXEdit:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 1,
    })
    toastXEdit:SetBackdropColor(0, 0, 0, 0.5)
    toastXEdit:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    toastXEdit:SetAutoFocus(false)
    toastXEdit:SetNumeric(false)  -- 숫자만 허용하는 제한 해제 (음수 및 부호 허용)
    toastXEdit:SetMaxLetters(6)
    toastXEdit:SetText(tostring((FoxChatDB and FoxChatDB.toastPosition and FoxChatDB.toastPosition.x) or 0))

    -- Y 좌표
    local toastYLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    toastYLabel:SetPoint("LEFT", toastXEdit, "RIGHT", 15, 0)
    toastYLabel:SetText("Y:")

    local toastYEdit = CreateFrame("EditBox", nil, tab1, "BackdropTemplate")
    toastYEdit:SetSize(60, 20)
    toastYEdit:SetPoint("LEFT", toastYLabel, "RIGHT", 5, 0)
    toastYEdit:SetFontObject("GameFontHighlight")
    toastYEdit:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 1,
    })
    toastYEdit:SetBackdropColor(0, 0, 0, 0.5)
    toastYEdit:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    toastYEdit:SetAutoFocus(false)
    toastYEdit:SetNumeric(false)  -- 숫자만 허용하는 제한 해제 (음수 및 부호 허용)
    toastYEdit:SetMaxLetters(6)

    -- Y 값 설정 (음수 기본값 보장)
    local yPos = -300  -- 기본값
    if FoxChatDB and FoxChatDB.toastPosition and FoxChatDB.toastPosition.y then
        yPos = FoxChatDB.toastPosition.y
    end
    toastYEdit:SetText(tostring(yPos))

    -- 토스트 위치 저장 및 유효성 검사
    local function SaveToastPosition()
        if FoxChatDB then
            FoxChatDB.toastPosition = FoxChatDB.toastPosition or {}
            local xValue = tonumber(toastXEdit:GetText())
            local yValue = tonumber(toastYEdit:GetText())

            -- 유효한 숫자인지 확인 및 범위 제한
            if xValue then
                FoxChatDB.toastPosition.x = math.max(-800, math.min(800, xValue))
                toastXEdit:SetText(tostring(FoxChatDB.toastPosition.x))
            else
                toastXEdit:SetText(tostring(FoxChatDB.toastPosition.x or 0))
            end

            if yValue then
                FoxChatDB.toastPosition.y = math.max(-600, math.min(600, yValue))
                toastYEdit:SetText(tostring(FoxChatDB.toastPosition.y))
            else
                toastYEdit:SetText(tostring(FoxChatDB.toastPosition.y or -300))
            end
        end
    end

    toastXEdit:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        SaveToastPosition()
    end)
    toastXEdit:SetScript("OnEditFocusLost", SaveToastPosition)

    toastYEdit:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        SaveToastPosition()
    end)
    toastYEdit:SetScript("OnEditFocusLost", SaveToastPosition)

    -- 토스트 표시 시간 드롭다운
    local toastDurationLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toastDurationLabel:SetPoint("LEFT", toastYEdit, "RIGHT", 30, 0)
    toastDurationLabel:SetText("표시 시간:")

    local toastDurationDropdown = CreateFrame("Frame", "FoxChatToastDurationDropdown", tab1, "UIDropDownMenuTemplate")
    toastDurationDropdown:SetPoint("LEFT", toastDurationLabel, "RIGHT", -10, -2)
    UIDropDownMenu_SetWidth(toastDurationDropdown, 60)

    -- 드롭다운 초기화 함수
    local function InitializeToastDurationDropdown(self)
        local durations = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
        for _, duration in ipairs(durations) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = duration .. "초"
            info.value = duration
            info.func = function()
                if FoxChatDB then
                    FoxChatDB.toastDuration = duration
                    UIDropDownMenu_SetSelectedValue(toastDurationDropdown, duration)
                    UIDropDownMenu_SetText(toastDurationDropdown, duration .. "초")
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end

    UIDropDownMenu_Initialize(toastDurationDropdown, InitializeToastDurationDropdown)

    -- 초기값 설정 (기본값 5초)
    local currentDuration = (FoxChatDB and FoxChatDB.toastDuration) or 5
    UIDropDownMenu_SetSelectedValue(toastDurationDropdown, currentDuration)
    UIDropDownMenu_SetText(toastDurationDropdown, currentDuration .. "초")

    -- 좌표 시스템 설명 (토스트 레이블 아래 줄에 왼쪽 정렬)
    local coordHelp = tab1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    coordHelp:SetPoint("TOPLEFT", toastLabel, "BOTTOMLEFT", 0, -5)
    coordHelp:SetText("|cFFAAAAAA좌표 설명: (0,0) = 화면 중앙, X: 좌측(-) 우측(+), Y: 위(-) 아래(+)|r")

    -- 강조 스타일 설정 (좌표 설명 아래에 왼쪽 정렬)
    local highlightLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    highlightLabel:SetPoint("TOPLEFT", coordHelp, "BOTTOMLEFT", 0, -15)
    highlightLabel:SetText("강조 스타일:")

    -- 굵게 라디오 버튼
    local boldRadio = CreateFrame("CheckButton", nil, tab1, "UIRadioButtonTemplate")
    boldRadio:SetPoint("LEFT", highlightLabel, "RIGHT", 10, 0)
    boldRadio:SetSize(20, 20)
    local boldLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    boldLabel:SetPoint("LEFT", boldRadio, "RIGHT", 5, 0)
    boldLabel:SetText("굵게")

    -- 색상만 라디오 버튼
    local colorRadio = CreateFrame("CheckButton", nil, tab1, "UIRadioButtonTemplate")
    colorRadio:SetPoint("LEFT", boldLabel, "RIGHT", 20, 0)
    colorRadio:SetSize(20, 20)
    local colorLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colorLabel:SetPoint("LEFT", colorRadio, "RIGHT", 5, 0)
    colorLabel:SetText("색상만")

    -- 굵게 + 색상 라디오 버튼
    local bothRadio = CreateFrame("CheckButton", nil, tab1, "UIRadioButtonTemplate")
    bothRadio:SetPoint("LEFT", colorLabel, "RIGHT", 20, 0)
    bothRadio:SetSize(20, 20)
    local bothLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bothLabel:SetPoint("LEFT", bothRadio, "RIGHT", 5, 0)
    bothLabel:SetText("굵게 + 색상")

    -- 초기값 설정
    local currentStyle = (FoxChatDB and FoxChatDB.highlightStyle) or "both"
    if currentStyle == "bold" then
        boldRadio:SetChecked(true)
    elseif currentStyle == "color" then
        colorRadio:SetChecked(true)
    else
        bothRadio:SetChecked(true)
    end

    -- 라디오 버튼 이벤트 처리
    boldRadio:SetScript("OnClick", function()
        boldRadio:SetChecked(true)
        colorRadio:SetChecked(false)
        bothRadio:SetChecked(false)
        FoxChatDB.highlightStyle = "bold"
    end)

    colorRadio:SetScript("OnClick", function()
        boldRadio:SetChecked(false)
        colorRadio:SetChecked(true)
        bothRadio:SetChecked(false)
        FoxChatDB.highlightStyle = "color"
    end)

    bothRadio:SetScript("OnClick", function()
        boldRadio:SetChecked(false)
        colorRadio:SetChecked(false)
        bothRadio:SetChecked(true)
        FoxChatDB.highlightStyle = "both"
    end)

    -- 토스트 테스트 버튼
    local toastTestButton = CreateFrame("Button", nil, tab1, "UIPanelButtonTemplate")
    toastTestButton:SetSize(80, 22)
    toastTestButton:SetPoint("LEFT", toastDurationDropdown, "RIGHT", 10, 2)
    toastTestButton:SetText("테스트")
    toastTestButton:SetScript("OnClick", function()
        -- 설정 값 즉시 저장
        SaveToastPosition()

        -- 토스트 미리보기 표시
        if addon.ShowToastPreview then
            addon.ShowToastPreview(FoxChatDB.toastDuration or 5)
        end
    end)

    -- 구분선 (강조 스타일 라디오 버튼 아래로 이동)
    local separator1 = CreateSeparator(tab1)
    separator1:SetPoint("TOPLEFT", highlightLabel, "BOTTOMLEFT", -10, -30)
    separator1:SetPoint("RIGHT", tab1, "RIGHT", -10, 0)

    -- =============================================
    -- Phase 2: 채널별 필터링 설정 영역 (하단)
    -- =============================================

    -- 좌측 메뉴 패널
    local leftMenuPanel = CreateFrame("Frame", nil, tab1, "BackdropTemplate")
    leftMenuPanel:SetSize(100, 280)
    leftMenuPanel:SetPoint("TOPLEFT", separator1, "BOTTOMLEFT", 10, -10)
    leftMenuPanel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 1,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })
    leftMenuPanel:SetBackdropColor(0.1, 0.1, 0.1, 0.3)

    -- 우측 컨텐츠 패널
    local rightContentPanel = CreateFrame("Frame", nil, tab1)
    rightContentPanel:SetSize(530, 280)
    rightContentPanel:SetPoint("TOPLEFT", leftMenuPanel, "TOPRIGHT", 5, 0)

    -- 채널 메뉴 데이터
    local channels = {
        {id = "LFG", name = "파티찾기"},
        {id = "PARTY", name = "파티/공격대"},
        {id = "GUILD", name = "길드"},
        {id = "SAY", name = "공개"},
        {id = "TRADE", name = "거래"}
    }

    local menuButtons = {}
    local contentFrames = {}
    local currentChannel = "LFG"

    -- 채널별 컨텐츠 생성 함수
    local function CreateChannelContent(parent, channel)
        local frame = CreateFrame("Frame", nil, parent)
        frame:SetAllPoints()
        frame:Hide()

        -- 채널 필터링 사용 체크박스
        local enableCheckbox = CreateFrame("CheckButton", nil, frame)
        enableCheckbox:SetSize(24, 24)
        enableCheckbox:SetPoint("TOPLEFT", 10, -10)
        enableCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        enableCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        enableCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
        enableCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

        local enableLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        enableLabel:SetPoint("LEFT", enableCheckbox, "RIGHT", 5, 0)
        enableLabel:SetText(channel.name .. " 채널 필터링 사용")

        -- 필터링 문구 라벨
        local keywordsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        keywordsLabel:SetPoint("TOPLEFT", enableCheckbox, "BOTTOMLEFT", 0, -20)
        keywordsLabel:SetText("필터링 문구:")

        local keywordsHelp = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        keywordsHelp:SetPoint("TOPLEFT", keywordsLabel, "BOTTOMLEFT", 0, -3)
        keywordsHelp:SetText("강조할 단어를 입력 (쉼표로 구분)")

        -- 필터링 문구 TextArea
        local keywordsBackground, keywordsEditBox = CreateTextArea(frame, 510, 80, 500)
        keywordsBackground:SetPoint("TOPLEFT", keywordsHelp, "BOTTOMLEFT", 0, -5)

        -- 무시할 문구 라벨
        local ignoreLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        ignoreLabel:SetPoint("TOPLEFT", keywordsBackground, "BOTTOMLEFT", 0, -20)
        ignoreLabel:SetText("무시할 문구:")

        local ignoreHelp = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        ignoreHelp:SetPoint("TOPLEFT", ignoreLabel, "BOTTOMLEFT", 0, -3)
        ignoreHelp:SetText("이 단어가 포함된 메시지는 필터링 안함 (쉼표로 구분)")

        -- 무시할 문구 TextArea
        local ignoreBackground, ignoreEditBox = CreateTextArea(frame, 510, 80, 500)
        ignoreBackground:SetPoint("TOPLEFT", ignoreHelp, "BOTTOMLEFT", 0, -5)

        -- 데이터 로드 및 저장
        if FoxChatDB and FoxChatDB.channelFilters and FoxChatDB.channelFilters[channel.id] then
            local channelFilter = FoxChatDB.channelFilters[channel.id]
            enableCheckbox:SetChecked(channelFilter.enabled)
            keywordsEditBox:SetText(channelFilter.keywords or "")
            ignoreEditBox:SetText(channelFilter.ignoreKeywords or "")
        end

        -- 이벤트 핸들러
        enableCheckbox:SetScript("OnClick", function(self)
            if FoxChatDB and FoxChatDB.channelFilters and FoxChatDB.channelFilters[channel.id] then
                FoxChatDB.channelFilters[channel.id].enabled = self:GetChecked()
            end
        end)

        keywordsEditBox:SetScript("OnTextChanged", function(self, user)
            if user and FoxChatDB and FoxChatDB.channelFilters and FoxChatDB.channelFilters[channel.id] then
                FoxChatDB.channelFilters[channel.id].keywords = self:GetText() or ""
            end
        end)

        ignoreEditBox:SetScript("OnTextChanged", function(self, user)
            if user and FoxChatDB and FoxChatDB.channelFilters and FoxChatDB.channelFilters[channel.id] then
                FoxChatDB.channelFilters[channel.id].ignoreKeywords = self:GetText() or ""
            end
        end)

        return frame
    end

    -- 각 채널별 메뉴 버튼 생성
    for i, channel in ipairs(channels) do
        local button = CreateFrame("Button", nil, leftMenuPanel)
        button:SetSize(96, 30)
        button:SetPoint("TOPLEFT", leftMenuPanel, "TOPLEFT", 2, -10 - (i-1) * 35)

        local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("CENTER")
        text:SetText(channel.name)
        button.text = text

        -- 호버 효과
        local highlight = button:CreateTexture(nil, "BACKGROUND")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 1, 1, 0.1)
        highlight:Hide()
        button.highlight = highlight

        -- 선택 효과
        local selected = button:CreateTexture(nil, "BACKGROUND")
        selected:SetAllPoints()
        selected:SetColorTexture(0.8, 0.6, 0.2, 0.3)
        selected:Hide()
        button.selected = selected

        button:SetScript("OnEnter", function(self)
            if currentChannel ~= channel.id then
                self.highlight:Show()
            end
        end)

        button:SetScript("OnLeave", function(self)
            self.highlight:Hide()
        end)

        -- 클릭 이벤트
        button:SetScript("OnClick", function(self)
            -- 모든 버튼 초기화
            for _, btn in pairs(menuButtons) do
                btn.selected:Hide()
                btn.text:SetTextColor(1, 1, 1, 1)
            end

            -- 현재 버튼 선택
            self.selected:Show()
            self.text:SetTextColor(1, 0.82, 0, 1)

            -- 컨텐츠 전환
            for _, frame in pairs(contentFrames) do
                frame:Hide()
            end
            if contentFrames[channel.id] then
                contentFrames[channel.id]:Show()
            end
            currentChannel = channel.id
        end)

        menuButtons[channel.id] = button

        -- 각 채널별 컨텐츠 프레임 생성
        contentFrames[channel.id] = CreateChannelContent(rightContentPanel, channel)
    end

    -- 첫 번째 채널 선택
    if menuButtons["GUILD"] then
        menuButtons["GUILD"]:GetScript("OnClick")(menuButtons["GUILD"])
    end

    -- OnShow 이벤트: 설정창이 열릴 때 값 갱신
    tab1:SetScript("OnShow", function()
        -- 토스트 위치 값 갱신
        if FoxChatDB and FoxChatDB.toastPosition then
            toastXEdit:SetText(tostring(FoxChatDB.toastPosition.x or 0))
            toastYEdit:SetText(tostring(FoxChatDB.toastPosition.y or -300))
        else
            toastXEdit:SetText("0")
            toastYEdit:SetText("-300")
        end

        -- 토스트 표시 시간 갱신
        local duration = (FoxChatDB and FoxChatDB.toastDuration) or 5
        UIDropDownMenu_SetText(toastDurationDropdown, duration .. "초")

        -- 체크박스 상태 갱신
        filterEnabledCheckbox:SetChecked(FoxChatDB and FoxChatDB.filterEnabled)
        soundCheckbox:SetChecked(FoxChatDB and FoxChatDB.playSound)
        minimapCheckbox:SetChecked(FoxChatDB and FoxChatDB.minimapButton and not FoxChatDB.minimapButton.hide)

        -- 강조 스타일 라디오 버튼 갱신
        local currentStyle = (FoxChatDB and FoxChatDB.highlightStyle) or "both"
        boldRadio:SetChecked(currentStyle == "bold")
        colorRadio:SetChecked(currentStyle == "color")
        bothRadio:SetChecked(currentStyle == "both")
    end)

    return tab1
end

-- 외부에서 호출할 수 있도록 export
addon.CreateChatFilterTab = CreateChatFilterTab