-- PurplePolice: Shows enchant status and rank icons on enchantable gear
local addonName, addon = ...

-- Enchantable slot IDs and their corresponding frame names
local ENCHANTABLE_SLOTS = {
    { slotID = 16, frameName = "CharacterMainHandSlot" },   -- Main Hand Weapon
    { slotID = 17, frameName = "CharacterSecondaryHandSlot" }, -- Off Hand
    { slotID = 9,  frameName = "CharacterWristSlot" },      -- Bracers
    { slotID = 5,  frameName = "CharacterChestSlot" },      -- Chest
    { slotID = 15, frameName = "CharacterBackSlot" },       -- Cloak
    { slotID = 7,  frameName = "CharacterLegsSlot" },       -- Pants
    { slotID = 8,  frameName = "CharacterFeetSlot" },       -- Boots
    { slotID = 11, frameName = "CharacterFinger0Slot" },    -- Ring 1
    { slotID = 12, frameName = "CharacterFinger1Slot" },    -- Ring 2
}

-- Slots that can have sockets and their max socket count
local SOCKETABLE_SLOTS = {
    { slotID = 2,  frameName = "CharacterNeckSlot", maxSockets = 2 },     -- Neck
    { slotID = 11, frameName = "CharacterFinger0Slot", maxSockets = 2 },  -- Ring 1
    { slotID = 12, frameName = "CharacterFinger1Slot", maxSockets = 2 },  -- Ring 2
    { slotID = 6,  frameName = "CharacterWaistSlot", maxSockets = 1 },    -- Belt
    { slotID = 9,  frameName = "CharacterWristSlot", maxSockets = 1 },    -- Bracer
    { slotID = 1,  frameName = "CharacterHeadSlot", maxSockets = 1 },     -- Helm
}

-- Inspect frame slot definitions
local INSPECT_ENCHANTABLE_SLOTS = {
    { slotID = 16, frameName = "InspectMainHandSlot" },   -- Main Hand Weapon
    { slotID = 17, frameName = "InspectSecondaryHandSlot" }, -- Off Hand
    { slotID = 9,  frameName = "InspectWristSlot" },      -- Bracers
    { slotID = 5,  frameName = "InspectChestSlot" },      -- Chest
    { slotID = 15, frameName = "InspectBackSlot" },       -- Cloak
    { slotID = 7,  frameName = "InspectLegsSlot" },       -- Pants
    { slotID = 8,  frameName = "InspectFeetSlot" },       -- Boots
    { slotID = 11, frameName = "InspectFinger0Slot" },    -- Ring 1
    { slotID = 12, frameName = "InspectFinger1Slot" },    -- Ring 2
}

-- Inspect frame socketable slots
local INSPECT_SOCKETABLE_SLOTS = {
    { slotID = 2,  frameName = "InspectNeckSlot", maxSockets = 2 },     -- Neck
    { slotID = 11, frameName = "InspectFinger0Slot", maxSockets = 2 },  -- Ring 1
    { slotID = 12, frameName = "InspectFinger1Slot", maxSockets = 2 },  -- Ring 2
    { slotID = 6,  frameName = "InspectWaistSlot", maxSockets = 1 },    -- Belt
    { slotID = 9,  frameName = "InspectWristSlot", maxSockets = 1 },    -- Bracer
    { slotID = 1,  frameName = "InspectHeadSlot", maxSockets = 1 },     -- Helm
}

-- Crafting quality icons (same as enchant rank icons in Dragonflight+)
-- These are the pip/gem icons used for crafting quality tiers
local RANK_ICONS = {
    [1] = "Professions-Icon-Quality-Tier1-Small",  -- Bronze/Copper (Rank 1)
    [2] = "Professions-Icon-Quality-Tier2-Small",  -- Silver (Rank 2)
    [3] = "Professions-Icon-Quality-Tier3-Small",  -- Gold (Rank 3)
}

-- Alternative: Use the larger versions if needed
-- "Professions-Icon-Quality-Tier1-Inv" (inventory size)
-- "Professions-ChatIcon-Quality-Tier1" (chat icon size)

-- Store references to our icon frames
local enchantIcons = {}
local unenchantedBorders = {}
local enchantTextLabels = {}
local enchantSideIndicators = {} -- Green/red side indicators for enchant status
local socketIndicators = {} -- Store socket indicator frames per slot
local toggleButton = nil

-- Inspect frame UI element storage (separate from character frame)
local inspectEnchantIcons = {}
local inspectUnenchantedBorders = {}
local inspectEnchantTextLabels = {}
local inspectEnchantSideIndicators = {}
local inspectSocketIndicators = {}
local inspectToggleButton = nil

-- Default options
local defaults = {
    showEnchantText = false,           -- Show enchant name text (hidden by default)
    showSideIndicators = true,         -- Show green/red side indicators
    showQualityIcons = true,           -- Show quality tier icons
    showSocketIndicators = true,       -- Show socket indicators
    showMissingEnchantText = false,    -- Show "Missing Enchant" text when missing (hidden by default)
    sideIndicatorPosition = "outside", -- "inside" or "outside" of character frame
    textPosition = "inside",           -- "inside" or "outside" of character frame
    -- Inspect frame options (separate from character frame)
    inspectShowEnchantText = false,
    inspectShowSideIndicators = true,
    inspectShowQualityIcons = true,
    inspectShowSocketIndicators = true,
    inspectShowMissingEnchantText = false,
    inspectSideIndicatorPosition = "outside",
    inspectTextPosition = "inside",
    -- Tooltip options
    showItemLevelTooltip = true,       -- Show item level in player tooltips
}

-- Current options (will be loaded from SavedVariables)
-- Store in addon table for access from Options.lua
local options = {}
addon.options = options

-- Create a side indicator (colored bar on one side of the slot)
local function CreateEnchantSideIndicator(slotFrame, slotID)
    local indicator = CreateFrame("Frame", "AmIEnchantedSideIndicator" .. slotID, slotFrame)
    indicator:SetFrameStrata("HIGH")
    indicator:SetSize(4, slotFrame:GetHeight() - 4)
    indicator:EnableMouse(false) -- Don't block mouse events from reaching slot
    
    -- Create the colored texture
    indicator.texture = indicator:CreateTexture(nil, "OVERLAY")
    indicator.texture:SetAllPoints(indicator)
    indicator.texture:SetColorTexture(0, 1, 0, 0.8) -- Default green
    
    -- Store slotID for repositioning
    indicator.slotID = slotID
    
    indicator:Hide()
    return indicator
end

-- Update side indicator position based on options
local function UpdateSideIndicatorPosition(indicator, slotFrame, slotID)
    indicator:ClearAllPoints()
    
    -- Determine which side to show the indicator based on slot position and option
    -- "inside" = towards center of character frame (but outside the slot)
    -- "outside" = away from center of character frame (but outside the slot)
    local isLeftSideSlot = (slotID == 9 or slotID == 5 or slotID == 15) -- Wrist, Chest, Cloak
    local isBottomSlot = (slotID == 16 or slotID == 17) -- Weapons
    local isRightSideSlot = (slotID == 7 or slotID == 8 or slotID == 11 or slotID == 12) -- Legs, Feet, Rings
    
    local positionInside = (options.sideIndicatorPosition == "inside")
    
    if isLeftSideSlot then
        -- Left side of character frame
        if positionInside then
            -- Inside = right side of slot (towards character center)
            indicator:SetPoint("LEFT", slotFrame, "RIGHT", 2, 0)
        else
            -- Outside = left side of slot (away from character)
            indicator:SetPoint("RIGHT", slotFrame, "LEFT", -2, 0)
        end
    elseif isRightSideSlot then
        -- Right side of character frame
        if positionInside then
            -- Inside = left side of slot (towards character center)
            indicator:SetPoint("RIGHT", slotFrame, "LEFT", -2, 0)
        else
            -- Outside = right side of slot (away from character)
            indicator:SetPoint("LEFT", slotFrame, "RIGHT", 2, 0)
        end
    elseif isBottomSlot then
        -- Weapons at bottom
        if slotID == 16 then -- Main hand (left weapon)
            if positionInside then
                -- Inside = right side of slot (towards character center)
                indicator:SetPoint("LEFT", slotFrame, "RIGHT", 2, 0)
            else
                -- Outside = left side of slot (away from character)
                indicator:SetPoint("RIGHT", slotFrame, "LEFT", -2, 0)
            end
        else -- Off hand (right weapon)
            if positionInside then
                -- Inside = left side of slot (towards character center)
                indicator:SetPoint("RIGHT", slotFrame, "LEFT", -2, 0)
            else
                -- Outside = right side of slot (away from character)
                indicator:SetPoint("LEFT", slotFrame, "RIGHT", 2, 0)
            end
        end
    else
        indicator:SetPoint("RIGHT", slotFrame, "RIGHT", -2, 0)
    end
end

-- Create a red border frame to highlight unenchanted gear (kept for compatibility but may not be used)
local function CreateUnenchantedBorder(slotFrame, slotID)
    local border = CreateFrame("Frame", "AmIEnchantedBorder" .. slotID, slotFrame, "BackdropTemplate")
    border:SetSize(slotFrame:GetWidth() + 4, slotFrame:GetHeight() + 4)
    border:SetPoint("CENTER", slotFrame, "CENTER", 0, 0)
    border:SetFrameStrata("HIGH")
    border:EnableMouse(false) -- Don't block mouse events from reaching slot
    
    -- Create red border using backdrop
    border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    border:SetBackdropBorderColor(1, 0, 0, 0.9) -- Bright red
    
    -- Add a subtle glow effect
    border.glow = border:CreateTexture(nil, "BACKGROUND")
    border.glow:SetPoint("TOPLEFT", border, "TOPLEFT", -2, 2)
    border.glow:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 2, -2)
    border.glow:SetColorTexture(1, 0, 0, 0.15)
    
    border:Hide()
    return border
