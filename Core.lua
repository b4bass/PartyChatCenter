-- Core.lua
-- Main logic: frame setup, background handling, event processing
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
    msgFrame:SetSize(500, 80) -- Width will adjust based on content
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
    
    -- Create a frame that will serve as our background container
    local function CreateBackgroundContainer(parent)
        -- Create a container frame to hold individual message backgrounds
        local container = CreateFrame("Frame", parent:GetName() .. "BackgroundContainer", UIParent)
        container:SetPoint("TOPLEFT", parent, "TOPLEFT", -10, 10)
        container:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 10, -10)
        container:SetFrameStrata("BACKGROUND")
        
        -- Table to track active background frames
        container.backgroundFrames = {}
        
        -- Function to clean up expired backgrounds
        container.CleanupBackgrounds = function()
            local now = GetTime()
            for i = #container.backgroundFrames, 1, -1 do
                local bgFrame = container.backgroundFrames[i]
                if now - bgFrame.creationTime > bgFrame.duration then
                    bgFrame:Hide()
                    table.remove(container.backgroundFrames, i)
                end
            end
        end
        
        -- Function to create a new background for a message
        container.CreateMessageBackground = function(text)
            -- First, clean up any expired backgrounds
            container.CleanupBackgrounds()
            
            -- Create a new backdrop frame for this message
            local bgFrame = CreateFrame("Frame", nil, container, "BackdropTemplate")
            bgFrame:SetFrameStrata("BACKGROUND")
            
            -- Estimate text dimensions based on font size and message length
            local fontSize = cfg.fontSize or 14
            local estimatedWidth = math.min(fontSize * (#text * 0.7), 500) -- Cap at 500px, increased multiplier
            local estimatedHeight = fontSize * 1.8 -- Increased height for better appearance
            
            -- Position at the appropriate insertion point
            if cfg.chatOrder == "TOP" then
                -- For TOP insert mode, new messages appear at the top
                bgFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
                
                -- Shift existing frames down
                for _, existingFrame in ipairs(container.backgroundFrames) do
                    local point, relFrame, relPoint, xOfs, yOfs = existingFrame:GetPoint(1)
                    if point and yOfs then -- Make sure we have valid position data
                        existingFrame:SetPoint(point, relFrame, relPoint, xOfs, yOfs - estimatedHeight - 2)
                    end
                end
            else
                -- For BOTTOM insert mode, new messages appear at the bottom
                if #container.backgroundFrames > 0 then
                    local lastFrame = container.backgroundFrames[#container.backgroundFrames]
                    local point, relFrame, relPoint, xOfs, yOfs = lastFrame:GetPoint(1)
                    if point and yOfs then -- Make sure we have valid position data
                        bgFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, yOfs - estimatedHeight - 2)
                    else
                        bgFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -estimatedHeight)
                    end
                else
                    bgFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -estimatedHeight)
                end
            end
            
            -- Set size based on text length
            bgFrame:SetSize(estimatedWidth, estimatedHeight)
            
            -- Apply backdrop
            bgFrame:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 8,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            
            -- Set colors
            bgFrame:SetBackdropColor(0, 0, 0, cfg.bgOpacity or 0.5)
            bgFrame:SetBackdropBorderColor(0, 0, 0, (cfg.bgOpacity or 0.5) * 0.7)
            
            -- Track creation time and duration
            bgFrame.creationTime = GetTime()
            bgFrame.duration = cfg.timeVisible or 10
            
            -- Add to our tracking table
            table.insert(container.backgroundFrames, 1, bgFrame)
            
            -- Ensure the frame is visible
            bgFrame:Show()
            
            return bgFrame
        end
        
        return container
    end
    
    -- Create background container
    local bgContainer = CreateBackgroundContainer(msgFrame)
    
    -- Override AddMessage to handle background creation for each message
    local originalAddMessage = msgFrame.AddMessage
    msgFrame.AddMessage = function(self, text, ...)
        local now = GetTime()
        
        -- Clean expired messages
        for i = #addon.activeMessages, 1, -1 do
            if now - addon.activeMessages[i].time > addon.activeMessages[i].duration then
                table.remove(addon.activeMessages, i)
            end
        end
        
        -- Add new message to tracking
        table.insert(addon.activeMessages, {
            text = text,
            time = now,
            duration = cfg.timeVisible or 10
        })
        
        -- Call original method to display the text
        originalAddMessage(self, text, ...)
        
        -- Skip background creation if opacity is 0
        if not cfg.bgOpacity or cfg.bgOpacity <= 0 then
            return
        end
        
        -- Create a background for this message
        bgContainer.CreateMessageBackground(text)
    end
    
    -- Store references in addon table
    addon.frame = msgFrame
    addon.cfg = cfg
    addon.bgContainer = bgContainer
    
    -- Update function to refresh display when settings change
    addon.updateDisplay = function()
        msgFrame:SetFont(STANDARD_TEXT_FONT, cfg.fontSize, "OUTLINE")
        msgFrame:SetTimeVisible(cfg.timeVisible)
        msgFrame:SetAlpha(cfg.fontOpacity)
        msgFrame:SetInsertMode(cfg.chatOrder)
        
        -- Update background fade time to match
        for _, bgFrame in ipairs(bgContainer.backgroundFrames) do
            bgFrame.duration = cfg.timeVisible
        end
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
    
    -- Set up a timer to periodically clean up background frames
    C_Timer.NewTicker(1, function()
        bgContainer.CleanupBackgrounds()
    end)
    
    -- Test messages to verify functionality
    C_Timer.After(1, function() 
        msgFrame:AddMessage("|cff00ff00[ChatEnhancer]|r Addon loaded successfully!") 
    end)
    C_Timer.After(2, function() 
        msgFrame:AddMessage("|cff00ff00[ChatEnhancer]|r This is a longer test message to verify background sizing") 
    end)
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
        if cfg.filterQuestie and message:find("Questie") then return end
        
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
        
        -- Add message to frame
        addon.frame:AddMessage(displayText)
    end
end)