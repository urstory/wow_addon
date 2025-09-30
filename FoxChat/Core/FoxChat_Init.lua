local addonName, addon = ...

-- 초기화 통합 모듈 (로딩 순서 관리)
FoxChat = FoxChat or {}
FoxChat.Init = {}

local Init = FoxChat.Init

-- 초기화 단계들
local initSteps = {
    -- 1단계: 코어 시스템
    {
        name = "Core Systems",
        modules = {
            "Events",
            "Core",
            "ChatHook"
        },
        init = function()
            if FoxChat.Events then
                FoxChat.Events:Initialize()
            end
            if FoxChat.Core then
                FoxChat.Core:Initialize()
            end
            if FoxChat.Core and FoxChat.Core.ChatHook then
                FoxChat.Core.ChatHook:Initialize()
            end
        end
    },

    -- 2단계: 유틸리티
    {
        name = "Utilities",
        modules = {
            "UTF8",
            "Common"
        },
        init = function()
            -- 유틸리티는 별도 초기화 불필요
            FoxChat:Debug("유틸리티 모듈 로드 완료")
        end
    },

    -- 3단계: 기능 모듈
    {
        name = "Features",
        modules = {
            "KeywordFilter",
            "PrefixSuffix",
            "Advertisement",
            "AutoTrade",
            "AutoGreeting",
            "AutoReply",
            "FirstCome"
        },
        init = function()
            local features = FoxChat.Features
            if features then
                if features.KeywordFilter then
                    features.KeywordFilter:Initialize()
                end
                if features.PrefixSuffix then
                    features.PrefixSuffix:Initialize()
                end
                if features.Advertisement then
                    features.Advertisement:Initialize()
                end
                if features.AutoTrade then
                    features.AutoTrade:Initialize()
                end
                if features.AutoGreeting then
                    features.AutoGreeting:Initialize()
                end
                if features.AutoReply then
                    features.AutoReply:Initialize()
                end
                if features.FirstCome then
                    features.FirstCome:Initialize()
                end
            end
        end
    },

    -- 4단계: UI 컴포넌트
    {
        name = "UI Components",
        modules = {
            "Toast",
            "MinimapButton",
            "AdButton",
            "FirstComeButton"
        },
        init = function()
            local ui = FoxChat.UI
            if ui then
                if ui.Toast then
                    ui.Toast:Initialize()
                end
                if ui.MinimapButton then
                    ui.MinimapButton:Initialize()
                end
                if ui.AdButton then
                    ui.AdButton:Initialize()
                end
                if ui.FirstComeButton then
                    ui.FirstComeButton:Initialize()
                end
            end
        end
    },

    -- 5단계: 설정 UI
    {
        name = "Config UI",
        modules = {
            "Components",
            "TabSystem",
            "ConfigMain"
        },
        init = function()
            local ui = FoxChat.UI
            if ui then
                if ui.Components then
                    -- Components는 별도 초기화 불필요
                end
                if ui.TabSystem then
                    ui.TabSystem:Initialize()
                end
                if ui.Config then
                    ui.Config:Initialize()
                end
            end
        end
    }
}

-- 메인 초기화 함수
function Init:Initialize()
    FoxChat:Print("FoxChat 초기화 시작...")

    -- 단계별 초기화
    for i, step in ipairs(initSteps) do
        FoxChat:Debug(string.format("초기화 단계 %d: %s", i, step.name))

        -- 모듈 확인
        local allModulesLoaded = true
        for _, moduleName in ipairs(step.modules) do
            if not self:CheckModule(moduleName) then
                FoxChat:Print(string.format("경고: %s 모듈이 로드되지 않았습니다.", moduleName))
                allModulesLoaded = false
            end
        end

        -- 초기화 실행
        if allModulesLoaded and step.init then
            local success, err = pcall(step.init)
            if not success then
                FoxChat:Print(string.format("오류: %s 초기화 실패 - %s", step.name, err))
            else
                FoxChat:Debug(string.format("%s 초기화 완료", step.name))
            end
        end
    end

    -- 초기화 완료 이벤트
    if FoxChat.Events then
        FoxChat.Events:Trigger("FOXCHAT_INIT_COMPLETE")
    end

    FoxChat:Print("FoxChat 초기화 완료!")
