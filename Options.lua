-- PurplePolice Options Panel
-- Handles all settings UI for the addon
local addonName, addon = ...

-- Store references for external access
addon.optionsCategory = nil
addon.characterCategory = nil
addon.inspectCategory = nil

-- Position options for dropdowns
local positionOptions = {
    { text = "Inside Character", value = "inside" },
    { text = "Outside Character", value = "outside" },
}

-- Helper function to create a checkbox in an options panel
local function CreateOptionsCheckbox(parent, yOffset, label, tooltipText, optionKey, updateFunc)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 16, yOffset)
    cb:SetSize(26, 26)
    
    local cbLabel = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cbLabel:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cbLabel:SetText(label)
    
    cb:SetChecked(addon.options[optionKey])
    cb.optionKey = optionKey
    
    cb:SetScript("OnClick", function(self)
        addon.options[optionKey] = self:GetChecked()
        if PurplePoliceDB then
            PurplePoliceDB[optionKey] = addon.options[optionKey]
        end
        if updateFunc then
            updateFunc()
        end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)
    
    cb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(label, 1, 1, 1)
        GameTooltip:AddLine(tooltipText, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    
    cb:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    return cb
end

-- Helper function to create a dropdown in an options panel
local function CreateOptionsDropdown(parent, yOffset, label, tooltipText, optionKey, dropdownOptions, updateFunc)
    local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", 16, yOffset)
    labelText:SetText(label)
    
    local dropdown = CreateFrame("Frame", "PurplePoliceDropdown_" .. optionKey, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 0, yOffset - 20)
    dropdown.optionKey = optionKey
    dropdown.dropdownOptions = dropdownOptions
    
    local function GetDisplayText()
        for _, opt in ipairs(dropdownOptions) do
            if opt.value == addon.options[optionKey] then
                return opt.text
            end
        end
        return dropdownOptions[1].text
    end
    
    UIDropDownMenu_SetWidth(dropdown, 150)
    UIDropDownMenu_SetText(dropdown, GetDisplayText())
    
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        for _, opt in ipairs(dropdownOptions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = opt.text
            info.value = opt.value
            info.checked = (addon.options[optionKey] == opt.value)
            info.func = function()
                addon.options[optionKey] = opt.value
                if PurplePoliceDB then
                    PurplePoliceDB[optionKey] = opt.value
                end
                UIDropDownMenu_SetText(dropdown, opt.text)
                CloseDropDownMenus()
                if updateFunc then
                    updateFunc()
                end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    
    return dropdown
end

-- Create the main options panel (just tooltip options)
local function CreateMainOptionsPanel()
    local optionsFrame = CreateFrame("Frame", "PurplePoliceMainOptionsPanel", UIParent)
    optionsFrame:SetSize(400, 200)
    
    -- Title
    local title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Purple Police")
    
    -- Description
    local desc = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(360)
    desc:SetJustifyH("LEFT")
    desc:SetText("Shows enchant status, socket indicators, and quality icons on your character and inspect frames. Expand the subcategories below for more options.")
    
    local yOffset = -80
    
    -- Tooltip Options Header
    local tooltipHeader = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    tooltipHeader:SetPoint("TOPLEFT", 16, yOffset)
    tooltipHeader:SetText("|cffffd700Tooltip Options|r")
    yOffset = yOffset - 30
    
    -- Show Item Level in Tooltips checkbox
    optionsFrame.showItemLevelCheckbox = CreateOptionsCheckbox(
        optionsFrame, yOffset,
        "Show Item Level in Tooltips |cffff8800(Experimental)|r",
        "Display the average item level of a player when hovering over them",
        "showItemLevelTooltip",
        nil -- No immediate update needed
    )
    
    return optionsFrame
end

-- Create the Character options subcategory panel
local function CreateCharacterOptionsPanel()
    local optionsFrame = CreateFrame("Frame", "PurplePoliceCharacterOptionsPanel", UIParent)
    optionsFrame:SetSize(400, 400)
    
    -- Title
    local title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff00ff00Character Frame Options|r")
    
    -- Description
    local desc = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(360)
    desc:SetJustifyH("LEFT")
    desc:SetText("Configure what enchant information is displayed on YOUR character panel.")
    
    local yOffset = -70
    
    -- Update function
    local function UpdateCharacterFrame()
        if CharacterFrame and CharacterFrame:IsShown() and addon.UpdateEnchantIcons then
            addon.UpdateEnchantIcons()
        end
    end
    
    -- Display Options Header
    local displayHeader = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    displayHeader:SetPoint("TOPLEFT", 16, yOffset)
    displayHeader:SetText("|cffffd700Display Options|r")
    yOffset = yOffset - 30
    
    -- Checkboxes
    CreateOptionsCheckbox(optionsFrame, yOffset, "Show Enchant Text",
        "Display the enchant name next to equipment slots", "showEnchantText", UpdateCharacterFrame)
    yOffset = yOffset - 30
    
    CreateOptionsCheckbox(optionsFrame, yOffset, "Show Side Indicators",
        "Display green/red bars on equipment slots to indicate enchant status", "showSideIndicators", UpdateCharacterFrame)
    yOffset = yOffset - 30
    
    CreateOptionsCheckbox(optionsFrame, yOffset, "Show Quality Icons",
        "Display the crafting quality tier icons (bronze/silver/gold) on enchanted items", "showQualityIcons", UpdateCharacterFrame)
    yOffset = yOffset - 30
    
    CreateOptionsCheckbox(optionsFrame, yOffset, "Show Socket Indicators",
        "Display socket status indicators on socketable equipment", "showSocketIndicators", UpdateCharacterFrame)
    yOffset = yOffset - 30
    
    CreateOptionsCheckbox(optionsFrame, yOffset, "Show 'Missing Enchant' Text",
        "Display 'Missing Enchant' text on items that need enchants", "showMissingEnchantText", UpdateCharacterFrame)
    yOffset = yOffset - 40
    
    -- Position Options Header
    local positionHeader = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    positionHeader:SetPoint("TOPLEFT", 16, yOffset)
    positionHeader:SetText("|cffffd700Position Options|r")
    yOffset = yOffset - 30
    
    -- Dropdowns
    CreateOptionsDropdown(optionsFrame, yOffset, "Side Indicator Position:",
        "Where to display the green/red side indicators", "sideIndicatorPosition", positionOptions, UpdateCharacterFrame)
    yOffset = yOffset - 60
    
    CreateOptionsDropdown(optionsFrame, yOffset, "Text Position:",
        "Where to display the enchant name text", "textPosition", positionOptions, UpdateCharacterFrame)
    
    return optionsFrame
end

-- Create the Inspect options subcategory panel
local function CreateInspectOptionsPanel()
    local optionsFrame = CreateFrame("Frame", "PurplePoliceInspectOptionsPanel", UIParent)
    optionsFrame:SetSize(400, 400)
    
    -- Title
    local title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff00ffffInspect Frame Options|r")
    
    -- Description
    local desc = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(360)
    desc:SetJustifyH("LEFT")
    desc:SetText("Configure what enchant information is displayed when inspecting OTHER players.")
    
    local yOffset = -70
    
    -- Update function
    local function UpdateInspectFrame()
        if InspectFrame and InspectFrame:IsShown() and addon.UpdateInspectEnchantIcons then
            addon.UpdateInspectEnchantIcons()
        end
    end
    
    -- Display Options Header
    local displayHeader = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    displayHeader:SetPoint("TOPLEFT", 16, yOffset)
    displayHeader:SetText("|cffffd700Display Options|r")
    yOffset = yOffset - 30
    
    -- Checkboxes
    CreateOptionsCheckbox(optionsFrame, yOffset, "Show Enchant Text",
        "Display the enchant name next to equipment slots", "inspectShowEnchantText", UpdateInspectFrame)
    yOffset = yOffset - 30
    
    CreateOptionsCheckbox(optionsFrame, yOffset, "Show Side Indicators",
        "Display green/red bars on equipment slots to indicate enchant status", "inspectShowSideIndicators", UpdateInspectFrame)
    yOffset = yOffset - 30
    
    CreateOptionsCheckbox(optionsFrame, yOffset, "Show Quality Icons",
        "Display the crafting quality tier icons (bronze/silver/gold) on enchanted items", "inspectShowQualityIcons", UpdateInspectFrame)
    yOffset = yOffset - 30
    
    CreateOptionsCheckbox(optionsFrame, yOffset, "Show Socket Indicators",
        "Display socket status indicators on socketable equipment", "inspectShowSocketIndicators", UpdateInspectFrame)
    yOffset = yOffset - 30
    
    CreateOptionsCheckbox(optionsFrame, yOffset, "Show 'Missing Enchant' Text",
        "Display 'Missing Enchant' text on items that need enchants", "inspectShowMissingEnchantText", UpdateInspectFrame)
    yOffset = yOffset - 40
    
    -- Position Options Header
    local positionHeader = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    positionHeader:SetPoint("TOPLEFT", 16, yOffset)
    positionHeader:SetText("|cffffd700Position Options|r")
    yOffset = yOffset - 30
    
    -- Dropdowns
    CreateOptionsDropdown(optionsFrame, yOffset, "Side Indicator Position:",
        "Where to display the green/red side indicators", "inspectSideIndicatorPosition", positionOptions, UpdateInspectFrame)
    yOffset = yOffset - 60
    
    CreateOptionsDropdown(optionsFrame, yOffset, "Text Position:",
        "Where to display the enchant name text", "inspectTextPosition", positionOptions, UpdateInspectFrame)
    
    return optionsFrame
end

-- Initialize all options panels and register with Settings API
function addon.InitializeOptions()
    -- Create the main options panel
    local mainPanel = CreateMainOptionsPanel()
    
    -- Register main category
    addon.optionsCategory = Settings.RegisterCanvasLayoutCategory(mainPanel, "Purple Police")
    Settings.RegisterAddOnCategory(addon.optionsCategory)
    
    -- Create and register Character subcategory
    local characterPanel = CreateCharacterOptionsPanel()
    addon.characterCategory = Settings.RegisterCanvasLayoutSubcategory(addon.optionsCategory, characterPanel, "Character")
    
    -- Create and register Inspect subcategory
    local inspectPanel = CreateInspectOptionsPanel()
    addon.inspectCategory = Settings.RegisterCanvasLayoutSubcategory(addon.optionsCategory, inspectPanel, "Inspect")
end

-- ============================================================================
-- POPUP OPTIONS PANEL (Quick access from Character/Inspect frames)
-- ============================================================================

-- Popup options panel reference
local popupOptionsFrame = nil

-- Create the quick popup options panel
local function CreatePopupOptionsPanel()
    if popupOptionsFrame then return popupOptionsFrame end
    
    local popup = CreateFrame("Frame", "PurplePolicePopupOptions", UIParent, "BackdropTemplate")
    popup:SetSize(280, 370)
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(100)
    popup:SetMovable(true)
    popup:EnableMouse(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
    popup:SetClampedToScreen(true)
    
    -- Backdrop
    popup:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    
    -- Title bar
    local titleBg = popup:CreateTexture(nil, "ARTWORK")
    titleBg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    titleBg:SetSize(160, 64)
    titleBg:SetPoint("TOP", popup, "TOP", 0, 12)
    
    local title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", popup, "TOP", 0, -4)
    title:SetText("Purple Police")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() popup:Hide() end)
    
    -- Store references
    popup.checkboxes = {}
    popup.dropdowns = {}
    popup.tabs = {}
    popup.tabContents = {}
    
    -- Update function for character frame
    local function UpdateCharacterFrame()
        if CharacterFrame and CharacterFrame:IsShown() and addon.UpdateEnchantIcons then
            addon.UpdateEnchantIcons()
        end
    end
    
    -- Update function for inspect frame
    local function UpdateInspectFrame()
        if InspectFrame and InspectFrame:IsShown() and addon.UpdateInspectEnchantIcons then
            addon.UpdateInspectEnchantIcons()
        end
    end
    
    -- Position options for dropdowns
    local popupPositionOptions = {
        { text = "Inside Character", value = "inside" },
        { text = "Outside Character", value = "outside" },
    }
    
    -- Create tab buttons with custom color
    local function CreateTabButton(text, tabIndex, r, g, b)
        local tab = CreateFrame("Button", nil, popup)
        tab:SetSize(120, 28)
        tab:SetNormalFontObject("GameFontNormal")
        tab:SetHighlightFontObject("GameFontHighlight")
        tab:SetText(text)
        tab.tabIndex = tabIndex
        tab.color = {r = r, g = g, b = b}
        
        -- Tab background
        tab.bg = tab:CreateTexture(nil, "BACKGROUND")
        tab.bg:SetAllPoints()
        tab.bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
        
        -- Selected highlight (colored tint)
        tab.selected = tab:CreateTexture(nil, "BORDER")
        tab.selected:SetAllPoints()
        tab.selected:SetColorTexture(r, g, b, 0.3)
        tab.selected:Hide()
        
        -- Bottom border when selected (matches tab color)
        tab.activeBorder = tab:CreateTexture(nil, "ARTWORK")
        tab.activeBorder:SetHeight(3)
        tab.activeBorder:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
        tab.activeBorder:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)
        tab.activeBorder:SetColorTexture(r, g, b, 1)
        tab.activeBorder:Hide()
        
        return tab
    end
    
    -- Create content container for a tab with colored header
    local function CreateTabContent(parent, headerText, r, g, b)
        local content = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        content:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -70)
        content:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -12, 12)
        
        -- Subtle colored background tint
        content:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        content:SetBackdropColor(r, g, b, 0.1)
        content:SetBackdropBorderColor(r, g, b, 0.3)
        
        -- Colored header bar at the top
        content.header = CreateFrame("Frame", nil, content, "BackdropTemplate")
        content.header:SetHeight(24)
        content.header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        content.header:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
        content.header:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
        })
        content.header:SetBackdropColor(r, g, b, 0.4)
        
        -- Header text
        content.headerText = content.header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        content.headerText:SetPoint("CENTER", content.header, "CENTER", 0, 0)
        content.headerText:SetText(headerText)
        content.headerText:SetTextColor(1, 1, 1, 1)
        
        -- Icon in the header
        content.headerIcon = content.header:CreateTexture(nil, "ARTWORK")
        content.headerIcon:SetSize(16, 16)
        content.headerIcon:SetPoint("RIGHT", content.headerText, "LEFT", -6, 0)
        
        content:Hide()
        return content
    end
    
    -- Helper function to create a checkbox within a content frame
    local function CreateContentCheckbox(parent, yOffset, label, optionKey, updateFunc)
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 4, yOffset)
        cb:SetSize(26, 26)
        
        local cbLabel = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cbLabel:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        cbLabel:SetText(label)
        
        cb:SetChecked(addon.options[optionKey])
        cb.optionKey = optionKey
        
        cb:SetScript("OnClick", function(self)
            addon.options[optionKey] = self:GetChecked()
            if PurplePoliceDB then
                PurplePoliceDB[optionKey] = addon.options[optionKey]
            end
            if updateFunc then
                updateFunc()
            end
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end)
        
        return cb
    end
    
    -- Helper function to create a dropdown within a content frame
    local function CreateContentDropdown(parent, yOffset, label, optionKey, dropdownOptions, updateFunc)
        local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        labelText:SetPoint("TOPLEFT", 4, yOffset)
        labelText:SetText(label)
        
        local dropdown = CreateFrame("Frame", "PurplePolicePopupDropdown_" .. optionKey, parent, "UIDropDownMenuTemplate")
        dropdown:SetPoint("TOPLEFT", -8, yOffset - 18)
        dropdown.optionKey = optionKey
        dropdown.dropdownOptions = dropdownOptions
        
        local function GetDisplayText()
            for _, opt in ipairs(dropdownOptions) do
                if opt.value == addon.options[optionKey] then
                    return opt.text
                end
            end
            return dropdownOptions[1].text
        end
        
        UIDropDownMenu_SetWidth(dropdown, 150)
        UIDropDownMenu_SetText(dropdown, GetDisplayText())
        
        UIDropDownMenu_Initialize(dropdown, function(self, level)
            for _, opt in ipairs(dropdownOptions) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = opt.text
                info.value = opt.value
                info.checked = (addon.options[optionKey] == opt.value)
                info.func = function()
                    addon.options[optionKey] = opt.value
                    if PurplePoliceDB then
                        PurplePoliceDB[optionKey] = opt.value
                    end
                    UIDropDownMenu_SetText(dropdown, opt.text)
                    CloseDropDownMenus()
                    if updateFunc then
                        updateFunc()
                    end
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        
        return dropdown
    end
    
    -- Create the two tabs with matching colors
    local charTab = CreateTabButton("|cff00ff00Character|r", 1, 0, 0.8, 0)
    charTab:SetPoint("TOPLEFT", popup, "TOPLEFT", 16, -35)
    popup.tabs[1] = charTab
    
    local inspectTab = CreateTabButton("|cff00ffffInspect|r", 2, 0, 0.8, 1)
    inspectTab:SetPoint("LEFT", charTab, "RIGHT", 4, 0)
    popup.tabs[2] = inspectTab
    
    -- Create content frames for each tab (with distinct colors)
    -- Character tab: Green theme (0, 0.8, 0)
    local charContent = CreateTabContent(popup, "Your Character", 0, 0.8, 0)
    charContent.headerIcon:SetAtlas("UI-HUD-UnitFrame-Player-PortraitOn-Status")
    popup.tabContents[1] = charContent
    
    -- Inspect tab: Cyan theme (0, 1, 1)
    local inspectContent = CreateTabContent(popup, "Inspecting Others", 0, 0.8, 1)
    inspectContent.headerIcon:SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn-Status")
    popup.tabContents[2] = inspectContent
    
    -- Populate Character tab content (offset to account for header)
    local yOff = -30
    popup.checkboxes.showEnchantText = CreateContentCheckbox(charContent, yOff, "Show Enchant Text", "showEnchantText", UpdateCharacterFrame)
    yOff = yOff - 26
    popup.checkboxes.showSideIndicators = CreateContentCheckbox(charContent, yOff, "Show Side Indicators", "showSideIndicators", UpdateCharacterFrame)
    yOff = yOff - 26
    popup.checkboxes.showQualityIcons = CreateContentCheckbox(charContent, yOff, "Show Quality Icons", "showQualityIcons", UpdateCharacterFrame)
    yOff = yOff - 26
    popup.checkboxes.showSocketIndicators = CreateContentCheckbox(charContent, yOff, "Show Socket Indicators", "showSocketIndicators", UpdateCharacterFrame)
    yOff = yOff - 26
    popup.checkboxes.showMissingEnchantText = CreateContentCheckbox(charContent, yOff, "Show 'Missing Enchant' Text", "showMissingEnchantText", UpdateCharacterFrame)
    yOff = yOff - 35
    popup.dropdowns.sideIndicatorPosition = CreateContentDropdown(charContent, yOff, "Side Indicator Position:", "sideIndicatorPosition", popupPositionOptions, UpdateCharacterFrame)
    yOff = yOff - 55
    popup.dropdowns.textPosition = CreateContentDropdown(charContent, yOff, "Text Position:", "textPosition", popupPositionOptions, UpdateCharacterFrame)
    
    -- Populate Inspect tab content (offset to account for header)
    yOff = -30
    popup.checkboxes.inspectShowEnchantText = CreateContentCheckbox(inspectContent, yOff, "Show Enchant Text", "inspectShowEnchantText", UpdateInspectFrame)
    yOff = yOff - 26
    popup.checkboxes.inspectShowSideIndicators = CreateContentCheckbox(inspectContent, yOff, "Show Side Indicators", "inspectShowSideIndicators", UpdateInspectFrame)
    yOff = yOff - 26
    popup.checkboxes.inspectShowQualityIcons = CreateContentCheckbox(inspectContent, yOff, "Show Quality Icons", "inspectShowQualityIcons", UpdateInspectFrame)
    yOff = yOff - 26
    popup.checkboxes.inspectShowSocketIndicators = CreateContentCheckbox(inspectContent, yOff, "Show Socket Indicators", "inspectShowSocketIndicators", UpdateInspectFrame)
    yOff = yOff - 26
    popup.checkboxes.inspectShowMissingEnchantText = CreateContentCheckbox(inspectContent, yOff, "Show 'Missing Enchant' Text", "inspectShowMissingEnchantText", UpdateInspectFrame)
    yOff = yOff - 35
    popup.dropdowns.inspectSideIndicatorPosition = CreateContentDropdown(inspectContent, yOff, "Side Indicator Position:", "inspectSideIndicatorPosition", popupPositionOptions, UpdateInspectFrame)
    yOff = yOff - 55
    popup.dropdowns.inspectTextPosition = CreateContentDropdown(inspectContent, yOff, "Text Position:", "inspectTextPosition", popupPositionOptions, UpdateInspectFrame)
    
    -- Tab switching function
    local function SelectTab(tabIndex)
        for i, tab in ipairs(popup.tabs) do
            if i == tabIndex then
                tab.selected:Show()
                tab.activeBorder:Show()
                popup.tabContents[i]:Show()
            else
                tab.selected:Hide()
                tab.activeBorder:Hide()
                popup.tabContents[i]:Hide()
            end
        end
        popup.selectedTab = tabIndex
    end
    
    -- Set up tab click handlers
    charTab:SetScript("OnClick", function() SelectTab(1) end)
    inspectTab:SetScript("OnClick", function() SelectTab(2) end)
    
    -- Default to character tab
    SelectTab(1)
    
    -- Refresh function to update UI from current options
    popup.Refresh = function(self)
        for key, cb in pairs(self.checkboxes) do
            cb:SetChecked(addon.options[key])
        end
        for key, dd in pairs(self.dropdowns) do
            for _, opt in ipairs(dd.dropdownOptions) do
                if opt.value == addon.options[key] then
                    UIDropDownMenu_SetText(dd, opt.text)
                    break
                end
            end
        end
    end
    
    -- Function to select tab by name (for auto-selecting based on context)
    popup.SelectTab = SelectTab
    
    popup:Hide()
    popupOptionsFrame = popup
    return popup
end

-- Toggle the popup options panel
function addon.TogglePopupOptions(anchorFrame, tabIndex)
    if not popupOptionsFrame then
        CreatePopupOptionsPanel()
    end
    
    if popupOptionsFrame:IsShown() then
        popupOptionsFrame:Hide()
    else
        -- Position to the right of the anchor frame (character or inspect frame)
        popupOptionsFrame:ClearAllPoints()
        local frame = anchorFrame or CharacterFrame
        popupOptionsFrame:SetPoint("TOPLEFT", frame, "TOPRIGHT", 5, 0)
        popupOptionsFrame:Refresh()
        -- Auto-select the appropriate tab (1 = Character, 2 = Inspect)
        if tabIndex and popupOptionsFrame.SelectTab then
            popupOptionsFrame.SelectTab(tabIndex)
        end
        popupOptionsFrame:Show()
    end
end

-- Get the popup frame reference
function addon.GetPopupOptionsFrame()
    return popupOptionsFrame
end
