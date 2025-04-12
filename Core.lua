-- Core.lua
-- Main logic: frame setup, event processing
local addonName, addon = ...

-- Initialize addon on load
local function Setup()
    -- Initialize DB if needed
    if not ChatEnhancerDB then
        ChatEnhancerDB = {}
    end
    
    if not next(ChatEnhancerDB) then
        for k, v in pairs(addon.defaults) do
            ChatEnhancerDB[k] = v
        end
    end
    local cfg = ChatEnhancerDB
    
    -- Create the main message frame
    local msgFrame = CreateFrame("MessageFrame", "ChatEnhancerFrame", UIParent)
    
    -- Set size based on WorldFrame dimensions (70% height, 40% width)
    local worldFrame = WorldFrame
    local worldWidth, worldHeight = worldFrame:GetWidth(), worldFrame:GetHeight()
    local frameWidth = worldWidth * 0.4
    local frameHeight = worldHeight * 0.6
    msgFrame:SetSize(frameWidth, frameHeight)
    
    msgFrame:SetPoint(cfg.point or "CENTER", UIParent, cfg.point or "CENTER", cfg.x or 0, cfg.y or 0)
    msgFrame:SetInsertMode(cfg.chatOrder or "BOTTOM")
    msgFrame:SetFont(STANDARD_TEXT_FONT, cfg.fontSize or 14, "OUTLINE")
    msgFrame:SetFading(true)
    msgFrame:SetFadeDuration(0.5)
    msgFrame:SetTimeVisible(cfg.timeVisible or 10)
    msgFrame:SetAlpha(cfg.fontOpacity or 1.0)
    msgFrame:Show() -- Ensure frame is visible
    
    -- Store active messages for tracking
    addon.activeMessages = {}
    
    -- Store references in addon table
    addon.frame = msgFrame
    addon.cfg = cfg
    
    -- Update function to refresh display when settings change
    addon.updateDisplay = function()
        msgFrame:SetFont(STANDARD_TEXT_FONT, cfg.fontSize, "OUTLINE")
        msgFrame:SetTimeVisible(cfg.timeVisible)
        msgFrame:SetAlpha(cfg.fontOpacity)
        msgFrame:SetInsertMode(cfg.chatOrder)
    end
    
    -- Store player name for later use
    addon.playerName = UnitName("player")
    
    -- Class colors cache and lookup function
    addon.classColors = {}
    addon.GetClassColor = function(name)
        if addon.classColors[name] then
            return unpack(addon.classColors[name])
        end
        
        local inRaid = IsInRaid()
        local numMembers = GetNumGroupMembers()
        local prefix = inRaid and "raid" or "party"
        
        for i = 1, numMembers do
            local unit = prefix..i
            if UnitExists(unit) and UnitName(unit) == name then
                local _, class = UnitClass(unit)
                if class and RAID_CLASS_COLORS[class] then
                    local color = RAID_CLASS_COLORS[class]
                    addon.classColors[name] = {color.r, color.g, color.b}
                    return color.r, color.g, color.b
                end
            end
        end
        
        -- Default color if not found
        addon.classColors[name] = {0.5, 0.7, 1.0}
        return 0.5, 0.7, 1.0
    end
end

-- Parse keywords for alert filtering
local function ParseKeywords(keywordsText)
    local keywords = {}
    if not keywordsText or keywordsText == "" then return keywords end
    
    for keyword in keywordsText:gmatch("[^\n]+") do
        keyword = strtrim(keyword):lower()
        if keyword ~= "" then
            keywords[keyword] = true
        end
    end
    return keywords
end

-- Custom function to add message with max lines limit
local function AddMessageWithLimit(frame, text)
    -- Clear the frame if we've reached the max messages
    if #addon.activeMessages >= (addon.cfg.maxMessages or 4) then
        frame:Clear()
        addon.activeMessages = {}
    end
    
    -- Add the message
    frame:AddMessage(text)
    
    -- Store the message
    table.insert(addon.activeMessages, text)
    
    -- Remove oldest message if we exceed the limit
    while #addon.activeMessages > (addon.cfg.maxMessages or 4) do
        table.remove(addon.activeMessages, 1)
    end
end

