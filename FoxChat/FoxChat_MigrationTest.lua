local addonName, addon = ...

-- 마이그레이션 테스트 명령어
SLASH_FOXCHATMIGRATION1 = "/fcmigrate"
SlashCmdList["FOXCHATMIGRATION"] = function(msg)
    local command = string.lower(msg or "")

    if command == "status" then
        -- 마이그레이션 상태 확인
        local status = addon.Migration:GetStatus()
        print("|cFF00FF00[FoxChat Migration]|r 현재 상태:")
        print("  현재 버전: " .. status.currentVersion)
        print("  목표 버전: " .. status.targetVersion)
        print("  마이그레이션 필요: " .. (status.needsMigration and "|cFFFF0000예|r" or "|cFF00FF00아니오|r"))
        print("  채널별 필터 존재: " .. (status.hasChannelFilters and "|cFF00FF00예|r" or "|cFFFF0000아니오|r"))
        print("  백업 개수: " .. status.backupCount)

    elseif command == "migrate" then
        -- 수동 마이그레이션 실행
        print("|cFF00FF00[FoxChat Migration]|r 마이그레이션 시작...")
        local success, result = addon.Migration:MigrateToChannelFilters()
        if success then
            print("|cFF00FF00[FoxChat Migration]|r 마이그레이션 성공!")
            print("  백업 ID: " .. (result or "없음"))
        else
            print("|cFFFF0000[FoxChat Migration]|r 마이그레이션 실패: " .. (result or "알 수 없는 오류"))
        end

    elseif command == "validate" then
        -- 설정 검증
        print("|cFF00FF00[FoxChat Migration]|r 설정 검증 중...")
        addon.Migration:ValidateChannelFilters()
        print("|cFF00FF00[FoxChat Migration]|r 검증 완료")

        -- 채널별 설정 출력
        if FoxChatDB and FoxChatDB.channelFilters then
            print("채널별 필터 설정:")
            for channel, settings in pairs(FoxChatDB.channelFilters) do
                print(string.format("  %s: 활성=%s, 키워드 수=%d, 무시 키워드 수=%d",
                    channel,
                    settings.enabled and "O" or "X",
                    settings.keywords and #(string.gsub(settings.keywords, "[^,]+", "")) + 1 or 0,
                    settings.ignoreKeywords and #(string.gsub(settings.ignoreKeywords, "[^,]+", "")) + 1 or 0
                ))
            end
        end

        -- 토스트 설정 출력
        if FoxChatDB and FoxChatDB.toastDuration then
            print("토스트 표시 시간: " .. FoxChatDB.toastDuration .. "초")
        end

    elseif command == "backup" then
        -- 수동 백업 생성
        print("|cFF00FF00[FoxChat Migration]|r 백업 생성 중...")
        local timestamp = addon.Migration:BackupSettings()
        if timestamp then
            print("|cFF00FF00[FoxChat Migration]|r 백업 생성 완료: " .. timestamp)
        else
            print("|cFFFF0000[FoxChat Migration]|r 백업 생성 실패")
        end

    elseif command == "list" then
        -- 백업 목록 확인
        local backups = addon.Migration:GetBackupList()
        if #backups > 0 then
            print("|cFF00FF00[FoxChat Migration]|r 백업 목록:")
            for i, timestamp in ipairs(backups) do
                -- 날짜 포맷 변환 (YYYYMMDD_HHMMSS -> YYYY-MM-DD HH:MM:SS)
                local year = string.sub(timestamp, 1, 4)
                local month = string.sub(timestamp, 5, 6)
                local day = string.sub(timestamp, 7, 8)
                local hour = string.sub(timestamp, 10, 11)
                local min = string.sub(timestamp, 12, 13)
                local sec = string.sub(timestamp, 14, 15)
                local formatted = string.format("%s-%s-%s %s:%s:%s", year, month, day, hour, min, sec)
                print(string.format("  %d. %s", i, formatted))
            end
            print("복구하려면: /fcmigrate restore <번호>")
        else
            print("|cFF00FF00[FoxChat Migration]|r 백업이 없습니다.")
        end

    elseif string.sub(command, 1, 7) == "restore" then
        -- 백업 복구
        local index = tonumber(string.sub(command, 9))
        if not index then
            print("|cFFFF0000[FoxChat Migration]|r 사용법: /fcmigrate restore <번호>")
            return
        end

        local backups = addon.Migration:GetBackupList()
        if index < 1 or index > #backups then
            print("|cFFFF0000[FoxChat Migration]|r 잘못된 백업 번호입니다.")
            return
        end

        local timestamp = backups[index]
        print("|cFF00FF00[FoxChat Migration]|r 백업 복구 중: " .. timestamp)
        local success, result = addon.Migration:RestoreBackup(timestamp)
        if success then
            print("|cFF00FF00[FoxChat Migration]|r 백업 복구 성공! UI를 다시 로드하세요 (/reload)")
        else
            print("|cFFFF0000[FoxChat Migration]|r 백업 복구 실패: " .. (result or "알 수 없는 오류"))
        end

    elseif command == "test" then
        -- 테스트 데이터로 마이그레이션 테스트
        print("|cFF00FF00[FoxChat Migration]|r 테스트 모드 시작...")

        -- 기존 구조 시뮬레이션
        FoxChatDB = FoxChatDB or {}
        FoxChatDB.keywords = "테스트1, 테스트2, 테스트3"
        FoxChatDB.ignoreKeywords = "무시1, 무시2"
        FoxChatDB.channelGroups = {
            GUILD = true,
            PUBLIC = false,
            PARTY_RAID = true,
            LFG = true
        }

        print("기존 설정 시뮬레이션 완료")
        print("  keywords: " .. FoxChatDB.keywords)
        print("  ignoreKeywords: " .. FoxChatDB.ignoreKeywords)

        -- 마이그레이션 실행
        local success, result = addon.Migration:MigrateToChannelFilters()
        if success then
            print("|cFF00FF00[FoxChat Migration]|r 테스트 마이그레이션 성공!")

            -- 결과 확인
            if FoxChatDB.channelFilters then
                print("마이그레이션 결과:")
                for channel, settings in pairs(FoxChatDB.channelFilters) do
                    print(string.format("  %s:", channel))
                    print(string.format("    활성: %s", settings.enabled and "O" or "X"))
                    print(string.format("    키워드: %s", settings.keywords or ""))
                    print(string.format("    무시: %s", settings.ignoreKeywords or ""))
                end
            end
        else
            print("|cFFFF0000[FoxChat Migration]|r 테스트 마이그레이션 실패")
        end

    elseif command == "reset" then
        -- 설정 초기화 (개발용)
        print("|cFFFF0000[FoxChat Migration]|r 경고: 모든 설정을 초기화합니다!")
        print("확인하려면 다음을 입력하세요: /fcmigrate reset confirm")

    elseif command == "reset confirm" then
        -- 설정 초기화 확인
        FoxChatDB = nil
        FoxChatDB_Backup = nil
        print("|cFFFF0000[FoxChat Migration]|r 모든 설정이 초기화되었습니다. UI를 다시 로드하세요 (/reload)")

    else
        -- 도움말
        print("|cFF00FF00[FoxChat Migration]|r 명령어:")
        print("  /fcmigrate status - 마이그레이션 상태 확인")
        print("  /fcmigrate migrate - 수동 마이그레이션 실행")
        print("  /fcmigrate validate - 설정 검증")
        print("  /fcmigrate backup - 현재 설정 백업")
        print("  /fcmigrate list - 백업 목록 확인")
        print("  /fcmigrate restore <번호> - 백업 복구")
        print("  /fcmigrate test - 테스트 마이그레이션")
        print("  /fcmigrate reset - 모든 설정 초기화 (주의!)")
    end
end

-- 짧은 별칭
SLASH_FCM1 = "/fcm"
SlashCmdList["FCM"] = SlashCmdList["FOXCHATMIGRATION"]

print("|cFF00FF00[FoxChat]|r 마이그레이션 테스트 명령어가 로드되었습니다. /fcmigrate 또는 /fcm 을 사용하세요.")