end

-- 모듈 체크 함수
function Init:CheckModule(moduleName)
    if moduleName == "Events" then
        return FoxChat.Events ~= nil
    elseif moduleName == "Core" then
        return FoxChat.Core ~= nil
    elseif moduleName == "ChatHook" then
        return FoxChat.Core and FoxChat.Core.ChatHook ~= nil
    elseif moduleName == "UTF8" then
        return FoxChat.Utils and FoxChat.Utils.UTF8 ~= nil
    elseif moduleName == "Common" then
        return FoxChat.Utils and FoxChat.Utils.Common ~= nil
    elseif moduleName == "KeywordFilter" then
        return FoxChat.Features and FoxChat.Features.KeywordFilter ~= nil
    elseif moduleName == "PrefixSuffix" then
        return FoxChat.Features and FoxChat.Features.PrefixSuffix ~= nil
    elseif moduleName == "Advertisement" then
        return FoxChat.Features and FoxChat.Features.Advertisement ~= nil
    elseif moduleName == "AutoTrade" then
        return FoxChat.Features and FoxChat.Features.AutoTrade ~= nil
    elseif moduleName == "AutoGreeting" then
        return FoxChat.Features and FoxChat.Features.AutoGreeting ~= nil
    elseif moduleName == "AutoReply" then
        return FoxChat.Features and FoxChat.Features.AutoReply ~= nil
    elseif moduleName == "FirstCome" then
        return FoxChat.Features and FoxChat.Features.FirstCome ~= nil
    elseif moduleName == "Toast" then
        return FoxChat.UI and FoxChat.UI.Toast ~= nil
    elseif moduleName == "MinimapButton" then
        return FoxChat.UI and FoxChat.UI.MinimapButton ~= nil
    elseif moduleName == "AdButton" then
        return FoxChat.UI and FoxChat.UI.AdButton ~= nil
    elseif moduleName == "FirstComeButton" then
        return FoxChat.UI and FoxChat.UI.FirstComeButton ~= nil
    elseif moduleName == "Components" then
        return FoxChat.UI and FoxChat.UI.Components ~= nil
    elseif moduleName == "TabSystem" then
        return FoxChat.UI and FoxChat.UI.TabSystem ~= nil
    elseif moduleName == "ConfigMain" then
        return FoxChat.UI and FoxChat.UI.Config ~= nil
    end

    return false
end

-- 리로드 함수
function Init:Reload()
    FoxChat:Print("FoxChat 모듈 리로드 시작...")

    -- 기존 모듈 정리
    if FoxChat.Events then
        FoxChat.Events:Trigger("FOXCHAT_MODULE_UNLOAD")
    end

    -- 재초기화
    self:Initialize()

    -- 리로드 완료 이벤트
    if FoxChat.Events then
        FoxChat.Events:Trigger("FOXCHAT_MODULE_RELOAD")
    end

    FoxChat:Print("FoxChat 모듈 리로드 완료!")
end

-- 애드온 로드 이벤트 처리
local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("ADDON_LOADED")
loadFrame:RegisterEvent("PLAYER_LOGIN")

loadFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- 초기 설정 로드
        FoxChatDB = FoxChatDB or {}
        FoxChatCharDB = FoxChatCharDB or {}

        -- 기본값 설정
        Init:SetDefaults()

    elseif event == "PLAYER_LOGIN" then
        -- 플레이어 로그인 후 초기화
        C_Timer.After(1, function()
            Init:Initialize()
        end)

        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