-- Event handling for chat messages
local eventFrame = CreateFrame("Frame")
addon.eventFrame = eventFrame
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" and arg1 == addonName then
        Setup()
        self:RegisterEvent("CHAT_MSG_PARTY")
        self:RegisterEvent("CHAT_MSG_PARTY_LEADER")
        self:RegisterEvent("CHAT_MSG_RAID")
        self:RegisterEvent("CHAT_MSG_RAID_LEADER")
        self:RegisterEvent("CHAT_MSG_RAID_WARNING")
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        if addon.cfg.showAllChat then
            self:RegisterEvent("CHAT_MSG_YELL")
            self:RegisterEvent("CHAT_MSG_SAY")
        end
        if addon.cfg.showWhispers then
            self:RegisterEvent("CHAT_MSG_WHISPER")
            self:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
        end
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "GROUP_ROSTER_UPDATE" then
        addon.classColors = {}
    elseif event:find("CHAT_MSG_") then
        local message, sender = arg1, arg2
        local cfg = addon.cfg
        local inInstance = IsInInstance()
        
        -- Check location mode
        if (cfg.locationMode == 1 and not inInstance) or
           (cfg.locationMode == 2 and inInstance) then
            return
        end
        
        -- Filter own messages if enabled
        if cfg.filterOwnMessages then
            local playerName = UnitName("player")
            local shortSender = Ambiguate(sender, "short")
            if shortSender == playerName then 
                return
            end
        end
        
        -- Filter Questie messages if enabled
        if cfg.filterQuestie and message:find("Questie:") then return end
        
        -- Check for keywords
        local hasKeyword = false
        if cfg.highlightKeyword or cfg.alertModeEnabled then
            local keywords = ParseKeywords(cfg.alertKeywords)
            for keyword in pairs(keywords) do
                if message:lower():find(keyword:lower()) then
                    hasKeyword = true
                    break
                end
            end
            
            -- In alert mode, only show messages with keywords
            if cfg.alertModeEnabled and not hasKeyword then
                return
            end
        end
        
        -- Format the message
        sender = Ambiguate(sender, "short")
        local r, g, b = addon.GetClassColor(sender)
        local displayText
        
        if cfg.colorMessages then
            local nameColor = "|cff" .. string.format("%02x%02x%02x", r*255, g*255, b*255)
            local msgColor
            
            if event == "CHAT_MSG_SAY" then
                msgColor = "|cffffffff"
            elseif event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" then
                msgColor = "|cff00b7eb"
            elseif event == "CHAT_MSG_YELL" then
                msgColor = "|cffff0000"
            elseif event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER" or event == "CHAT_MSG_RAID_WARNING" then
                msgColor = "|cffa330c9"
            elseif event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_WHISPER_INFORM" then
                msgColor = "|cffff00ff"
            else
                msgColor = nameColor
            end
            
            if cfg.showNames then
                displayText = nameColor .. sender .. "|r: " .. msgColor .. message .. "|r"
            else
                displayText = msgColor .. message .. "|r"
            end
        else
            if cfg.showNames then
                displayText = "|cff" .. string.format("%02x%02x%02x", r*255, g*255, b*255) .. sender .. "|r: " .. message
            else
                displayText = message
            end
        end
        
        -- Highlight keywords if enabled and keywords found
        if cfg.highlightKeyword and hasKeyword then
            local keywords = ParseKeywords(cfg.alertKeywords)
            for keyword in pairs(keywords) do
                local lowerMsg = message:lower()
                local lowerKeyword = keyword:lower()
                local pos = 1
                local count = 0
                
                -- Count keyword occurrences
                while true do
                    local i = lowerMsg:find(lowerKeyword, pos, true)
                    if not i then break end
                    count = count + 1
                    pos = i + #lowerKeyword
                end
                
                -- Highlight each occurrence
                if count > 0 then
                    for i = 1, count do
                        local escapedKeyword = keyword:gsub("([%%%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
                        local pattern = string.format("([^|]-)(%s)", escapedKeyword)
                        displayText = displayText:gsub(pattern, function(prefix, match)
                            return prefix .. "|cffff0000#" .. match:upper() .. "#|r"
                        end, 1)
                    end
                    
                    -- Play alert sound if enabled
                    if cfg.alertSound then
                        PlaySound(5274, "Master")
                    end
                end
            end
        end
        
        -- Add message to frame with max lines limit
        AddMessageWithLimit(addon.frame, displayText)
    end
end)