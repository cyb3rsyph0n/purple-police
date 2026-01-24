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

-- Default options
local defaults = {
    showEnchantText = false,           -- Show enchant name text (hidden by default)
    showSideIndicators = true,         -- Show green/red side indicators
    showQualityIcons = true,           -- Show quality tier icons
    showSocketIndicators = true,       -- Show socket indicators
    showMissingEnchantText = false,    -- Show "Missing Enchant" text when missing (hidden by default)
    sideIndicatorPosition = "outside", -- "inside" or "outside" of character frame
    textPosition = "inside",           -- "inside" or "outside" of character frame
}

-- Current options (will be loaded from SavedVariables)
local options = {}

-- Create a side indicator (colored bar on one side of the slot)
local function CreateEnchantSideIndicator(slotFrame, slotID)
    local indicator = CreateFrame("Frame", "AmIEnchantedSideIndicator" .. slotID, slotFrame)
    indicator:SetFrameStrata("HIGH")
    indicator:SetSize(4, slotFrame:GetHeight() - 4)
    
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
                
                -- Show "Missing Enchant" text only if options are on
                if options.showEnchantText and options.showMissingEnchantText then
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

-- Toggle enchant text display (side indicators controlled by options)
local function ToggleEnchantText()
    options.showEnchantText = not options.showEnchantText
    if PurplePoliceDB then
        PurplePoliceDB.showEnchantText = options.showEnchantText
    end
    UpdateEnchantIcons()
end

-- Options category reference (declared here so CreateToggleButton can access it)
local optionsCategory = nil

-- Popup options panel reference
local popupOptionsFrame = nil

-- Create the quick popup options panel
local function CreatePopupOptionsPanel()
    if popupOptionsFrame then return popupOptionsFrame end
    
    local popup = CreateFrame("Frame", "PurplePolicePopupOptions", UIParent, "BackdropTemplate")
    popup:SetSize(280, 340)
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
    
    local yOffset = -35
    
    -- Helper function to create a checkbox
    local function CreatePopupCheckbox(label, optionKey)
        local cb = CreateFrame("CheckButton", nil, popup, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 16, yOffset)
        cb:SetSize(26, 26)
        
        local cbLabel = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cbLabel:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        cbLabel:SetText(label)
        
        cb:SetChecked(options[optionKey])
        cb.optionKey = optionKey
        
        cb:SetScript("OnClick", function(self)
            options[optionKey] = self:GetChecked()
            if PurplePoliceDB then
                PurplePoliceDB[optionKey] = options[optionKey]
            end
            if CharacterFrame and CharacterFrame:IsShown() then
                UpdateEnchantIcons()
            end
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end)
        
        yOffset = yOffset - 26
        return cb
    end
    
    -- Helper function to create a dropdown
    local function CreatePopupDropdown(label, optionKey, dropdownOptions)
        local labelText = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        labelText:SetPoint("TOPLEFT", 16, yOffset)
        labelText:SetText(label)
        
        yOffset = yOffset - 18
        
        local dropdown = CreateFrame("Frame", "PurplePolicePopupDropdown_" .. optionKey, popup, "UIDropDownMenuTemplate")
        dropdown:SetPoint("TOPLEFT", -4, yOffset)
        dropdown.optionKey = optionKey
        dropdown.dropdownOptions = dropdownOptions
        
        local function GetDisplayText()
            for _, opt in ipairs(dropdownOptions) do
                if opt.value == options[optionKey] then
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
                info.checked = (options[optionKey] == opt.value)
                info.func = function()
                    options[optionKey] = opt.value
                    if PurplePoliceDB then
                        PurplePoliceDB[optionKey] = opt.value
                    end
                    UIDropDownMenu_SetText(dropdown, opt.text)
                    CloseDropDownMenus()
                    if CharacterFrame and CharacterFrame:IsShown() then
                        UpdateEnchantIcons()
                    end
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        
        yOffset = yOffset - 32
        return dropdown
    end
    
    -- Display Options Header
    local displayHeader = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    displayHeader:SetPoint("TOPLEFT", 16, yOffset)
    displayHeader:SetText("|cffffd700Display Options|r")
    yOffset = yOffset - 22
    
    -- Store checkbox references for refresh
    popup.checkboxes = {}
    popup.dropdowns = {}
    
    -- Checkboxes
    popup.checkboxes.showEnchantText = CreatePopupCheckbox("Show Enchant Text", "showEnchantText")
    popup.checkboxes.showSideIndicators = CreatePopupCheckbox("Show Side Indicators", "showSideIndicators")
    popup.checkboxes.showQualityIcons = CreatePopupCheckbox("Show Quality Icons", "showQualityIcons")
    popup.checkboxes.showSocketIndicators = CreatePopupCheckbox("Show Socket Indicators", "showSocketIndicators")
    popup.checkboxes.showMissingEnchantText = CreatePopupCheckbox("Show 'Missing Enchant' Text", "showMissingEnchantText")
    
    yOffset = yOffset - 10
    
    -- Position Options Header
    local positionHeader = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    positionHeader:SetPoint("TOPLEFT", 16, yOffset)
    positionHeader:SetText("|cffffd700Position Options|r")
    yOffset = yOffset - 22
    
    local positionOptions = {
        { text = "Inside Character", value = "inside" },
        { text = "Outside Character", value = "outside" },
    }
    
    popup.dropdowns.sideIndicatorPosition = CreatePopupDropdown("Side Indicator Position:", "sideIndicatorPosition", positionOptions)
    popup.dropdowns.textPosition = CreatePopupDropdown("Text Position:", "textPosition", positionOptions)
    
    -- Refresh function to update UI from current options
    popup.Refresh = function(self)
        for key, cb in pairs(self.checkboxes) do
            cb:SetChecked(options[key])
        end
        for key, dd in pairs(self.dropdowns) do
            for _, opt in ipairs(dd.dropdownOptions) do
                if opt.value == options[key] then
                    UIDropDownMenu_SetText(dd, opt.text)
                    break
                end
            end
        end
    end
    
    popup:Hide()
    popupOptionsFrame = popup
    return popup
