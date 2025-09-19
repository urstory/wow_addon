-- Simple test frame to verify chat events work (disabled for production)
-- Uncomment the code below to enable debug mode

--[[
local testFrame = CreateFrame("Frame", "TestChatFrame")
testFrame:RegisterEvent("CHAT_MSG_CHANNEL")

testFrame:SetScript("OnEvent", function()
    if event == "CHAT_MSG_CHANNEL" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TEST] Channel message detected!|r")
        DEFAULT_CHAT_FRAME:AddMessage("  arg1 (msg): " .. tostring(arg1))
        DEFAULT_CHAT_FRAME:AddMessage("  arg2 (author): " .. tostring(arg2))
        DEFAULT_CHAT_FRAME:AddMessage("  arg8 (channel#): " .. tostring(arg8))
        DEFAULT_CHAT_FRAME:AddMessage("  arg9 (channel name): " .. tostring(arg9))
    end
end)

DEFAULT_CHAT_FRAME:AddMessage("|cffff0000TestChat loaded - listening for channel messages|r")
--]]