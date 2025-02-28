-- Core.lua
-- Main logic: frame setup, background handling, event processing
local addonName, addon = ...

-- Initialize addon on load
local function Setup()
    if not next(ChatEnhancerDB) then
        for k, v in pairs(addon.defaults) do  -- Changed from defaults to addon.defaults
            ChatEnhancerDB[k] = v
        end
    end
    local cfg = ChatEnhancerDB
    
    local screenWidth = GetScreenWidth()
    local maxWidth = math.min(768, screenWidth * 0.7)
    
    local msgFrame = CreateFrame("MessageFrame", "ChatEnhancerFrame", UIParent)
    msgFrame:SetSize(maxWidth, 80)
    msgFrame:SetPoint(cfg.point, UIParent, cfg.point, cfg.x, cfg.y)
    msgFrame:SetInsertMode(cfg.chatOrder)
    msgFrame:SetFont(STANDARD_TEXT_FONT, cfg.fontSize, "OUTLINE")
    msgFrame:SetFading(true)
    msgFrame:SetFadeDuration(0.5)
    msgFrame:SetTimeVisible(cfg.timeVisible)
    msgFrame:SetAlpha(cfg.fontOpacity)
    
    -- Background frame setup
    local bg = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    bg:SetFrameStrata("BACKGROUND")
    bg:SetFrameLevel(0)
    bg:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    bg:SetBackdropColor(0, 0, 0, 0)
    bg:SetBackdropBorderColor(0.5, 0.5, 0.5, 0)
    bg:SetPoint("CENTER", msgFrame, "CENTER", 0, 0)
    bg:SetSize(maxWidth, 80)
    bg:Hide()
    msgFrame:SetFrameStrata("MEDIUM")
    
    -- Background management variables
    local activeMessages = {}
    local bgVisible = false
    local bgFadeTimer = nil
    
    -- Update background size based on active messages
    local function UpdateBackgroundSize()
        if #activeMessages == 0 then return end
        local totalHeight = 0
        local maxMsgWidth = msgFrame:GetWidth() - 20
        for _, msg in ipairs(activeMessages) do
            local cleanText = msg.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            local approxWidth = cleanText:len() * (cfg.fontSize * 0.6)
            local lines = math.max(1, math.ceil(approxWidth / maxMsgWidth))
            totalHeight = totalHeight + (lines * cfg.fontSize * 1.5)
        end
        totalHeight = totalHeight + 20
        bg:SetHeight(math.max(60, totalHeight))
        bg:ClearAllPoints()
        if cfg.chatOrder == "TOP" then
            bg:SetPoint("TOP", msgFrame, "TOP", 0, 10)
        else
            bg:SetPoint("BOTTOM", msgFrame, "BOTTOM", 0, -10)
        end
        bg:SetWidth(msgFrame:GetWidth() + 20)
    end
    
    -- Handle background visibility with fade effects
    local function UpdateBackgroundVisibility()
        if bgFadeTimer then
            bgFadeTimer:Cancel()
            bgFadeTimer = nil
        end
        local shouldBeVisible = (#activeMessages > 0 and cfg.bgOpacity > 0)
        if shouldBeVisible and not bgVisible then
            bg:SetBackdropColor(0, 0, 0, 0)
            bg:SetBackdropBorderColor(0.5, 0.5, 0.5, 0)
            bg:Show()
            bg.fadeIn = bg.fadeIn or bg:CreateAnimationGroup()
            if bg.fadeIn:IsPlaying() then bg.fadeIn:Stop() end
            bg.fadeIn:SetScript("OnPlay", function() bg:Show() end)
            if not bg.fadeIn.alpha then
                bg.fadeIn.alpha = bg.fadeIn:CreateAnimation("Alpha")
                bg.fadeIn.alpha:SetFromAlpha(0)
                bg.fadeIn.alpha:SetDuration(0.3)
            end
            bg.fadeIn.alpha:SetToAlpha(cfg.bgOpacity)
            bg.fadeIn:SetScript("OnFinished", function()
                bg:SetBackdropColor(0, 0, 0, cfg.bgOpacity)
                bg:SetBackdropBorderColor(0.5, 0.5, 0.5, cfg.bgOpacity)
            end)
            bg.fadeIn:Play()
            bgVisible = true
            UpdateBackgroundSize()
        elseif not shouldBeVisible and bgVisible then
            bg.fadeOut = bg.fadeOut or bg:CreateAnimationGroup()
            if bg.fadeOut:IsPlaying() then bg.fadeOut:Stop() end
            if not bg.fadeOut.alpha then
                bg.fadeOut.alpha = bg.fadeOut:CreateAnimation("Alpha")
                bg.fadeOut.alpha:SetFromAlpha(cfg.bgOpacity)
                bg.fadeOut.alpha:SetDuration(0.5)
            end
            bg.fadeOut.alpha:SetFromAlpha(cfg.bgOpacity)
            bg.fadeOut.alpha:SetToAlpha(0)
            bg.fadeOut:SetScript("OnFinished", function()
                bg:Hide()
                bgVisible = false
            end)
            bg.fadeOut:Play()
        elseif shouldBeVisible and bgVisible then
            bg:SetBackdropColor(0, 0, 0, cfg.bgOpacity)
            bg:SetBackdropBorderColor(0.5, 0.5, 0.5, cfg.bgOpacity)
            UpdateBackgroundSize()
        end
    end
    
    -- Check if background should fade out
    local function CheckBackgroundFade()
        local now = GetTime()
        local shouldBeVisible = false
        for i = #activeMessages, 1, -1 do
            local msg = activeMessages[i]
            if now - msg.time <= msg.duration then
                shouldBeVisible = true
                break
            end
        end
        if not shouldBeVisible and bgVisible then
            UpdateBackgroundVisibility()
        end
    end
    
    -- Hook AddMessage to track messages and update background
    local originalAddMessage = msgFrame.AddMessage
    msgFrame.AddMessage = function(self, text, ...)
        table.insert(activeMessages, {
            text = text,
            time = GetTime(),
            duration = cfg.timeVisible
        })
        originalAddMessage(self, text, ...)
        UpdateBackgroundVisibility()
        bgFadeTimer = C_Timer.NewTimer(cfg.timeVisible + 0.5, CheckBackgroundFade)
    end
    
    -- Frame for cleaning expired messages
    local updateFrame = CreateFrame("Frame")
    updateFrame:SetScript("OnUpdate", function()
        local now = GetTime()
        local needsUpdate = false
        local needsVisibilityCheck = false
        for i = #activeMessages, 1, -1 do
            local msg = activeMessages[i]
            if now - msg.time > msg.duration then
                table.remove(activeMessages, i)
                needsUpdate = true
                needsVisibilityCheck = true
            end
        end
        if needsUpdate and bgVisible then
            UpdateBackgroundSize()
        end
        if needsVisibilityCheck and #activeMessages == 0 and bgVisible then
            UpdateBackgroundVisibility()
        end
    end)
    
    -- Make frame movable
    msgFrame:SetMovable(true)
    msgFrame:RegisterForDrag("LeftButton")
    msgFrame:SetScript("OnDragStart", function() 
        if IsShiftKeyDown() then 
            msgFrame:StartMoving() 
        end
    end)
    msgFrame:SetScript("OnDragStop", function() 
        msgFrame:StopMovingOrSizing() 
        local point, _, _, x, y = msgFrame:GetPoint()
        cfg.point = point
        cfg.x = x
        cfg.y = y
    end)
    
    -- Store references in addon table
    addon.frame = msgFrame
    addon.bg = bg
    addon.cfg = cfg
    addon.activeMessages = activeMessages
    
    -- Update background when opacity changes
    addon.updateBackground = function()
        bg:SetBackdropColor(0, 0, 0, bgVisible and addon.cfg.bgOpacity or 0)
        bg:SetBackdropBorderColor(0.5, 0.5, 0.5, bgVisible and addon.cfg.bgOpacity or 0)
        if addon.cfg.bgOpacity <= 0 then
            if bgVisible then
                bgVisible = false
                bg:Hide()
            end
            if bgFadeTimer then
                bgFadeTimer:Cancel()
                bgFadeTimer = nil
            end
        else
            if #activeMessages > 0 and not bgVisible then
                UpdateBackgroundVisibility()
            end
        end
        if bgVisible and #activeMessages > 0 then
            UpdateBackgroundSize()
        end
    end
    
    addon.playerName = UnitName("player")
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
        if (cfg.locationMode == 1 and not inInstance) or
           (cfg.locationMode == 2 and inInstance) then
            return
        end
        if cfg.filterOwnMessages then
            local playerName = UnitName("player")
            local shortSender = Ambiguate(sender, "short")
            if shortSender == playerName then 
                return
            end
        end
        if cfg.filterQuestie and message:find("Questie") then return end
        local hasKeyword = false
        if cfg.highlightKeyword then
            local keywords = ParseKeywords(cfg.alertKeywords)
            for keyword in pairs(keywords) do
                if message:lower():find(keyword:lower()) then
                    hasKeyword = true
                    break
                end
            end
            if cfg.alertModeEnabled and not hasKeyword then
                return
            end
        elseif cfg.alertModeEnabled then
            local keywords = ParseKeywords(cfg.alertKeywords)
            for keyword in pairs(keywords) do
                if message:lower():find(keyword:lower()) then
                    hasKeyword = true
                    break
                end
            end
            if not hasKeyword then
                return
            end
        end
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
        if cfg.highlightKeyword and hasKeyword then
            local keywords = ParseKeywords(cfg.alertKeywords)
            for keyword in pairs(keywords) do
                local lowerMsg = message:lower()
                local lowerKeyword = keyword:lower()
                local pos = 1
                local count = 0
                while true do
                    local i = lowerMsg:find(lowerKeyword, pos, true)
                    if not i then break end
                    count = count + 1
                    pos = i + #lowerKeyword
                end
                if count > 0 then
                    for i = 1, count do
                        local escapedKeyword = keyword:gsub("([%%%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
                        local pattern = string.format("([^|]-)(%s)", escapedKeyword)
                        displayText = displayText:gsub(pattern, function(prefix, match)
                            return prefix .. "|cffff0000#" .. match:upper() .. "#|r"
                        end, 1) 
                    end
                    if cfg.alertSound then
                        PlaySound(5274, "Master")
                    end
                end
            end
        end
        addon.frame:AddMessage(displayText)
    end
end)