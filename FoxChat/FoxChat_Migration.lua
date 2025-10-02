local addonName, addon = ...

-- 데이터 마이그레이션 모듈
local Migration = {}
addon.Migration = Migration

-- 마이그레이션 버전
local MIGRATION_VERSION = 2  -- 채널별 필터링 구조로 변경

-- 기본 채널별 필터링 설정
local defaultChannelFilters = {
    GUILD = {
        enabled = true,
        keywords = "",
        ignoreKeywords = ""
    },
    SAY = {
        enabled = true,
        keywords = "",
        ignoreKeywords = ""
    },
    PARTY = {
        enabled = true,
        keywords = "",
        ignoreKeywords = ""
    },
    LFG = {
        enabled = true,
        keywords = "",
        ignoreKeywords = ""
    },
    TRADE = {
        enabled = true,
        keywords = "",
        ignoreKeywords = ""
    }
}

-- 설정 백업 함수
function Migration:BackupSettings()
    if not FoxChatDB then
        return nil
    end

    -- 깊은 복사를 위한 헬퍼 함수
    local function deepCopy(orig)
        local orig_type = type(orig)
        local copy
        if orig_type == 'table' then
            copy = {}
            for orig_key, orig_value in next, orig, nil do
                copy[deepCopy(orig_key)] = deepCopy(orig_value)
            end
            setmetatable(copy, deepCopy(getmetatable(orig)))
        else
            copy = orig
        end
        return copy
    end

    -- 백업 생성
    FoxChatDB_Backup = FoxChatDB_Backup or {}
    local timestamp = date("%Y%m%d_%H%M%S")
    FoxChatDB_Backup[timestamp] = deepCopy(FoxChatDB)

    -- 최대 5개의 백업만 유지
    local backupKeys = {}
    for k in pairs(FoxChatDB_Backup) do
        table.insert(backupKeys, k)
    end
    table.sort(backupKeys)

    while #backupKeys > 5 do
        FoxChatDB_Backup[backupKeys[1]] = nil
        table.remove(backupKeys, 1)
    end

    return timestamp
end

-- 기존 설정을 새 구조로 마이그레이션
function Migration:MigrateToChannelFilters()
    if not FoxChatDB then
        FoxChatDB = {}
    end

    -- 이미 마이그레이션된 경우 스킵
    if FoxChatDB.migrationVersion and FoxChatDB.migrationVersion >= MIGRATION_VERSION then
        return false, "Already migrated"
    end

    -- 백업 생성
    local backupTimestamp = self:BackupSettings()

    -- 토스트 표시 시간 설정 추가 (기본값 5초)
    if not FoxChatDB.toastDuration then
        FoxChatDB.toastDuration = 5
    end

    -- 채널별 필터링 구조가 없으면 생성
    if not FoxChatDB.channelFilters then
        FoxChatDB.channelFilters = {}

        -- 기존 keywords와 ignoreKeywords를 문자열로 변환
        local oldKeywords = ""
        local oldIgnoreKeywords = ""

        if FoxChatDB.keywords then
            if type(FoxChatDB.keywords) == "table" then
                oldKeywords = table.concat(FoxChatDB.keywords, ", ")
            else
                oldKeywords = tostring(FoxChatDB.keywords)
            end
        end

        if FoxChatDB.ignoreKeywords then
            if type(FoxChatDB.ignoreKeywords) == "table" then
                oldIgnoreKeywords = table.concat(FoxChatDB.ignoreKeywords, ", ")
            else
                oldIgnoreKeywords = tostring(FoxChatDB.ignoreKeywords)
            end
        end

        -- 각 채널에 대해 설정 생성 (기존 키워드는 LFG 채널에만 적용)
        for channelType, defaultSettings in pairs(defaultChannelFilters) do
            FoxChatDB.channelFilters[channelType] = {
                enabled = defaultSettings.enabled,
                keywords = (channelType == "LFG") and oldKeywords or "",  -- 기존 키워드는 LFG에만
                ignoreKeywords = (channelType == "LFG") and oldIgnoreKeywords or ""  -- 기존 무시 키워드는 LFG에만
            }
        end

        -- 기존 채널 그룹 설정을 반영
        if FoxChatDB.channelGroups then
            -- GUILD 채널
            if FoxChatDB.channelGroups.GUILD ~= nil then
                FoxChatDB.channelFilters.GUILD.enabled = FoxChatDB.channelGroups.GUILD
            end

            -- SAY (PUBLIC) 채널
            if FoxChatDB.channelGroups.PUBLIC ~= nil then
                FoxChatDB.channelFilters.SAY.enabled = FoxChatDB.channelGroups.PUBLIC
            end

            -- PARTY 채널
            if FoxChatDB.channelGroups.PARTY_RAID ~= nil then
                FoxChatDB.channelFilters.PARTY.enabled = FoxChatDB.channelGroups.PARTY_RAID
            end

            -- LFG 채널
            if FoxChatDB.channelGroups.LFG ~= nil then
                FoxChatDB.channelFilters.LFG.enabled = FoxChatDB.channelGroups.LFG
            end
        end
    end

    -- 마이그레이션 버전 기록
    FoxChatDB.migrationVersion = MIGRATION_VERSION

    -- 마이그레이션 로그
    FoxChatDB.migrationLog = FoxChatDB.migrationLog or {}
    table.insert(FoxChatDB.migrationLog, {
        version = MIGRATION_VERSION,
        date = date("%Y-%m-%d %H:%M:%S"),
        backup = backupTimestamp,
        changes = "Migrated to channel-specific filtering structure"
    })

    return true, backupTimestamp