end

-- Toggle the popup options panel
local function TogglePopupOptions()
    if not popupOptionsFrame then
        CreatePopupOptionsPanel()
    end
    
    if popupOptionsFrame:IsShown() then
        popupOptionsFrame:Hide()
    else
        -- Position to the right of the character frame
        popupOptionsFrame:ClearAllPoints()
        popupOptionsFrame:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", 5, 0)
        popupOptionsFrame:Refresh()
        popupOptionsFrame:Show()
    end
end

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
    
    -- Handle clicks - toggle popup options panel
    toggleButton:SetScript("OnClick", function(self, button)
        TogglePopupOptions()
    end)
end

-- Create the options panel
local function CreateOptionsPanel()
    -- Create the main options frame
    local optionsFrame = CreateFrame("Frame", "PurplePoliceOptionsPanel", UIParent)
    optionsFrame:SetSize(400, 500)
    
    -- Title
    local title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Purple Police Options")
    
    -- Description
    local desc = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Configure what enchant information is displayed on your character panel.")
    
    local yOffset = -70
    
    -- Helper function to create a checkbox
    local function CreateCheckbox(parent, label, tooltipText, optionKey)
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 16, yOffset)
        cb:SetSize(26, 26)
        
        local cbLabel = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cbLabel:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        cbLabel:SetText(label)
        
        cb:SetChecked(options[optionKey])
        
        cb:SetScript("OnClick", function(self)
            options[optionKey] = self:GetChecked()
            if PurplePoliceDB then
                PurplePoliceDB[optionKey] = options[optionKey]
            end
            if CharacterFrame and CharacterFrame:IsShown() then
                UpdateEnchantIcons()
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
        
        yOffset = yOffset - 30
        return cb
    end
    
    -- Helper function to create a dropdown
    local function CreateDropdown(parent, label, tooltipText, optionKey, dropdownOptions)
        local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        labelText:SetPoint("TOPLEFT", 16, yOffset)
        labelText:SetText(label)
        
        yOffset = yOffset - 20
        
        local dropdown = CreateFrame("Frame", "PurplePoliceDropdown_" .. optionKey, parent, "UIDropDownMenuTemplate")
        dropdown:SetPoint("TOPLEFT", 0, yOffset)
        
        local function GetDisplayText()
            for _, opt in ipairs(dropdownOptions) do
                if opt.value == options[optionKey] then
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
                info.checked = (options[optionKey] == opt.value)
                info.func = function()
                    options[optionKey] = opt.value
                    if PurplePoliceDB then
                        PurplePoliceDB[optionKey] = opt.value
                    end
                    UIDropDownMenu_SetText(dropdown, opt.text)
                    CloseDropDownMenus()
                    if CharacterFrame and CharacterFrame:IsShown() then
                        UpdateEnchantIcons()
                    end
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        
        yOffset = yOffset - 40
        return dropdown
    end
    
    -- Display Options Header
    local displayHeader = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    displayHeader:SetPoint("TOPLEFT", 16, yOffset)
    displayHeader:SetText("|cffffd700Display Options|r")
    yOffset = yOffset - 25
    
    -- Checkboxes for what to display
    CreateCheckbox(optionsFrame, "Show Enchant Text", 
        "Display the enchant name next to equipment slots", "showEnchantText")
    
    CreateCheckbox(optionsFrame, "Show Side Indicators",
        "Display green/red bars on equipment slots to indicate enchant status", "showSideIndicators")
    
    CreateCheckbox(optionsFrame, "Show Quality Icons",
        "Display the crafting quality tier icons (bronze/silver/gold) on enchanted items", "showQualityIcons")
    
    CreateCheckbox(optionsFrame, "Show Socket Indicators",
        "Display socket status indicators on socketable equipment", "showSocketIndicators")
    
    CreateCheckbox(optionsFrame, "Show 'Missing Enchant' Text",
        "Display 'Missing Enchant' text on items that need enchants (requires Show Enchant Text)", "showMissingEnchantText")
    
    yOffset = yOffset - 15
    
    -- Position Options Header
    local positionHeader = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    positionHeader:SetPoint("TOPLEFT", 16, yOffset)
    positionHeader:SetText("|cffffd700Position Options|r")
    yOffset = yOffset - 25
    
    local positionOptions = {
        { text = "Inside Character", value = "inside" },
        { text = "Outside Character", value = "outside" },
    }
    
    -- Side Indicator Position dropdown
    CreateDropdown(optionsFrame, "Side Indicator Position:", 
        "Where to display the green/red side indicators", "sideIndicatorPosition", positionOptions)
    
    -- Text Position dropdown
    CreateDropdown(optionsFrame, "Text Position:",
        "Where to display the enchant name text", "textPosition", positionOptions)
    
    -- Register with the new Settings API
    optionsCategory = Settings.RegisterCanvasLayoutCategory(optionsFrame, "Purple Police")
    Settings.RegisterAddOnCategory(optionsCategory)
    
    return optionsFrame
end

-- Create the main frame for event handling
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("UNIT_INVENTORY_CHANGED")

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
        
        -- Create the options panel
        CreateOptionsPanel()
        
        -- Hook into the character frame
        if CharacterFrame then
            CharacterFrame:HookScript("OnShow", function()
                UpdateEnchantIcons() -- Always update (side indicators always show)
            end)
        end
        
        -- Also hook the PaperDollFrame if it exists
        if PaperDollFrame then
            PaperDollFrame:HookScript("OnShow", function()
                UpdateEnchantIcons() -- Always update (side indicators always show)
            end)
        end
        
        print("|cff9932ccPurple Police|r loaded! Open your character screen to see enchant status. Right-click the button for options.")
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "UNIT_INVENTORY_CHANGED" then
        -- Delay slightly to ensure item data is available
        -- Always update since side indicators are always shown
        C_Timer.After(0.1, UpdateEnchantIcons)
    end
end)