-- 기본값 설정
function Init:SetDefaults()
    -- 전역 설정 기본값
    FoxChatDB.enabled = FoxChatDB.enabled ~= false
    FoxChatDB.filterEnabled = FoxChatDB.filterEnabled ~= false
    FoxChatDB.prefixSuffixEnabled = FoxChatDB.prefixSuffixEnabled == true
    FoxChatDB.playSound = FoxChatDB.playSound ~= false
    FoxChatDB.soundVolume = FoxChatDB.soundVolume or 0.5

    -- 채널 그룹 기본값
    FoxChatDB.channelGroups = FoxChatDB.channelGroups or {}
    FoxChatDB.channelGroups.GUILD = FoxChatDB.channelGroups.GUILD ~= false
    FoxChatDB.channelGroups.PUBLIC = FoxChatDB.channelGroups.PUBLIC ~= false
    FoxChatDB.channelGroups.PARTY_RAID = FoxChatDB.channelGroups.PARTY_RAID ~= false
    FoxChatDB.channelGroups.LFG = FoxChatDB.channelGroups.LFG ~= false

    -- 미니맵 버튼 기본값
    FoxChatDB.minimapButton = FoxChatDB.minimapButton or {}
    FoxChatDB.minimapButton.hide = FoxChatDB.minimapButton.hide or false
    FoxChatDB.minimapButton.minimapPos = FoxChatDB.minimapButton.minimapPos or 180
    FoxChatDB.minimapButton.radius = FoxChatDB.minimapButton.radius or 80

    -- 자동 기능 기본값
    FoxChatDB.autoPartyGreetMyJoin = FoxChatDB.autoPartyGreetMyJoin or false
    FoxChatDB.autoPartyGreetOthersJoin = FoxChatDB.autoPartyGreetOthersJoin or false
    FoxChatDB.autoReplyAFK = FoxChatDB.autoReplyAFK or false
    FoxChatDB.autoReplyCombat = FoxChatDB.autoReplyCombat or false
    FoxChatDB.autoReplyInstance = FoxChatDB.autoReplyInstance or false
    FoxChatDB.firstComeEnabled = FoxChatDB.firstComeEnabled or false
    FoxChatDB.firstComeCooldown = FoxChatDB.firstComeCooldown or 5
    FoxChatDB.autoReplyCooldown = FoxChatDB.autoReplyCooldown or 5
end

-- 호환성 함수들 (기존 코드와의 호환성 유지)
function FoxChat:Toggle()
    if FoxChatDB then
        FoxChatDB.filterEnabled = not FoxChatDB.filterEnabled
        if FoxChat.UI and FoxChat.UI.MinimapButton then
            FoxChat.UI.MinimapButton:ToggleFilter()
        end
    end
end

function FoxChat:OpenConfig()
    if FoxChat.UI and FoxChat.UI.Config and FoxChat.UI.Config.Show then
        FoxChat.UI.Config:Show()
    else
        print("|cffFFA500FoxChat|r 설정창이 아직 로드되지 않았습니다.")
    end
end

function FoxChat:UpdateKeywords()
    if FoxChat.Features and FoxChat.Features.KeywordFilter then
        FoxChat.Features.KeywordFilter:UpdateKeywords()
    end
end

function FoxChat:UpdateIgnoreKeywords()
    if FoxChat.Features and FoxChat.Features.KeywordFilter then
        FoxChat.Features.KeywordFilter:UpdateIgnoreKeywords()
    end
end

function FoxChat:ResetAdCooldown()
    if FoxChat.Features and FoxChat.Features.Advertisement then
        FoxChat.Features.Advertisement:ResetCooldown()
    end
end

-- ShowToast 전역 함수 (기존 코드 호환성)
function ShowToast(author, message, channelGroup, isTest)
    if FoxChat.UI and FoxChat.UI.Toast then
        FoxChat.UI.Toast:Show(author, message, channelGroup, isTest)
    end
end

-- 슬래시 커맨드
SLASH_FOXCHAT1 = "/foxchat"
SLASH_FOXCHAT2 = "/fc"
SlashCmdList["FOXCHAT"] = function(msg)
    if msg == "reload" then
        Init:Reload()
    elseif msg == "debug" then
        FoxChatDB.debug = not FoxChatDB.debug
        FoxChat:Print("디버그 모드:", FoxChatDB.debug and "켜짐" or "꺼짐")
    else
        if FoxChat.UI and FoxChat.UI.Config then
            FoxChat.UI.Config:Toggle()
        else
            FoxChat:Print("사용법: /foxchat 또는 /fc")
            FoxChat:Print("  reload - 모듈 리로드")
            FoxChat:Print("  debug - 디버그 모드 토글")
        end
    end
end