end

-- 채널별 필터링 설정 검증 및 복구
function Migration:ValidateChannelFilters()
    if not FoxChatDB then
        FoxChatDB = {}
    end

    if not FoxChatDB.channelFilters then
        FoxChatDB.channelFilters = {}
    end

    -- 각 채널에 대해 설정 검증
    for channelType, defaultSettings in pairs(defaultChannelFilters) do
        if not FoxChatDB.channelFilters[channelType] then
            FoxChatDB.channelFilters[channelType] = {}
        end

        local channelFilter = FoxChatDB.channelFilters[channelType]

        -- enabled 필드 검증
        if type(channelFilter.enabled) ~= "boolean" then
            channelFilter.enabled = defaultSettings.enabled
        end

        -- keywords 필드 검증
        if type(channelFilter.keywords) ~= "string" then
            channelFilter.keywords = defaultSettings.keywords
        end

        -- ignoreKeywords 필드 검증
        if type(channelFilter.ignoreKeywords) ~= "string" then
            channelFilter.ignoreKeywords = defaultSettings.ignoreKeywords
        end
    end

    -- 토스트 표시 시간 검증 (기본값 5초)
    if type(FoxChatDB.toastDuration) ~= "number" then
        FoxChatDB.toastDuration = 5
    elseif FoxChatDB.toastDuration < 1 then
        FoxChatDB.toastDuration = 1
    elseif FoxChatDB.toastDuration > 10 then
        FoxChatDB.toastDuration = 10
    end
end

-- 하위 호환성 함수: 기존 방식의 키워드 접근을 채널별 키워드로 변환
function Migration:GetCompatibleKeywords(channelType)
    -- 새 구조가 있으면 사용
    if FoxChatDB and FoxChatDB.channelFilters and FoxChatDB.channelFilters[channelType] then
        return FoxChatDB.channelFilters[channelType].keywords or ""
    end

    -- 기존 구조 폴백
    if FoxChatDB and FoxChatDB.keywords then
        return FoxChatDB.keywords
    end

    return ""
end

function Migration:GetCompatibleIgnoreKeywords(channelType)
    -- 새 구조가 있으면 사용
    if FoxChatDB and FoxChatDB.channelFilters and FoxChatDB.channelFilters[channelType] then
        return FoxChatDB.channelFilters[channelType].ignoreKeywords or ""
    end

    -- 기존 구조 폴백
    if FoxChatDB and FoxChatDB.ignoreKeywords then
        return FoxChatDB.ignoreKeywords
    end

    return ""
end

function Migration:IsChannelFilterEnabled(channelType)
    -- 새 구조 확인
    if FoxChatDB and FoxChatDB.channelFilters and FoxChatDB.channelFilters[channelType] then
        return FoxChatDB.channelFilters[channelType].enabled
    end

    -- 기존 구조 폴백 (채널 그룹 매핑)
    if FoxChatDB and FoxChatDB.channelGroups then
        local mapping = {
            GUILD = "GUILD",
            SAY = "PUBLIC",
            PARTY = "PARTY_RAID",
            LFG = "LFG"
        }
        local groupKey = mapping[channelType]
        if groupKey and FoxChatDB.channelGroups[groupKey] ~= nil then
            return FoxChatDB.channelGroups[groupKey]
        end
    end

    return true  -- 기본값
end

-- 설정 복구 함수
function Migration:RestoreBackup(timestamp)
    if not FoxChatDB_Backup or not FoxChatDB_Backup[timestamp] then
        return false, "Backup not found"
    end

    -- 현재 설정 백업
    self:BackupSettings()

    -- 백업 복구
    FoxChatDB = {}
    for k, v in pairs(FoxChatDB_Backup[timestamp]) do
        FoxChatDB[k] = v
    end

    return true, "Settings restored from backup"
end

-- 백업 목록 가져오기
function Migration:GetBackupList()
    if not FoxChatDB_Backup then
        return {}
    end

    local backups = {}
    for timestamp in pairs(FoxChatDB_Backup) do
        table.insert(backups, timestamp)
    end
    table.sort(backups, function(a, b) return a > b end)  -- 최신순 정렬

    return backups
end

-- 마이그레이션 상태 확인
function Migration:GetStatus()
    local status = {
        currentVersion = FoxChatDB and FoxChatDB.migrationVersion or 0,
        targetVersion = MIGRATION_VERSION,
        needsMigration = false,
        hasChannelFilters = false,
        backupCount = 0
    }

    if FoxChatDB then
        status.needsMigration = not FoxChatDB.migrationVersion or FoxChatDB.migrationVersion < MIGRATION_VERSION
        status.hasChannelFilters = FoxChatDB.channelFilters ~= nil
    else
        status.needsMigration = true
    end

    if FoxChatDB_Backup then
        for _ in pairs(FoxChatDB_Backup) do
            status.backupCount = status.backupCount + 1
        end
    end

    return status
end

-- 초기화 함수
function Migration:Initialize()
    -- 마이그레이션이 필요한지 확인
    local status = self:GetStatus()

    if status.needsMigration then
        -- 자동 마이그레이션 실행
        local success, result = self:MigrateToChannelFilters()
        if success then
            print("|cFF00FF00[FoxChat]|r 설정이 새로운 채널별 필터링 구조로 마이그레이션되었습니다.")
            if result then
                print("|cFF00FF00[FoxChat]|r 백업 생성됨: " .. result)
            end
        end
    end

    -- 설정 검증
    self:ValidateChannelFilters()
end

return Migration