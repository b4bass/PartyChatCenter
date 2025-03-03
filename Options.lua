-- Options.lua
-- Options panel UI and controls
local addonName, addon = ...

function addon.ShowOptions()
    if addon.optionsFrame then 
        addon.optionsFrame:Show()
        return
    end
    local cfg = addon.cfg
    local frame = CreateFrame("Frame", "ChatEnhancerOptions", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(400, 620)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetFontObject("GameFontHighlight")
    frame.title:SetPoint("TOP", 0, -5)
    frame.title:SetText(addon.L.OPTIONS)
    
    local function CreateSlider(name, label, min, max, value, x, y, formatter)
        local slider = CreateFrame("Slider", "ChatEnhancer"..name.."Slider", frame, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", x, y)
        slider:SetMinMaxValues(min, max)
        slider:SetValueStep(1)
        slider:SetValue(value)
        slider:SetWidth(170)
        slider.text = _G[slider:GetName() .. "Text"]
        slider.low = _G[slider:GetName() .. "Low"]
        slider.high = _G[slider:GetName() .. "High"]
        slider.low:SetText(min)
        slider.high:SetText(max)
        slider.text:SetText(label .. ": " .. formatter(value))
        slider:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(addon.L["TOOLTIP_" .. name] or "No tooltip available.", 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        slider:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return slider
    end
    
    local function CreateCheckbox(name, label, checked, x, y)
        local checkbox = CreateFrame("CheckButton", "ChatEnhancer"..name.."Checkbox", frame, "UICheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", x, y)
        _G[checkbox:GetName() .. "Text"]:SetText(label)
        checkbox:SetChecked(checked)
        checkbox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(addon.L["TOOLTIP_" .. name] or "No tooltip available.", 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        checkbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return checkbox
    end
    
    local function CreateDropdown(name, label, options, default, x, y, onChange)
        local dropdown = CreateFrame("Frame", "ChatEnhancer"..name.."Dropdown", frame, "UIDropDownMenuTemplate")
        dropdown:SetPoint("TOPLEFT", x -15, y -13)
        UIDropDownMenu_SetWidth(dropdown, 100)
        UIDropDownMenu_SetText(dropdown, options[default])
        local function Initialize(self, level)
            for i, option in ipairs(options) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = option
                info.value = i
                info.func = function(self)
                    UIDropDownMenu_SetSelectedValue(dropdown, self.value)
                    UIDropDownMenu_SetText(dropdown, option)
                    onChange(self.value)
                    CloseDropDownMenus()
                end
                UIDropDownMenu_AddButton(info)
            end
        end
        UIDropDownMenu_Initialize(dropdown, Initialize)
        UIDropDownMenu_SetSelectedValue(dropdown, default)
        local labelText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        labelText:SetPoint("TOPLEFT", x + 5, y + 5)
        labelText:SetText(label)
        dropdown:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(addon.L["TOOLTIP_" .. name] or "No tooltip available.", 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        dropdown:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return dropdown
    end
    
    local function CreateEditBox(name, label, text, x, y, width, height, onTextChanged)
        local scrollFrame = CreateFrame("ScrollFrame", "ChatEnhancer"..name.."ScrollFrame", frame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", x, y)
        scrollFrame:SetSize(width, 60)
        local editBox = CreateFrame("EditBox", "ChatEnhancer"..name.."EditBox", scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetMaxLetters(1000)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject("ChatFontNormal")
        editBox:SetTextInsets(5, 5, 5, 5)
        editBox:SetText(text or "")
        editBox:SetSize(width - 20, height * 2)
        scrollFrame:SetScrollChild(editBox)
        local labelText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        labelText:SetPoint("TOPLEFT", x + 5, y + 20)
        labelText:SetText(label)
        editBox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(addon.L["TOOLTIP_" .. name] or "No tooltip available.", 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        editBox:SetScript("OnLeave", function() GameTooltip:Hide() end)
        editBox:SetScript("OnTextChanged", function(self, userInput)
            if userInput then
                onTextChanged(self:GetText())
            end
        end)
        return editBox
    end
    
    local function CreateSeparator(text, y)
        local separator = frame:CreateTexture(nil, "ARTWORK")
        separator:SetPoint("TOP", 0, y)
        separator:SetSize(380, 1)
        separator:SetColorTexture(1, 0.82, 0, 1)
        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOP", separator, "BOTTOM", 0, -5)
        label:SetText(text)
        label:SetTextColor(1, 0.82, 0)
        return separator
    end
    
    local leftX, rightX = 20, 210
    CreateSeparator(addon.L.SECTION_DISPLAY, -30)
    
    local fontSlider = CreateSlider("fontsize", addon.L.FONT_SIZE, 12, 28, cfg.fontSize, leftX, -60,
        function(v) return v end)
    fontSlider:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value)
        self.text:SetText(addon.L.FONT_SIZE .. ": " .. val)
        cfg.fontSize = val
        addon.updateDisplay()
    end)
    
    local fontOpacitySlider = CreateSlider("fontopacity", addon.L.FONT_OPACITY, 1, 10, cfg.fontOpacity * 10, rightX, -60,
        function(v) return (v/10) end)
    fontOpacitySlider:SetValueStep(1)
    fontOpacitySlider:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value) / 10
        self.text:SetText(addon.L.FONT_OPACITY .. ": " .. val)
        cfg.fontOpacity = val
        addon.updateDisplay()
    end)
    
    local timeSlider = CreateSlider("displaytime", addon.L.DISPLAY_TIME, 1, 8, cfg.timeVisible, leftX, -115,
        function(v) return v .. "s" end)
    timeSlider:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value)
        self.text:SetText(addon.L.DISPLAY_TIME .. ": " .. val .. "s")
        cfg.timeVisible = val
        addon.updateDisplay()
    end)
    
    CreateSeparator(addon.L.SECTION_FILTERS, -170)
    local questieCheck = CreateCheckbox("filterquestie", addon.L.FILTER_QUESTIE, cfg.filterQuestie, leftX, -200)
    questieCheck:SetScript("OnClick", function(self) cfg.filterQuestie = self:GetChecked() end)
    
    local ownMsgCheck = CreateCheckbox("filterown", addon.L.FILTER_OWN, cfg.filterOwnMessages, leftX, -230)
    ownMsgCheck:SetScript("OnClick", function(self) cfg.filterOwnMessages = self:GetChecked() end)
    
    CreateSeparator(addon.L.SECTION_BEHAVIOR, -270)
    local chatOrderCheck = CreateCheckbox("reversechat", addon.L.REVERSE_CHAT, cfg.chatOrder == "BOTTOM", leftX, -300)
    chatOrderCheck:SetScript("OnClick", function(self)
        cfg.chatOrder = self:GetChecked() and "BOTTOM" or "TOP"
        addon.updateDisplay()
    end)
    
    local showNamesCheck = CreateCheckbox("shownames", addon.L.SHOW_NAMES, cfg.showNames, leftX, -330)
    showNamesCheck:SetScript("OnClick", function(self) cfg.showNames = self:GetChecked() end)
    
    local showAllChatCheck = CreateCheckbox("showallchat", addon.L.SHOW_ALL_CHAT, cfg.showAllChat, leftX, -360)
    showAllChatCheck:SetScript("OnClick", function(self)
        cfg.showAllChat = self:GetChecked()
        local eventFrame = addon.eventFrame
        if cfg.showAllChat then
            eventFrame:RegisterEvent("CHAT_MSG_YELL")
            eventFrame:RegisterEvent("CHAT_MSG_SAY")
        else
            eventFrame:UnregisterEvent("CHAT_MSG_YELL")
            eventFrame:UnregisterEvent("CHAT_MSG_SAY")
        end
    end)
    
    local colorMessagesCheck = CreateCheckbox("colormessages", addon.L.COLOR_MESSAGES, cfg.colorMessages, rightX, -300)
    colorMessagesCheck:SetScript("OnClick", function(self) cfg.colorMessages = self:GetChecked() end)
    
    local locationOptions = {addon.L.LOCATION_DUNGEON, addon.L.LOCATION_WORLD, addon.L.LOCATION_BOTH}
    local locationDropdown = CreateDropdown("locationmode", addon.L.LOCATION_MODE, locationOptions, cfg.locationMode, rightX, -343,
        function(value) cfg.locationMode = value end)
    
    CreateSeparator(addon.L.SECTION_ALERT, -400)
    local alertKeywordsEditBox = CreateEditBox("alertkeywords", addon.L.ALERT_KEYWORDS, cfg.alertKeywords, leftX, -450, 160, 60,
        function(text) cfg.alertKeywords = text end)
    
    local highlightKeywordCheck = CreateCheckbox("highlightkeyword", addon.L.HIGHLIGHT_KEYWORD, cfg.highlightKeyword, rightX, -430)
    highlightKeywordCheck:SetScript("OnClick", function(self) cfg.highlightKeyword = self:GetChecked() end)
    
    local alertSoundCheck = CreateCheckbox("alertsound", addon.L.ALERT_SOUND, cfg.alertSound, rightX, -460)
    alertSoundCheck:SetScript("OnClick", function(self) cfg.alertSound = self:GetChecked() end)
    
    local alertModeEnabledCheck = CreateCheckbox("alertmodeenabled", addon.L.ALERT_MODE_ENABLED, cfg.alertModeEnabled, rightX, -490)
    alertModeEnabledCheck:SetScript("OnClick", function(self) cfg.alertModeEnabled = self:GetChecked() end)
    
    local resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetBtn:SetSize(80, 22)
    resetBtn:SetPoint("BOTTOM", 0, 20)
    resetBtn:SetText(addon.L.RESET_ALL)
    resetBtn:SetScript("OnClick", function()
        for k, v in pairs(addon.defaults) do
            cfg[k] = v
        end
        wipe(addon.activeMessages)
        addon.frame:ClearAllPoints()
        addon.frame:SetPoint(cfg.point, UIParent, cfg.point, cfg.x, cfg.y)
        addon.updateDisplay()
        fontSlider:SetValue(cfg.fontSize)
        timeSlider:SetValue(cfg.timeVisible)
        fontOpacitySlider:SetValue(cfg.fontOpacity * 10)
        chatOrderCheck:SetChecked(cfg.chatOrder == "BOTTOM")
        showNamesCheck:SetChecked(cfg.showNames)
        showAllChatCheck:SetChecked(cfg.showAllChat)
        questieCheck:SetChecked(cfg.filterQuestie)
        ownMsgCheck:SetChecked(cfg.filterOwnMessages)
        colorMessagesCheck:SetChecked(cfg.colorMessages)
        UIDropDownMenu_SetSelectedValue(locationDropdown, cfg.locationMode)
        UIDropDownMenu_SetText(locationDropdown, locationOptions[cfg.locationMode])
        alertKeywordsEditBox:SetText(cfg.alertKeywords)
        highlightKeywordCheck:SetChecked(cfg.highlightKeyword)
        alertSoundCheck:SetChecked(cfg.alertSound)
        alertModeEnabledCheck:SetChecked(cfg.alertModeEnabled)
        local eventFrame = addon.eventFrame
        if cfg.showAllChat then
            eventFrame:RegisterEvent("CHAT_MSG_YELL")
            eventFrame:RegisterEvent("CHAT_MSG_SAY")
        else
            eventFrame:UnregisterEvent("CHAT_MSG_YELL")
            eventFrame:UnregisterEvent("CHAT_MSG_SAY")
        end
        print(addon.L.RESET_CONFIRM)
    end)
    
    addon.optionsFrame = frame
end