end

-- Get the enchant name from an item's tooltip
local function GetEnchantName(itemLink)
    if not itemLink then return nil end
    
    -- Check if item has an enchant first
    local enchantID = itemLink:match("item:%d+:(%d+)")
    if not enchantID or tonumber(enchantID) == 0 then
        return nil -- No enchant
    end
    
    -- Use C_TooltipInfo API to get enchant name
    local tooltipData = C_TooltipInfo.GetHyperlink(itemLink)
    if tooltipData and tooltipData.lines then
        for _, lineData in ipairs(tooltipData.lines) do
            if lineData.leftText then
                local text = lineData.leftText
                -- Enchant lines typically are green and contain quality tier icons or enchant names
                -- Look for lines with the enchant pattern - they usually start with "Enchanted:" or contain tier icons
                -- Remove atlas icons from text for clean display
                local cleanText = text:gsub("|A:[^|]+|a", ""):gsub("%s+", " "):trim()
                
                -- Check if this line has tier quality icons (indicates it's an enchant line)
                if text:find("Professions%-ChatIcon%-Quality%-Tier") or text:find("|A:Professions") then
                    -- This is an enchant line, extract the name
                    if cleanText and cleanText ~= "" then
                        -- Remove "Enchanted: " prefix if present
                        cleanText = cleanText:gsub("^Enchanted:%s*", "")
                        return cleanText
                    end
                end
            end
        end
    end
    
    -- Fallback: scan traditional tooltip for green text enchant lines
    if not addon.scanTooltip then
        addon.scanTooltip = CreateFrame("GameTooltip", "AmIEnchantedScanTooltip", nil, "GameTooltipTemplate")
        addon.scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    
    local tooltip = addon.scanTooltip
    tooltip:ClearLines()
    tooltip:SetHyperlink(itemLink)
    
    for i = 1, tooltip:NumLines() do
        local line = _G["AmIEnchantedScanTooltipTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text then
                local r, g, b = line:GetTextColor()
                -- Green text (enchants) or text with quality tier icons
                if (g > 0.9 and r < 0.2 and b < 0.2) or text:find("Professions%-ChatIcon%-Quality%-Tier") then
                    if not text:find("Socket") and not text:find("socket") then
                        local cleanText = text:gsub("|A:[^|]+|a", ""):gsub("%s+", " "):trim()
                        if cleanText and cleanText ~= "" then
                            -- Remove "Enchanted: " prefix if present
                            cleanText = cleanText:gsub("^Enchanted:%s*", "")
                            return cleanText
                        end
                    end
                end
            end
        end
    end
    
    return nil
end

-- Create a text label for showing enchant name
local function CreateEnchantTextLabel(slotFrame, slotID)
    local label = slotFrame:CreateFontString("AmIEnchantedText" .. slotID, "OVERLAY", "GameFontNormal")
    label:SetTextColor(0, 1, 0, 1) -- Green text
    label:SetShadowOffset(2, -2)
    label:SetShadowColor(0, 0, 0, 1)
    label.slotID = slotID -- Store for repositioning
    label:SetWidth(120) -- Max width to prevent overflow
    label:Hide()
    return label
end

-- Update text label position based on options
local function UpdateTextLabelPosition(label, slotFrame, slotID)
    label:ClearAllPoints()
    
    local positionInside = (options.textPosition == "inside")
    
    -- Position based on slot type
    if slotID == 16 then
        -- Main hand weapon - text to the LEFT of the slot
        if positionInside then
            label:SetPoint("BOTTOMRIGHT", slotFrame, "BOTTOMLEFT", -4, 0)
            label:SetJustifyH("RIGHT")
        else
            label:SetPoint("BOTTOMLEFT", slotFrame, "BOTTOMRIGHT", 4, 0)
            label:SetJustifyH("LEFT")
        end
    elseif slotID == 17 then
        -- Off hand - text to the RIGHT of the slot
        if positionInside then
            label:SetPoint("BOTTOMLEFT", slotFrame, "BOTTOMRIGHT", 4, 0)
            label:SetJustifyH("LEFT")
        else
            label:SetPoint("BOTTOMRIGHT", slotFrame, "BOTTOMLEFT", -4, 0)
            label:SetJustifyH("RIGHT")
        end
    elseif slotID == 9 or slotID == 5 or slotID == 15 then
        -- Wrist, Chest, Cloak (left side slots)
        if positionInside then
            label:SetPoint("LEFT", slotFrame, "RIGHT", 4, 0)
            label:SetJustifyH("LEFT")
        else
            label:SetPoint("RIGHT", slotFrame, "LEFT", -4, 0)
            label:SetJustifyH("RIGHT")
        end
    elseif slotID == 11 or slotID == 12 then
        -- Rings (right side slots)
        if positionInside then
            label:SetPoint("RIGHT", slotFrame, "LEFT", -4, 0)
            label:SetJustifyH("RIGHT")
        else
            label:SetPoint("LEFT", slotFrame, "RIGHT", 4, 0)
            label:SetJustifyH("LEFT")
        end
    else
        -- Legs, Feet (bottom slots)
        if positionInside then
            label:SetPoint("RIGHT", slotFrame, "LEFT", -4, 0)
            label:SetJustifyH("RIGHT")
        else
            label:SetPoint("LEFT", slotFrame, "RIGHT", 4, 0)
            label:SetJustifyH("LEFT")
        end
    end
end

-- Create a single socket indicator (black square with red border when missing)
local function CreateSocketIndicator(parent, index)
    local indicator = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    indicator:SetSize(12, 12)
    indicator:EnableMouse(false) -- Don't block mouse events from reaching slot
    indicator:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    -- Default to "missing" state (black with red border)
    indicator:SetBackdropColor(0, 0, 0, 0.9)
    indicator:SetBackdropBorderColor(1, 0, 0, 1)
    indicator:Hide()
    return indicator
end

-- Create socket indicators for a slot (up to maxSockets)
local function CreateSocketIndicators(slotFrame, slotID, maxSockets)
    local indicators = {}
    for i = 1, maxSockets do
        local indicator = CreateSocketIndicator(slotFrame, i)
        indicator:SetFrameStrata("HIGH")
        indicator.slotID = slotID -- Store for repositioning
        indicator.index = i
        indicators[i] = indicator
    end
    return indicators
end

-- Update socket indicator positions based on current options
local function UpdateSocketIndicatorPositions(indicators, slotFrame, slotID)
    if not indicators or #indicators == 0 then return end
    
    -- Check if this is a right-side slot (rings, belt)
    local isRightSideSlot = (slotID == 11 or slotID == 12 or slotID == 6) -- Ring 1, Ring 2, Belt
    
    -- Position indicators at the top of the slot, side by side
    -- Socket indicators are inside the icon, side indicators are on the edge
    for i, indicator in ipairs(indicators) do
        indicator:ClearAllPoints()
        if isRightSideSlot then
            -- Right side slots - position from top-right, going left
            if i == 1 then
                indicator:SetPoint("TOPRIGHT", slotFrame, "TOPRIGHT", -2, -2)
            else
                indicator:SetPoint("RIGHT", indicators[i-1], "LEFT", -2, 0)
            end
        else
            -- Left side and center slots - position from top-left, going right
            if i == 1 then
                indicator:SetPoint("TOPLEFT", slotFrame, "TOPLEFT", 2, -2)
            else
                indicator:SetPoint("LEFT", indicators[i-1], "RIGHT", 2, 0)
            end
        end
    end
end

-- Check socket status for an item
-- Returns: hasItem, totalSockets, filledSockets, missingGems
local function CheckSocketStatus(slotID)
    local itemLink = GetInventoryItemLink("player", slotID)
    
    if not itemLink then
        return false, 0, 0, 0
    end
    
    local totalSockets = 0
    local filledSockets = 0
    
    -- Parse the item link for gem IDs
    -- Modern item link format has gems at positions 5, 6, 7, 8 when split by ":"
    -- (after color, Hitem, itemID, enchantID)
    local linkParts = {strsplit(":", itemLink)}
    for i = 5, 8 do
        local gemID = tonumber(linkParts[i])
        if gemID and gemID > 0 then
            filledSockets = filledSockets + 1
        end
    end
    
    -- Use GetItemGem to check each socket slot (this counts total sockets)
    -- GetItemGem returns gemName, gemLink for filled sockets
    for socketIndex = 1, 4 do
        local gemName, gemLink = C_Item.GetItemGem(itemLink, socketIndex)
        if gemName or gemLink then
            -- This socket exists and has a gem
            totalSockets = math.max(totalSockets, socketIndex)
        end
    end
    
    -- Alternative: Use tooltip scanning to find socket info
    -- Create scanning tooltip if needed
    if not addon.scanTooltip then
        addon.scanTooltip = CreateFrame("GameTooltip", "AmIEnchantedScanTooltip", nil, "GameTooltipTemplate")
        addon.scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    
    local tooltip = addon.scanTooltip
    tooltip:ClearLines()
    tooltip:SetInventoryItem("player", slotID)
    
    -- Scan tooltip for socket information
    for i = 1, tooltip:NumLines() do
        local line = _G["AmIEnchantedScanTooltipTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text then
                -- Check for empty sockets
                if text:find("Empty Prismatic Socket") or text:find("Empty Socket") then
                    totalSockets = totalSockets + 1
                end
            end
        end
    end
    
    -- Total sockets = empty sockets found + filled sockets from link
    totalSockets = totalSockets + filledSockets
    
    local missingGems = totalSockets - filledSockets
    if missingGems < 0 then missingGems = 0 end
    
    return true, totalSockets, filledSockets, missingGems
end

-- Create an icon frame for a slot
local function CreateEnchantIcon(slotFrame, slotID)
    local icon = CreateFrame("Frame", "AmIEnchantedIcon" .. slotID, slotFrame)
    icon:SetSize(14, 14)
    icon:SetFrameStrata("HIGH")
    icon:EnableMouse(false) -- Don't block mouse events from reaching slot
    
    -- Position icon in the bottom-right corner of the slot
    -- Side indicators are outside the slot, so no offset needed
    icon:SetPoint("BOTTOMRIGHT", slotFrame, "BOTTOMRIGHT", -1, 1)
    
    -- Create the texture for the rank icon
    icon.texture = icon:CreateTexture(nil, "OVERLAY")
    icon.texture:SetAllPoints(icon)
    
    -- Create a background for better visibility
    icon.bg = icon:CreateTexture(nil, "BACKGROUND")
    icon.bg:SetAllPoints(icon)
    icon.bg:SetColorTexture(0, 0, 0, 0.5)
    
    icon:Hide()
    return icon
end

-- Parse enchant rank from enchant ID or item tooltip
local function GetEnchantRank(itemLink)
    if not itemLink then return nil end
    
    -- Extract enchant ID from item link
    -- Item link format: |cff...|Hitem:itemID:enchantID:...|h[Name]|h|r
    local enchantID = itemLink:match("item:%d+:(%d+)")
    enchantID = tonumber(enchantID)
    
    if not enchantID or enchantID == 0 then
        return nil -- No enchant
    end
    
    -- For modern WoW enchants (Dragonflight+), we need to check the tooltip
    -- to determine the rank since enchant IDs don't directly indicate rank
    local rank = GetEnchantRankFromTooltip(itemLink)
    
    return rank
end

-- Scan tooltip to find enchant rank
function GetEnchantRankFromTooltip(itemLink)
    if not itemLink then return nil end
    
    -- Create a scanning tooltip if we don't have one
    if not addon.scanTooltip then
        addon.scanTooltip = CreateFrame("GameTooltip", "AmIEnchantedScanTooltip", nil, "GameTooltipTemplate")
        addon.scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    
    local tooltip = addon.scanTooltip
    tooltip:ClearLines()
    tooltip:SetHyperlink(itemLink)
    
    -- Scan tooltip lines for enchant info
    for i = 1, tooltip:NumLines() do
        local line = _G["AmIEnchantedScanTooltipTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text then
                -- Look for enchant lines - they often contain "|A:Professions-ChatIcon-Quality-Tier"
                -- or have rank indicators like "Rank 1", "Rank 2", "Rank 3" or quality tier icons
                
                -- Check for atlas quality icons in the text (Dragonflight+ style)
                if text:find("Professions%-ChatIcon%-Quality%-Tier3") or text:find("Tier3") then
                    return 3
                elseif text:find("Professions%-ChatIcon%-Quality%-Tier2") or text:find("Tier2") then
                    return 2
                elseif text:find("Professions%-ChatIcon%-Quality%-Tier1") or text:find("Tier1") then
                    return 1
                end
                
                -- Check for "|||" quality indicators (3 pips = rank 3, etc.)
                -- Some enchants show quality as repeated symbols
                local pips = text:match("|A:Professions%-ChatIcon%-Quality%-Tier(%d)")
                if pips then
                    return tonumber(pips)
                end
            end
        end
    end
    
    -- If we found an enchant but couldn't determine rank, check if there's any enchant text
    -- Look for "Enchanted:" or common enchant prefixes
    for i = 1, tooltip:NumLines() do
        local line = _G["AmIEnchantedScanTooltipTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text then
                -- Green text often indicates enchants
                local r, g, b = line:GetTextColor()
                if g > 0.9 and r < 0.2 and b < 0.2 then
                    -- This is green text, likely an enchant
                    -- If we can't determine rank, assume rank 1 as fallback for having an enchant
                    -- But first check if it's actually an enchant and not just a socket bonus
                    if not text:find("Socket") and not text:find("socket") then
                        -- Check for quality tier in the line more carefully
                        if text:find("|A:") then
                            -- Has atlas icon, try to extract tier
                            local tier = text:match("Tier(%d)")
                            if tier then
                                return tonumber(tier)
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Alternative: Check using C_TooltipInfo API (more reliable in modern WoW)
    local tooltipData = C_TooltipInfo.GetHyperlink(itemLink)
    if tooltipData and tooltipData.lines then
        for _, lineData in ipairs(tooltipData.lines) do
            if lineData.leftText then
                local text = lineData.leftText
                
                -- Check for quality tier indicators
                if text:find("Tier3") or text:find("Quality%-Tier3") then
                    return 3
                elseif text:find("Tier2") or text:find("Quality%-Tier2") then
                    return 2
                elseif text:find("Tier1") or text:find("Quality%-Tier1") then
                    return 1
                end
            end
        end
    end
    
    -- Check if item has any enchant via the enchant ID in the link
    local enchantID = itemLink:match("item:%d+:(%d+)")
    if enchantID and tonumber(enchantID) > 0 then
        -- Has an enchant but we couldn't determine rank
        -- Default to showing rank 1 icon to indicate "enchanted but unknown rank"
        return 1
    end
    
    return nil -- No enchant found
end

-- Check if an item can be enchanted based on its type
-- Returns false for shields, off-hand held items, and other non-enchantable items
local function IsItemEnchantable(itemLink, slotID)
    if not itemLink then return false end
    
    -- Get item class and subclass info
    local _, _, _, itemEquipLoc, _, itemClassID, itemSubClassID = C_Item.GetItemInfoInstant(itemLink)
    
    if not itemClassID then return false end
    
    -- Item class constants:
    -- Enum.ItemClass.Weapon = 2
    -- Enum.ItemClass.Armor = 4
    
    -- For weapons (class 2), they can generally be enchanted
    if itemClassID == Enum.ItemClass.Weapon then
        return true
    end
    
    -- For armor (class 4), check the subclass and slot
    if itemClassID == Enum.ItemClass.Armor then
        -- Armor subclass constants:
        -- 0 = Miscellaneous (includes off-hand items like books, orbs)
        -- 6 = Shields
        
        -- Shields (subclass 6) cannot be enchanted with weapon enchants
        if itemSubClassID == 6 then -- Shield
            return false
        end
        
        -- Off-hand held items (Miscellaneous armor in off-hand slot) cannot be enchanted
        -- itemEquipLoc "INVTYPE_HOLDABLE" is for held in off-hand items
        if itemEquipLoc == "INVTYPE_HOLDABLE" then
            return false
        end
        
        -- For slot 17 (off-hand), if it's armor that's not a weapon, it's likely not enchantable
        if slotID == 17 and itemSubClassID == 0 then
            return false
        end
        
        -- Other armor slots (chest, wrist, back, legs, feet) can be enchanted
        return true
    end
    
    -- Default to not enchantable for other item types
    return false
end

-- Check if a slot has an enchantable item and get its enchant status
local function CheckSlotEnchant(slotID)
    local itemLink = GetInventoryItemLink("player", slotID)
    
    if not itemLink then
        return false, nil, false -- No item in slot (hasItem, enchantRank, isEnchantable)
    end
    
    -- Check if this item type can be enchanted
    local canBeEnchanted = IsItemEnchantable(itemLink, slotID)
    
    if not canBeEnchanted then
        return true, nil, false -- Has item, but it's not enchantable
    end
    
    local rank = GetEnchantRank(itemLink)
    return true, rank, true -- Has item, enchant rank (or nil), and it's enchantable
end

-- Update all enchant icons
local function UpdateEnchantIcons()
    if not CharacterFrame:IsShown() then
        return
    end
    
    for _, slotInfo in ipairs(ENCHANTABLE_SLOTS) do
        local slotID = slotInfo.slotID
        local frameName = slotInfo.frameName
        local slotFrame = _G[frameName]
        
        if slotFrame then
            -- Create icon if it doesn't exist
            if not enchantIcons[slotID] then
                enchantIcons[slotID] = CreateEnchantIcon(slotFrame, slotID)
            end
            
            local icon = enchantIcons[slotID]
            local hasItem, enchantRank, isEnchantable = CheckSlotEnchant(slotID)
            
            -- Create red border if it doesn't exist
            if not unenchantedBorders[slotID] then
                unenchantedBorders[slotID] = CreateUnenchantedBorder(slotFrame, slotID)
            end
            local border = unenchantedBorders[slotID]
            
            -- Create text label if it doesn't exist
            if not enchantTextLabels[slotID] then
                enchantTextLabels[slotID] = CreateEnchantTextLabel(slotFrame, slotID)
            end
            local textLabel = enchantTextLabels[slotID]
            
            -- Create side indicator if it doesn't exist
            if not enchantSideIndicators[slotID] then
                enchantSideIndicators[slotID] = CreateEnchantSideIndicator(slotFrame, slotID)
            end
            local sideIndicator = enchantSideIndicators[slotID]
            
            -- Get item link for enchant name
            local itemLink = GetInventoryItemLink("player", slotID)
            
            if hasItem and isEnchantable and enchantRank then
                -- Show the appropriate rank icon if option enabled
                if options.showQualityIcons then
                    local atlasName = RANK_ICONS[enchantRank]
                    if atlasName then
                        icon.texture:SetAtlas(atlasName)
                        icon:Show()
                    else
                        icon:Hide()
                    end
                else
                    icon:Hide()
                end
                -- Hide red border since item is enchanted
                border:Hide()
                
                -- Show green side indicator for enchanted items if option enabled
                if options.showSideIndicators then
                    UpdateSideIndicatorPosition(sideIndicator, slotFrame, slotID)
                    sideIndicator.texture:SetColorTexture(0, 1, 0, 0.8) -- Green
                    sideIndicator:Show()
                else
                    sideIndicator:Hide()
                end
                
                -- Show enchant name only if option is on
                if options.showEnchantText then
                    local enchantName = GetEnchantName(itemLink)
                    if enchantName then
                        UpdateTextLabelPosition(textLabel, slotFrame, slotID)
                        textLabel:SetText(enchantName)
                        textLabel:SetTextColor(0, 1, 0, 1) -- Green text
                        textLabel:Show()
                    else
                        textLabel:Hide()
                    end
                else
                    textLabel:Hide()
                end
            elseif hasItem and isEnchantable then
                -- Item exists and CAN be enchanted but has no enchant - show red side indicator
                icon:Hide()
                border:Hide()
                
                -- Show red side indicator for missing enchants if option enabled
                if options.showSideIndicators then
                    UpdateSideIndicatorPosition(sideIndicator, slotFrame, slotID)
                    sideIndicator.texture:SetColorTexture(1, 0, 0, 0.8) -- Red
                    sideIndicator:Show()
                else
                    sideIndicator:Hide()
                end
                
                -- Show "Missing Enchant" text only if option is on
                if options.showMissingEnchantText then
                    UpdateTextLabelPosition(textLabel, slotFrame, slotID)
                    textLabel:SetText("Missing Enchant")
                    textLabel:SetTextColor(1, 0, 0, 1) -- Red text
                    textLabel:Show()
                else
                    textLabel:Hide()
                end
            else
                -- No item in slot OR item is not enchantable (shields, off-hands, etc.)
                icon:Hide()
                border:Hide()
                sideIndicator:Hide()
                textLabel:Hide()
            end
        end
    end
    
    -- Update socket indicators for socketable slots
    for _, slotInfo in ipairs(SOCKETABLE_SLOTS) do
        local slotID = slotInfo.slotID
        local frameName = slotInfo.frameName
        local maxSockets = slotInfo.maxSockets
        local slotFrame = _G[frameName]
        
        if slotFrame then
            -- Create socket indicators if they don't exist
            if not socketIndicators[slotID] then
                socketIndicators[slotID] = CreateSocketIndicators(slotFrame, slotID, maxSockets)
            end
            
            local indicators = socketIndicators[slotID]
            local hasItem, totalSockets, filledSockets, missingGems = CheckSocketStatus(slotID)
            
            -- Update positions based on current options
            UpdateSocketIndicatorPositions(indicators, slotFrame, slotID)
            
            -- Hide all indicators first
            for _, indicator in ipairs(indicators) do
                indicator:Hide()
            end
            
            -- Only show socket indicators if option is enabled
            if options.showSocketIndicators then
                if hasItem and totalSockets > 0 then
                    -- Show indicators for each socket that exists
                    for i = 1, totalSockets do
                        if indicators[i] then
                            if i <= filledSockets then
                                -- Socket is filled - green border
                                indicators[i]:SetBackdropColor(0.1, 0.3, 0.1, 0.9)
                                indicators[i]:SetBackdropBorderColor(0, 1, 0, 1)
                            else
                                -- Socket is empty - black with red border
                                indicators[i]:SetBackdropColor(0, 0, 0, 0.9)
                                indicators[i]:SetBackdropBorderColor(1, 0, 0, 1)
                            end
                            indicators[i]:Show()
                        end
                    end
                    -- Show red indicators for missing sockets (sockets that could be added)
                    for i = totalSockets + 1, maxSockets do
                        if indicators[i] then
                            indicators[i]:SetBackdropColor(0, 0, 0, 0.9)
                            indicators[i]:SetBackdropBorderColor(1, 0, 0, 1)
                            indicators[i]:Show()
                        end
                    end
                elseif hasItem then
                    -- Item has no sockets at all - show all as missing (red)
                    for i = 1, maxSockets do
                        if indicators[i] then
                            indicators[i]:SetBackdropColor(0, 0, 0, 0.9)
                            indicators[i]:SetBackdropBorderColor(1, 0, 0, 1)
                            indicators[i]:Show()
                        end
                    end
                end
            end
        end
    end
end

-- Hide all enchant UI elements (now only hides text, keeps side indicators visible)
local function HideAllEnchantText()
    for slotID, label in pairs(enchantTextLabels) do
        label:Hide()
    end
end

-- Hide everything (used when character frame is closed)
local function HideAllEnchantUI()
    for slotID, icon in pairs(enchantIcons) do
        icon:Hide()
    end
    for slotID, border in pairs(unenchantedBorders) do
        border:Hide()
    end
    for slotID, label in pairs(enchantTextLabels) do
        label:Hide()
    end
    for slotID, indicator in pairs(enchantSideIndicators) do
        indicator:Hide()
    end
    for slotID, indicators in pairs(socketIndicators) do
        for _, indicator in ipairs(indicators) do
            indicator:Hide()
        end
    end
end

-- ============================================================================
-- INSPECT FRAME FUNCTIONS
-- ============================================================================

-- Get item link for inspected unit
local function GetInspectItemLink(slotID)
    local unit = InspectFrame and InspectFrame.unit or "target"
    return GetInventoryItemLink(unit, slotID)
end

-- Check socket status for an inspected unit's item
local function CheckInspectSocketStatus(slotID)
    local itemLink = GetInspectItemLink(slotID)
    
    if not itemLink then
        return false, 0, 0, 0
    end
    
    local totalSockets = 0
    local filledSockets = 0
    
    -- Parse the item link for gem IDs
    local linkParts = {strsplit(":", itemLink)}
    for i = 5, 8 do
        local gemID = tonumber(linkParts[i])
        if gemID and gemID > 0 then
            filledSockets = filledSockets + 1
        end
    end
    
    -- Use GetItemGem to check each socket slot
    for socketIndex = 1, 4 do
        local gemName, gemLink = C_Item.GetItemGem(itemLink, socketIndex)
        if gemName or gemLink then
            totalSockets = math.max(totalSockets, socketIndex)
        end
    end
    
    -- Use tooltip scanning to find socket info
    if not addon.scanTooltip then
        addon.scanTooltip = CreateFrame("GameTooltip", "AmIEnchantedScanTooltip", nil, "GameTooltipTemplate")
        addon.scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    
    local tooltip = addon.scanTooltip
    tooltip:ClearLines()
    tooltip:SetHyperlink(itemLink)
    
    for i = 1, tooltip:NumLines() do
        local line = _G["AmIEnchantedScanTooltipTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text then
                if text:find("Empty Prismatic Socket") or text:find("Empty Socket") then
                    totalSockets = totalSockets + 1
                end
            end
        end
    end
    
    totalSockets = totalSockets + filledSockets
    
    local missingGems = totalSockets - filledSockets
    if missingGems < 0 then missingGems = 0 end
    
    return true, totalSockets, filledSockets, missingGems
end

-- Check if a slot has an enchantable item and get its enchant status (for inspect)
local function CheckInspectSlotEnchant(slotID)
    local itemLink = GetInspectItemLink(slotID)
    
    if not itemLink then
        return false, nil, false
    end
    
    local canBeEnchanted = IsItemEnchantable(itemLink, slotID)
    
    if not canBeEnchanted then
        return true, nil, false
    end
    
    local rank = GetEnchantRank(itemLink)
    return true, rank, true
end

-- Create side indicator for inspect frame (parent to InspectFrame to avoid blocking slot events)
local function CreateInspectSideIndicator(slotFrame, slotID)
    local indicator = CreateFrame("Frame", "PurplePoliceInspectSideIndicator" .. slotID, InspectFrame)
    indicator:SetFrameStrata("HIGH")
    indicator:SetSize(4, slotFrame:GetHeight() - 4)
    
    indicator.texture = indicator:CreateTexture(nil, "OVERLAY")
    indicator.texture:SetAllPoints(indicator)
    indicator.texture:SetColorTexture(0, 1, 0, 0.8)
    
    indicator.slotID = slotID
    indicator.slotFrame = slotFrame -- Store reference for positioning
    indicator:Hide()
    
    -- Ensure mouse events pass through
    indicator:EnableMouse(false)
    indicator:SetHitRectInsets(1000, 1000, 1000, 1000)
    
    return indicator
end

-- Update side indicator position for inspect frame
local function UpdateInspectSideIndicatorPosition(indicator, slotFrame, slotID)
    indicator:ClearAllPoints()
    
    local isLeftSideSlot = (slotID == 9 or slotID == 5 or slotID == 15)
    local isBottomSlot = (slotID == 16 or slotID == 17)
    local isRightSideSlot = (slotID == 7 or slotID == 8 or slotID == 11 or slotID == 12)
    
    local positionInside = (options.inspectSideIndicatorPosition == "inside")
    
    if isLeftSideSlot then
        if positionInside then
            indicator:SetPoint("LEFT", slotFrame, "RIGHT", 2, 0)
        else
            indicator:SetPoint("RIGHT", slotFrame, "LEFT", -2, 0)
        end
    elseif isRightSideSlot then
        if positionInside then
            indicator:SetPoint("RIGHT", slotFrame, "LEFT", -2, 0)
        else
            indicator:SetPoint("LEFT", slotFrame, "RIGHT", 2, 0)
        end
    elseif isBottomSlot then
        if slotID == 16 then
            if positionInside then
                indicator:SetPoint("LEFT", slotFrame, "RIGHT", 2, 0)
            else
                indicator:SetPoint("RIGHT", slotFrame, "LEFT", -2, 0)
            end
        else
            if positionInside then
                indicator:SetPoint("RIGHT", slotFrame, "LEFT", -2, 0)
            else
                indicator:SetPoint("LEFT", slotFrame, "RIGHT", 2, 0)
            end
        end
    else
        indicator:SetPoint("RIGHT", slotFrame, "RIGHT", -2, 0)
    end
end

-- Create text label for inspect frame
local function CreateInspectTextLabel(slotFrame, slotID)
    local label = slotFrame:CreateFontString("PurplePoliceInspectText" .. slotID, "OVERLAY", "GameFontNormal")
    label:SetTextColor(0, 1, 0, 1)
    label:SetShadowOffset(2, -2)
    label:SetShadowColor(0, 0, 0, 1)
    label.slotID = slotID
    label:SetWidth(120)
    label:Hide()
    return label
end

-- Update text label position for inspect frame
local function UpdateInspectTextLabelPosition(label, slotFrame, slotID)
    label:ClearAllPoints()
    
    local positionInside = (options.inspectTextPosition == "inside")
    
    if slotID == 16 then
        if positionInside then
            label:SetPoint("BOTTOMRIGHT", slotFrame, "BOTTOMLEFT", -4, 0)
            label:SetJustifyH("RIGHT")
        else
            label:SetPoint("BOTTOMLEFT", slotFrame, "BOTTOMRIGHT", 4, 0)
            label:SetJustifyH("LEFT")
        end
    elseif slotID == 17 then
        if positionInside then
            label:SetPoint("BOTTOMLEFT", slotFrame, "BOTTOMRIGHT", 4, 0)
            label:SetJustifyH("LEFT")
        else
            label:SetPoint("BOTTOMRIGHT", slotFrame, "BOTTOMLEFT", -4, 0)
            label:SetJustifyH("RIGHT")
        end
    elseif slotID == 9 or slotID == 5 or slotID == 15 then
        if positionInside then
            label:SetPoint("LEFT", slotFrame, "RIGHT", 4, 0)
            label:SetJustifyH("LEFT")
        else
            label:SetPoint("RIGHT", slotFrame, "LEFT", -4, 0)
            label:SetJustifyH("RIGHT")
        end
    elseif slotID == 11 or slotID == 12 then
        if positionInside then
            label:SetPoint("RIGHT", slotFrame, "LEFT", -4, 0)
            label:SetJustifyH("RIGHT")
        else
            label:SetPoint("LEFT", slotFrame, "RIGHT", 4, 0)
            label:SetJustifyH("LEFT")
        end
    else
        if positionInside then
            label:SetPoint("RIGHT", slotFrame, "LEFT", -4, 0)
            label:SetJustifyH("RIGHT")
        else
            label:SetPoint("LEFT", slotFrame, "RIGHT", 4, 0)
            label:SetJustifyH("LEFT")
        end
    end
end

-- Create socket indicators for inspect frame (parent to InspectFrame to avoid blocking slot events)
local function CreateInspectSocketIndicators(slotFrame, slotID, maxSockets)
    local indicators = {}
    for i = 1, maxSockets do
        local indicator = CreateFrame("Frame", nil, InspectFrame, "BackdropTemplate")
        indicator:SetSize(12, 12)
        indicator:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        indicator:SetBackdropColor(0, 0, 0, 0.9)
        indicator:SetBackdropBorderColor(1, 0, 0, 1)
        indicator:SetFrameStrata("HIGH")
        indicator.slotID = slotID
        indicator.slotFrame = slotFrame -- Store reference for positioning
        indicator.index = i
        indicator:Hide()
        
        -- Ensure mouse events pass through
        indicator:EnableMouse(false)
        indicator:SetHitRectInsets(1000, 1000, 1000, 1000)
        
        indicators[i] = indicator
    end
    return indicators
end

-- Update socket indicator positions for inspect frame
local function UpdateInspectSocketIndicatorPositions(indicators, slotFrame, slotID)
    if not indicators or #indicators == 0 then return end
    
    local isRightSideSlot = (slotID == 11 or slotID == 12 or slotID == 6)
    
    for i, indicator in ipairs(indicators) do
        indicator:ClearAllPoints()
        if isRightSideSlot then
            if i == 1 then
                indicator:SetPoint("TOPRIGHT", slotFrame, "TOPRIGHT", -2, -2)
            else
                indicator:SetPoint("RIGHT", indicators[i-1], "LEFT", -2, 0)
            end
        else
            if i == 1 then
                indicator:SetPoint("TOPLEFT", slotFrame, "TOPLEFT", 2, -2)
            else
                indicator:SetPoint("LEFT", indicators[i-1], "RIGHT", 2, 0)
            end
        end
    end
end

-- Create enchant icon for inspect frame (parent to InspectFrame to avoid blocking slot events)
local function CreateInspectEnchantIcon(slotFrame, slotID)
    local icon = CreateFrame("Frame", "PurplePoliceInspectIcon" .. slotID, InspectFrame)
    icon:SetSize(14, 14)
    icon:SetFrameStrata("HIGH")
    icon:SetPoint("BOTTOMRIGHT", slotFrame, "BOTTOMRIGHT", -1, 1)
    
    icon.texture = icon:CreateTexture(nil, "OVERLAY")
    icon.texture:SetAllPoints(icon)
    
    icon.bg = icon:CreateTexture(nil, "BACKGROUND")
    icon.bg:SetAllPoints(icon)
    icon.bg:SetColorTexture(0, 0, 0, 0.5)
    
    icon.slotFrame = slotFrame -- Store reference
    icon:Hide()
    
    -- Ensure mouse events pass through
    icon:EnableMouse(false)
    icon:SetHitRectInsets(1000, 1000, 1000, 1000)
    
    return icon
end

-- Create border for inspect frame (parent to InspectFrame to avoid blocking slot events)
local function CreateInspectBorder(slotFrame, slotID)
    local border = CreateFrame("Frame", "PurplePoliceInspectBorder" .. slotID, InspectFrame, "BackdropTemplate")
    border:SetSize(slotFrame:GetWidth() + 4, slotFrame:GetHeight() + 4)
    border:SetPoint("CENTER", slotFrame, "CENTER", 0, 0)
    border:SetFrameStrata("HIGH")
    
    border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    border:SetBackdropBorderColor(1, 0, 0, 0.9)
    
    border.glow = border:CreateTexture(nil, "BACKGROUND")
    border.glow:SetPoint("TOPLEFT", border, "TOPLEFT", -2, 2)
    border.glow:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 2, -2)
    border.glow:SetColorTexture(1, 0, 0, 0.15)
    
    border.slotFrame = slotFrame -- Store reference
    border:Hide()
    
    -- Ensure mouse events pass through
    border:EnableMouse(false)
    border:SetHitRectInsets(1000, 1000, 1000, 1000)
    
    return border
end

-- Update all enchant icons for inspect frame
local function UpdateInspectEnchantIcons()
    if not InspectFrame or not InspectFrame:IsShown() then
        return
    end
    
    for _, slotInfo in ipairs(INSPECT_ENCHANTABLE_SLOTS) do
        local slotID = slotInfo.slotID
        local frameName = slotInfo.frameName
        local slotFrame = _G[frameName]
        
        if slotFrame then
            -- Create icon if it doesn't exist
            if not inspectEnchantIcons[slotID] then
                inspectEnchantIcons[slotID] = CreateInspectEnchantIcon(slotFrame, slotID)
            end
            
            local icon = inspectEnchantIcons[slotID]
            local hasItem, enchantRank, isEnchantable = CheckInspectSlotEnchant(slotID)
            
            -- Create border if it doesn't exist
            if not inspectUnenchantedBorders[slotID] then
                inspectUnenchantedBorders[slotID] = CreateInspectBorder(slotFrame, slotID)
            end
            local border = inspectUnenchantedBorders[slotID]
            
            -- Create text label if it doesn't exist
            if not inspectEnchantTextLabels[slotID] then
                inspectEnchantTextLabels[slotID] = CreateInspectTextLabel(slotFrame, slotID)
            end
            local textLabel = inspectEnchantTextLabels[slotID]
            
            -- Create side indicator if it doesn't exist
            if not inspectEnchantSideIndicators[slotID] then
                inspectEnchantSideIndicators[slotID] = CreateInspectSideIndicator(slotFrame, slotID)
            end
            local sideIndicator = inspectEnchantSideIndicators[slotID]
            
            -- Get item link for enchant name
            local itemLink = GetInspectItemLink(slotID)
            
            if hasItem and isEnchantable and enchantRank then
                -- Show the appropriate rank icon if option enabled
                if options.inspectShowQualityIcons then
                    local atlasName = RANK_ICONS[enchantRank]
                    if atlasName then
                        icon.texture:SetAtlas(atlasName)
                        icon:Show()
                    else
                        icon:Hide()
                    end
                else
                    icon:Hide()
                end
                border:Hide()
                
                -- Show green side indicator for enchanted items if option enabled
                if options.inspectShowSideIndicators then
                    UpdateInspectSideIndicatorPosition(sideIndicator, slotFrame, slotID)
                    sideIndicator.texture:SetColorTexture(0, 1, 0, 0.8)
                    sideIndicator:Show()
                else
                    sideIndicator:Hide()
                end
                
                -- Show enchant name if option is on
                if options.inspectShowEnchantText then
                    local enchantName = GetEnchantName(itemLink)
                    if enchantName then
                        UpdateInspectTextLabelPosition(textLabel, slotFrame, slotID)
                        textLabel:SetText(enchantName)
                        textLabel:SetTextColor(0, 1, 0, 1)
                        textLabel:Show()
                    else
                        textLabel:Hide()
                    end
                else
                    textLabel:Hide()
                end
            elseif hasItem and isEnchantable then
                -- Item exists and CAN be enchanted but has no enchant
                icon:Hide()
                border:Hide()
                
                -- Show red side indicator for missing enchants if option enabled
                if options.inspectShowSideIndicators then
                    UpdateInspectSideIndicatorPosition(sideIndicator, slotFrame, slotID)
                    sideIndicator.texture:SetColorTexture(1, 0, 0, 0.8)
                    sideIndicator:Show()
                else
                    sideIndicator:Hide()
                end
                
                -- Show "Missing Enchant" text only if option is on
                if options.inspectShowMissingEnchantText then
                    UpdateInspectTextLabelPosition(textLabel, slotFrame, slotID)
                    textLabel:SetText("Missing Enchant")
                    textLabel:SetTextColor(1, 0, 0, 1)
                    textLabel:Show()
                else
                    textLabel:Hide()
                end
            else
                -- No item in slot OR item is not enchantable
                icon:Hide()
                border:Hide()
                sideIndicator:Hide()
                textLabel:Hide()
            end
        end
    end
    
    -- Update socket indicators for inspect socketable slots
    for _, slotInfo in ipairs(INSPECT_SOCKETABLE_SLOTS) do
        local slotID = slotInfo.slotID
        local frameName = slotInfo.frameName
        local maxSockets = slotInfo.maxSockets
        local slotFrame = _G[frameName]
        
        if slotFrame then
            -- Create socket indicators if they don't exist
            if not inspectSocketIndicators[slotID] then
                inspectSocketIndicators[slotID] = CreateInspectSocketIndicators(slotFrame, slotID, maxSockets)
            end
            
            local indicators = inspectSocketIndicators[slotID]
            local hasItem, totalSockets, filledSockets, missingGems = CheckInspectSocketStatus(slotID)
            
            -- Update positions
            UpdateInspectSocketIndicatorPositions(indicators, slotFrame, slotID)
            
            -- Hide all indicators first
            for _, indicator in ipairs(indicators) do
                indicator:Hide()
            end
            
            -- Only show socket indicators if option is enabled
            if options.inspectShowSocketIndicators then
                if hasItem and totalSockets > 0 then
                    for i = 1, totalSockets do
                        if indicators[i] then
                            if i <= filledSockets then
                                indicators[i]:SetBackdropColor(0.1, 0.3, 0.1, 0.9)
                                indicators[i]:SetBackdropBorderColor(0, 1, 0, 1)
                            else
                                indicators[i]:SetBackdropColor(0, 0, 0, 0.9)
                                indicators[i]:SetBackdropBorderColor(1, 0, 0, 1)
                            end
                            indicators[i]:Show()
                        end
                    end
                    for i = totalSockets + 1, maxSockets do
                        if indicators[i] then
                            indicators[i]:SetBackdropColor(0, 0, 0, 0.9)
                            indicators[i]:SetBackdropBorderColor(1, 0, 0, 1)
                            indicators[i]:Show()
                        end
                    end
                elseif hasItem then
                    for i = 1, maxSockets do
                        if indicators[i] then
                            indicators[i]:SetBackdropColor(0, 0, 0, 0.9)
                            indicators[i]:SetBackdropBorderColor(1, 0, 0, 1)
                            indicators[i]:Show()
                        end
                    end
                end
            end
        end
    end
end

-- Hide all inspect UI elements
local function HideAllInspectUI()
    for slotID, icon in pairs(inspectEnchantIcons) do
        icon:Hide()
    end
    for slotID, border in pairs(inspectUnenchantedBorders) do
        border:Hide()
    end
    for slotID, label in pairs(inspectEnchantTextLabels) do
        label:Hide()
    end
    for slotID, indicator in pairs(inspectEnchantSideIndicators) do
        indicator:Hide()
    end
    for slotID, indicators in pairs(inspectSocketIndicators) do
        for _, indicator in ipairs(indicators) do
            indicator:Hide()
        end
    end
end

-- ============================================================================
-- END INSPECT FRAME FUNCTIONS
-- ============================================================================

-- Toggle enchant text display (side indicators controlled by options)
local function ToggleEnchantText()
    options.showEnchantText = not options.showEnchantText
    if PurplePoliceDB then
        PurplePoliceDB.showEnchantText = options.showEnchantText
    end
    UpdateEnchantIcons()
end

-- Expose update functions to addon table for Options.lua
addon.UpdateEnchantIcons = UpdateEnchantIcons
addon.UpdateInspectEnchantIcons = UpdateInspectEnchantIcons

-- Create the toggle icon button in the title bar
local function CreateToggleButton()
    if toggleButton then return end
    
    toggleButton = CreateFrame("Button", "PurplePoliceToggleButton", CharacterFrame, "UIPanelButtonTemplate")
    toggleButton:SetSize(28, 20)
    
    -- Position in the title bar, to the right of the Class/Spec icon
    toggleButton:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 60, -3)
    toggleButton:SetFrameStrata("HIGH")
    
    -- Remove the default text
    toggleButton:SetText("")
    
    -- Create the quality tier icon (similar to rank 3 enchant icon)
    toggleButton.icon = toggleButton:CreateTexture(nil, "ARTWORK")
    toggleButton.icon:SetSize(14, 14)
    toggleButton.icon:SetPoint("CENTER", toggleButton, "CENTER", 0, 0)
    toggleButton.icon:SetAtlas("Professions-Icon-Quality-Tier3-Small") -- Gold quality pip
    
    -- Tooltip
    toggleButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Purple Police")
        GameTooltip:AddLine("Click to toggle options", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    
    toggleButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Handle clicks - toggle popup options panel (tab 1 = Character)
    toggleButton:SetScript("OnClick", function(self, button)
        addon.TogglePopupOptions(CharacterFrame, 1)
    end)
end

-- Create the toggle button for the inspect frame
local function CreateInspectToggleButton()
    if inspectToggleButton then return end
    if not InspectFrame then return end
    
    inspectToggleButton = CreateFrame("Button", "PurplePoliceInspectToggleButton", InspectFrame, "UIPanelButtonTemplate")
    inspectToggleButton:SetSize(28, 20)
    
    -- Position in the title bar area
    inspectToggleButton:SetPoint("TOPLEFT", InspectFrame, "TOPLEFT", 60, -3)
    inspectToggleButton:SetFrameStrata("HIGH")
    
    -- Remove the default text
    inspectToggleButton:SetText("")
    
    -- Create the quality tier icon
    inspectToggleButton.icon = inspectToggleButton:CreateTexture(nil, "ARTWORK")
    inspectToggleButton.icon:SetSize(14, 14)
    inspectToggleButton.icon:SetPoint("CENTER", inspectToggleButton, "CENTER", 0, 0)
    inspectToggleButton.icon:SetAtlas("Professions-Icon-Quality-Tier3-Small")
    
    -- Tooltip
    inspectToggleButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Purple Police")
        GameTooltip:AddLine("Click to toggle options", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    
    inspectToggleButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Handle clicks - toggle popup options panel (tab 2 = Inspect)
    inspectToggleButton:SetScript("OnClick", function(self, button)
        addon.TogglePopupOptions(InspectFrame, 2)
    end)
end

-- ============================================================================
-- ITEM LEVEL TOOLTIP FEATURE
-- ============================================================================

-- Cache for item level lookups
local itemLevelCache = {}
local inspectRequestTime = {}
local inspectRequestUnit = {} -- Track which unit was inspected by GUID

-- Slot names for display
local SLOT_NAMES = {
    [1] = "Head",
    [2] = "Neck",
    [3] = "Shoulder",
    [5] = "Chest",
    [6] = "Waist",
    [7] = "Legs",
    [8] = "Feet",
    [9] = "Wrist",
    [10] = "Hands",
    [11] = "Ring 1",
    [12] = "Ring 2",
    [13] = "Trinket 1",
    [14] = "Trinket 2",
    [15] = "Back",
    [16] = "Main Hand",
    [17] = "Off Hand",
}

-- Enchantable slot IDs for tooltip display
local TOOLTIP_ENCHANTABLE_SLOTS = {
    [5] = true,   -- Chest
    [7] = true,   -- Legs
    [8] = true,   -- Feet
    [9] = true,   -- Wrist
    [11] = true,  -- Ring 1
    [12] = true,  -- Ring 2
    [15] = true,  -- Back
    [16] = true,  -- Main Hand
    [17] = true,  -- Off Hand
}

-- Socketable slot IDs and their max sockets for tooltip
local TOOLTIP_SOCKETABLE_SLOTS = {
    [1] = 1,   -- Head
    [2] = 2,   -- Neck
    [6] = 1,   -- Waist
    [9] = 1,   -- Wrist
    [11] = 2,  -- Ring 1
    [12] = 2,  -- Ring 2
}

-- Check socket status for a unit's item (for tooltip)
local function CheckTooltipSocketStatus(unit, slotID)
    local itemLink = GetInventoryItemLink(unit, slotID)
    
    if not itemLink then
        return false, 0, 0, 0
    end
    
    local totalSockets = 0
    local filledSockets = 0
    
    -- Parse the item link for gem IDs
    local linkParts = {strsplit(":", itemLink)}
    for i = 5, 8 do
        local gemID = tonumber(linkParts[i])
        if gemID and gemID > 0 then
            filledSockets = filledSockets + 1
        end
    end
    
    -- Use GetItemGem to check each socket slot
    for socketIndex = 1, 4 do
        local gemName, gemLink = C_Item.GetItemGem(itemLink, socketIndex)
        if gemName or gemLink then
            totalSockets = math.max(totalSockets, socketIndex)
        end
    end
    
    -- Use tooltip scanning to find socket info
    if not addon.scanTooltip then
        addon.scanTooltip = CreateFrame("GameTooltip", "AmIEnchantedScanTooltip", nil, "GameTooltipTemplate")
        addon.scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    
    local tooltip = addon.scanTooltip
    tooltip:ClearLines()
    tooltip:SetHyperlink(itemLink)
    
    for i = 1, tooltip:NumLines() do
        local line = _G["AmIEnchantedScanTooltipTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text then
                if text:find("Empty Prismatic Socket") or text:find("Empty Socket") then
                    totalSockets = totalSockets + 1
                end
            end
        end
    end
    
    totalSockets = totalSockets + filledSockets
    
    local missingGems = totalSockets - filledSockets
    if missingGems < 0 then missingGems = 0 end
    
    return true, totalSockets, filledSockets, missingGems
end

-- Check enchant status for a unit's item (for tooltip)
local function CheckTooltipEnchantStatus(unit, slotID)
    local itemLink = GetInventoryItemLink(unit, slotID)
    
    if not itemLink then
        return false, nil, false
    end
    
    -- Check if this item type can be enchanted
    local canBeEnchanted = IsItemEnchantable(itemLink, slotID)
    
    if not canBeEnchanted then
        return true, nil, false
    end
    
    local rank = GetEnchantRank(itemLink)
    return true, rank, true
end

-- Build detailed gear info for tooltip
-- expectedGUID: if provided, verify the unit's GUID matches before reading gear
local function BuildGearInfoForTooltip(unit, expectedGUID)
    local info = {
        itemLevel = 0,
        itemCount = 0,
        totalItemLevel = 0,
        missingEnchants = {},
        missingSockets = {},
        lowRankEnchants = {},
    }
    
    -- Validate unit exists
    if not unit or not UnitExists(unit) then
        return info
    end
    
    -- Get unit level for sanity checking
    local unitLevel = UnitLevel(unit)
    if not unitLevel or unitLevel <= 0 then
        unitLevel = 80 -- Assume max level if unknown
    end
    
    -- Verify GUID matches if expected GUID is provided
    -- This prevents reading gear from wrong player if unit token points elsewhere
    if expectedGUID then
        local actualGUID = UnitGUID(unit)
        if actualGUID ~= expectedGUID then
            return info -- GUID mismatch - don't read potentially wrong data
        end
        
        -- Also verify we're not reading our own gear by accident
        local playerGUID = UnitGUID("player")
        if actualGUID == playerGUID then
            return info -- We're accidentally reading player's own gear
        end
    end
    
    -- Calculate max expected ilvl based on unit level
    -- This helps detect when we're reading wrong data
    -- Current max ilvl (TWW post-squish): Mythic 8/8 = 170
    local maxExpectedILvl
    if unitLevel >= 80 then
        maxExpectedILvl = 180  -- Allow some buffer above 170 max
    elseif unitLevel >= 70 then
        maxExpectedILvl = 150  -- Dragonflight leveling gear
    elseif unitLevel >= 60 then
        maxExpectedILvl = 100  -- Shadowlands leveling gear
    else
        maxExpectedILvl = unitLevel * 2  -- Rough estimate for lower levels
    end
    
    -- All equipment slots (excluding shirt=4 and tabard=19)
    -- WoW always calculates average ilvl using 16 slots
    local equipSlots = {1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17}
    local TOTAL_GEAR_SLOTS = 16
    
    local mainHandILvl = nil
    local hasOffHand = false
    
    for _, slotID in ipairs(equipSlots) do
        local itemLink = GetInventoryItemLink(unit, slotID)
        if itemLink then
            local effectiveILvl = GetDetailedItemLevelInfo(itemLink)
            if effectiveILvl and effectiveILvl > 0 then
                -- Cap item level at max expected (handles borrowed power items like cloaks with inflated ilvl)
                local cappedILvl = math.min(effectiveILvl, maxExpectedILvl)
                
                info.totalItemLevel = info.totalItemLevel + cappedILvl
                info.itemCount = info.itemCount + 1
                
                -- Track main hand ilvl for 2H weapon handling (use capped value)
                if slotID == 16 then
                    mainHandILvl = cappedILvl
                elseif slotID == 17 then
                    hasOffHand = true
                end
            end
            
            -- Check enchant status for enchantable slots
            if TOOLTIP_ENCHANTABLE_SLOTS[slotID] then
                local hasItem, enchantRank, isEnchantable = CheckTooltipEnchantStatus(unit, slotID)
                if hasItem and isEnchantable then
                    if not enchantRank then
                        table.insert(info.missingEnchants, SLOT_NAMES[slotID] or ("Slot " .. slotID))
                    elseif enchantRank < 3 then
                        table.insert(info.lowRankEnchants, {
                            slot = SLOT_NAMES[slotID] or ("Slot " .. slotID),
                            rank = enchantRank
                        })
                    end
                end
            end
            
            -- Check socket status for socketable slots
            local maxSockets = TOOLTIP_SOCKETABLE_SLOTS[slotID]
            if maxSockets then
                local hasItem, totalSockets, filledSockets, missingGems = CheckTooltipSocketStatus(unit, slotID)
                if hasItem then
                    -- Check for missing sockets (either empty or not added yet)
                    local actualMissing = maxSockets - filledSockets
                    if actualMissing > 0 then
                        table.insert(info.missingSockets, {
                            slot = SLOT_NAMES[slotID] or ("Slot " .. slotID),
                            missing = actualMissing,
                            max = maxSockets
                        })
                    end
                end
            end
        end
    end
    
    -- Handle 2H weapons: if main hand exists but no off-hand, count main hand twice
    -- This matches how WoW calculates average ilvl
    if mainHandILvl and not hasOffHand then
        info.totalItemLevel = info.totalItemLevel + mainHandILvl
        info.itemCount = info.itemCount + 1
    end
    
    -- Always divide by 16 slots (WoW's standard calculation)
    -- Only calculate if we have a reasonable amount of gear data
    if info.itemCount >= 10 then
        info.itemLevel = math.floor(info.totalItemLevel / TOTAL_GEAR_SLOTS)
    elseif info.itemCount > 0 then
        -- Partial data - still calculate but may be inaccurate
        info.itemLevel = math.floor(info.totalItemLevel / TOTAL_GEAR_SLOTS)
    end
    
    return info
end

-- Hook into GameTooltip to show item level and gear status
local function SetupItemLevelTooltip()
    -- Hook into unit tooltips
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
        if tooltip ~= GameTooltip then return end
        if not options.showItemLevelTooltip then return end
        
        -- Disable tooltip additions when inspect frame is open to avoid conflicts
        if InspectFrame and InspectFrame:IsShown() then return end
        
        local _, unit = tooltip:GetUnit()
        if not unit then return end
        
        -- Only show for players (use pcall to handle tainted values during combat)
        local isPlayerSuccess, isPlayer = pcall(UnitIsPlayer, unit)
        if not isPlayerSuccess or not isPlayer then return end
        
        -- Check if we can inspect this unit (use pcall for combat safety)
        local canInspectSuccess, canInspect = pcall(CanInspect, unit)
        if not canInspectSuccess or not canInspect then return end
        
        local guid = UnitGUID(unit)
        if not guid then return end
        
        -- Check cache first (reduced to 15 seconds to avoid stale data)
        if itemLevelCache[guid] and (GetTime() - (itemLevelCache[guid].time or 0) < 15) then
            local cachedInfo = itemLevelCache[guid]
            if cachedInfo.itemLevel and cachedInfo.itemLevel > 0 then
                -- Add separator
                tooltip:AddLine(" ")
                tooltip:AddLine("|cff9932ccPurple Police|r")
                
                -- Item Level
                tooltip:AddLine(string.format("|cffffd700Item Level:|r %d", cachedInfo.itemLevel))
                
                -- Missing Enchants
                if cachedInfo.missingEnchants and #cachedInfo.missingEnchants > 0 then
                    tooltip:AddLine("|cffff0000Missing Enchants:|r")
                    for _, slotName in ipairs(cachedInfo.missingEnchants) do
                        tooltip:AddLine(string.format("  |cffff6666- %s|r", slotName))
                    end
                end
                
                -- Low Rank Enchants
                if cachedInfo.lowRankEnchants and #cachedInfo.lowRankEnchants > 0 then
                    tooltip:AddLine("|cffffa500Low Rank Enchants:|r")
                    for _, info in ipairs(cachedInfo.lowRankEnchants) do
                        tooltip:AddLine(string.format("  |cffffcc66- %s (Rank %d)|r", info.slot, info.rank))
                    end
                end
                
                -- Missing Sockets
                if cachedInfo.missingSockets and #cachedInfo.missingSockets > 0 then
                    tooltip:AddLine("|cffff0000Missing Gems:|r")
                    for _, info in ipairs(cachedInfo.missingSockets) do
                        tooltip:AddLine(string.format("  |cffff6666- %s (%d/%d)|r", info.slot, info.max - info.missing, info.max))
                    end
                end
                
                -- All good message
                if (not cachedInfo.missingEnchants or #cachedInfo.missingEnchants == 0) and
                   (not cachedInfo.lowRankEnchants or #cachedInfo.lowRankEnchants == 0) and
                   (not cachedInfo.missingSockets or #cachedInfo.missingSockets == 0) then
                    tooltip:AddLine("|cff00ff00All enchants and gems look good!|r")
                end
                
                tooltip:Show()
            end
            return
        end
        
        -- Request inspect if we haven't recently
        local lastRequest = inspectRequestTime[guid] or 0
        if GetTime() - lastRequest > 2 then
            inspectRequestTime[guid] = GetTime()
            inspectRequestUnit[guid] = unit -- Store the unit we're inspecting
            
            -- Invalidate old cache entry to avoid showing stale data
            itemLevelCache[guid] = nil
            
            -- Clear any stale inspect data before requesting new inspection
            ClearInspectPlayer()
            NotifyInspect(unit)
            
            -- Show loading message
            tooltip:AddLine(" ")
            tooltip:AddLine("|cff9932ccPurple Police|r")
            tooltip:AddLine("|cff888888Inspecting...|r")
            tooltip:Show()
        end
    end)
end

-- Refresh the tooltip if it's showing a player we just inspected
local function RefreshTooltipForUnit(guid)
    if not GameTooltip:IsShown() then return end
    
    local _, unit = GameTooltip:GetUnit()
    if not unit then return end
    
    -- Use pcall to handle tainted values during combat
    local isPlayerSuccess, isPlayer = pcall(UnitIsPlayer, unit)
    if not isPlayerSuccess or not isPlayer then return end
    
    local tooltipGuid = UnitGUID(unit)
    if tooltipGuid == guid then
        -- Force tooltip to refresh by hiding and re-showing for the same unit
        GameTooltip:SetUnit(unit)
    end
end

-- Find a unit token that matches the given GUID
local function FindUnitByGUID(guid)
    -- Check common unit tokens
    local unitsToCheck = {"target", "mouseover", "focus", "party1", "party2", "party3", "party4", "raid1"}
    
    -- Also check the stored unit from the inspect request
    local storedUnit = inspectRequestUnit[guid]
    if storedUnit then
        local storedGUID = UnitGUID(storedUnit)
        if storedGUID == guid then
            return storedUnit
        end
    end
    
    for _, unitToken in ipairs(unitsToCheck) do
        if UnitGUID(unitToken) == guid then
            return unitToken
        end
    end
    
    -- Check more raid members if in a raid
    for i = 1, 40 do
        local raidUnit = "raid" .. i
        if UnitGUID(raidUnit) == guid then
            return raidUnit
        end
    end
    
    return nil
end

-- Handle INSPECT_READY to cache gear info
local function OnInspectReadyForTooltip(guid)
    if not guid then return end
    
    -- Find the actual unit that was inspected
    local unit = FindUnitByGUID(guid)
    if not unit then
        -- Clean up stored unit reference
        inspectRequestUnit[guid] = nil
        return
    end
    
    -- Verify GUID still matches before reading (unit token might have changed)
    local currentGUID = UnitGUID(unit)
    if currentGUID ~= guid then
        inspectRequestUnit[guid] = nil
        return
    end
    
    -- Build detailed gear info using the correct unit, pass GUID for verification
    local gearInfo = BuildGearInfoForTooltip(unit, guid)
    
    -- Only cache if we got valid data (itemCount > 0 means we actually read gear)
    -- Also sanity check: ilvl should be below 180 (max possible post-squish is ~170)
    -- If ilvl is higher, we likely read wrong data
    if gearInfo.itemCount > 0 and gearInfo.itemLevel > 0 and gearInfo.itemLevel < 180 then
        itemLevelCache[guid] = {
            itemLevel = gearInfo.itemLevel,
            missingEnchants = gearInfo.missingEnchants,
            lowRankEnchants = gearInfo.lowRankEnchants,
            missingSockets = gearInfo.missingSockets,
            time = GetTime()
        }
        
        -- Clean up stored unit reference
        inspectRequestUnit[guid] = nil
        
        -- Refresh tooltip if it's showing this player
        RefreshTooltipForUnit(guid)
    else
        -- Clean up if we didn't get valid data
        inspectRequestUnit[guid] = nil
    end
end

-- Create the main frame for event handling
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
frame:RegisterEvent("INSPECT_READY")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        -- Initialize SavedVariables
        if PurplePoliceDB == nil then
            PurplePoliceDB = {}
        end
        
        -- Load saved settings with defaults
        for key, defaultValue in pairs(defaults) do
            if PurplePoliceDB[key] == nil then
                PurplePoliceDB[key] = defaultValue
            end
            options[key] = PurplePoliceDB[key]
        end
        
        -- Create the toggle button
        CreateToggleButton()
        
        -- Initialize the options panel (from Options.lua)
        addon.InitializeOptions()
        
        -- Setup item level tooltip feature
        SetupItemLevelTooltip()
        
        -- Hook into the character frame
        if CharacterFrame then
            CharacterFrame:HookScript("OnShow", function()
                UpdateEnchantIcons() -- Always update (side indicators always show)
            end)
            CharacterFrame:HookScript("OnHide", function()
                -- Close the options popup when character frame closes
                local popupOptionsFrame = addon.GetPopupOptionsFrame()
                if popupOptionsFrame and popupOptionsFrame:IsShown() then
                    popupOptionsFrame:Hide()
                end
            end)
        end
        
        -- Also hook the PaperDollFrame if it exists
        if PaperDollFrame then
            PaperDollFrame:HookScript("OnShow", function()
                UpdateEnchantIcons() -- Always update (side indicators always show)
            end)
        end
        
        -- Hook into the inspect frame when it's loaded
        local function HookInspectFrame()
            if InspectFrame then
                -- Create the toggle button for inspect frame
                CreateInspectToggleButton()
                
                InspectFrame:HookScript("OnShow", function()
                    C_Timer.After(0.2, function()
                        UpdateInspectEnchantIcons()
                    end)
                end)
                InspectFrame:HookScript("OnHide", function()
                    HideAllInspectUI()
                    -- Close the options popup when inspect frame closes
                    local popupOptionsFrame = addon.GetPopupOptionsFrame()
                    if popupOptionsFrame and popupOptionsFrame:IsShown() then
                        popupOptionsFrame:Hide()
                    end
                end)
            end
        end
        
        -- Try to hook now if InspectFrame exists
        if InspectFrame then
            HookInspectFrame()
        else
            -- Hook when the Blizzard_InspectUI addon loads
            local inspectLoader = CreateFrame("Frame")
            inspectLoader:RegisterEvent("ADDON_LOADED")
            inspectLoader:SetScript("OnEvent", function(self, event, addonName)
                if addonName == "Blizzard_InspectUI" then
                    HookInspectFrame()
                    self:UnregisterEvent("ADDON_LOADED")
                end
            end)
        end
        
        print("|cff9932ccPurple Police|r loaded! Open your character screen to see enchant status. Click the button for options.")
        print("|cff9932ccPurple Police|r Use /pp hide to disable overlays for testing tooltips, /pp show to re-enable")
        
        -- Add slash command for toggling overlays
        SLASH_PURPLEPOLICE1 = "/pp"
        SLASH_PURPLEPOLICE2 = "/purplepolice"
        SlashCmdList["PURPLEPOLICE"] = function(msg)
            local cmd = msg:lower():trim()
            if cmd == "hide" then
                -- Hide all inspect overlays to test if they're blocking tooltips
                HideAllInspectUI()
                print("|cff9932ccPurple Police|r Inspect overlays hidden. Tooltips should work now if overlays were the issue.")
            elseif cmd == "show" then
                -- Re-show overlays
                if InspectFrame and InspectFrame:IsShown() then
                    UpdateInspectEnchantIcons()
                end
                print("|cff9932ccPurple Police|r Inspect overlays re-enabled.")
            else
                print("|cff9932ccPurple Police|r Commands: /pp hide, /pp show")
            end
        end
        
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "UNIT_INVENTORY_CHANGED" then
        -- Delay slightly to ensure item data is available
        -- Always update since side indicators are always shown
        C_Timer.After(0.1, UpdateEnchantIcons)
    elseif event == "INSPECT_READY" then
        -- Update inspect frame when inspection data is ready
        C_Timer.After(0.1, function()
            UpdateInspectEnchantIcons()
        end)
        -- Also update item level cache for tooltip
        local guid = ...
        OnInspectReadyForTooltip(guid)
    end
end)
