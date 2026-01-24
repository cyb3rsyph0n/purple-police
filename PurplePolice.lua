-- AmIEnchanted: Shows enchant rank icons on enchantable gear
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
local showEnchantText = false -- Default to hidden (will be loaded from SavedVariables)

-- Create a side indicator (colored bar on one side of the slot)
local function CreateEnchantSideIndicator(slotFrame, slotID)
    local indicator = CreateFrame("Frame", "AmIEnchantedSideIndicator" .. slotID, slotFrame)
    indicator:SetFrameStrata("HIGH")
    
    -- Determine which side to show the indicator based on slot position
    -- Left side slots show indicator on the right, right side slots show on the left
    local isLeftSideSlot = (slotID == 9 or slotID == 5 or slotID == 15) -- Wrist, Chest, Cloak
    local isBottomSlot = (slotID == 16 or slotID == 17) -- Weapons
    local isRightSideSlot = (slotID == 7 or slotID == 8 or slotID == 11 or slotID == 12) -- Legs, Feet, Rings
    
    indicator:SetSize(4, slotFrame:GetHeight() - 4)
    
    if isLeftSideSlot then
        indicator:SetPoint("LEFT", slotFrame, "LEFT", 2, 0)
    elseif isRightSideSlot then
        indicator:SetPoint("RIGHT", slotFrame, "RIGHT", -2, 0)
    elseif isBottomSlot then
        -- For weapons, main hand on left, off hand on right
        if slotID == 16 then -- Main hand
            indicator:SetPoint("LEFT", slotFrame, "LEFT", 2, 0)
        else -- Off hand
            indicator:SetPoint("RIGHT", slotFrame, "RIGHT", -2, 0)
        end
    else
        indicator:SetPoint("RIGHT", slotFrame, "RIGHT", -2, 0)
    end
    
    -- Create the colored texture
    indicator.texture = indicator:CreateTexture(nil, "OVERLAY")
    indicator.texture:SetAllPoints(indicator)
    indicator.texture:SetColorTexture(0, 1, 0, 0.8) -- Default green
    
    indicator:Hide()
    return indicator
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
    
    -- Position based on slot type (labels inside the character screen)
    if slotID == 16 then
        -- Main hand weapon - bottom, text to the left, aligned right
        label:SetPoint("BOTTOMRIGHT", slotFrame, "BOTTOMLEFT", -4, 0)
        label:SetJustifyH("RIGHT")
    elseif slotID == 17 then
        -- Off hand - bottom, text to the right, aligned left
        label:SetPoint("BOTTOMLEFT", slotFrame, "BOTTOMRIGHT", 4, 0)
        label:SetJustifyH("LEFT")
    elseif slotID == 9 or slotID == 5 or slotID == 15 then
        -- Wrist, Chest, Cloak (left side slots) - text to the right (inside), centered vertically
        label:SetPoint("LEFT", slotFrame, "RIGHT", 4, 0)
        label:SetJustifyH("LEFT")
    elseif slotID == 11 or slotID == 12 then
        -- Rings (right side slots) - text to the left (inside), centered vertically
        label:SetPoint("RIGHT", slotFrame, "LEFT", -4, 0)
        label:SetJustifyH("RIGHT")
    else
        -- Legs, Feet (bottom slots) - text to the left (inside), centered vertically
        label:SetPoint("RIGHT", slotFrame, "LEFT", -4, 0)
        label:SetJustifyH("RIGHT")
    end
    
    label:SetWidth(120) -- Max width to prevent overflow
    label:Hide()
    return label
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
        
        -- Check if this is a left-side slot with a side indicator (bracers)
        local isLeftSideSlot = (slotID == 9) -- Wrist/Bracers
        local xOffset = isLeftSideSlot and 8 or 2 -- Move right for left-side slots
        
        -- Position indicators at the top of the slot, side by side
        if i == 1 then
            indicator:SetPoint("TOPLEFT", slotFrame, "TOPLEFT", xOffset, -2)
        else
            indicator:SetPoint("LEFT", indicators[i-1], "RIGHT", 2, 0)
        end
        
        indicators[i] = indicator
    end
    return indicators
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
    
    -- Position icon accounting for side indicators on right-side slots
    local isRightSideSlot = (slotID == 7 or slotID == 8 or slotID == 11 or slotID == 12) -- Legs, Feet, Rings
    local isOffHand = (slotID == 17)
    
    if isRightSideSlot or isOffHand then
        -- Move icon left to avoid overlap with right-side indicator
        icon:SetPoint("BOTTOMRIGHT", slotFrame, "BOTTOMRIGHT", -7, 1)
    else
        icon:SetPoint("BOTTOMRIGHT", slotFrame, "BOTTOMRIGHT", -1, 1)
    end
    
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
                -- Show the appropriate rank icon
                local atlasName = RANK_ICONS[enchantRank]
                if atlasName then
                    icon.texture:SetAtlas(atlasName)
                    icon:Show()
                else
                    icon:Hide()
                end
                -- Hide red border since item is enchanted
                border:Hide()
                
                -- Always show green side indicator for enchanted items
                sideIndicator.texture:SetColorTexture(0, 1, 0, 0.8) -- Green
                sideIndicator:Show()
                
                -- Show enchant name only if toggle is on
                if showEnchantText then
                    local enchantName = GetEnchantName(itemLink)
                    if enchantName then
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
                
                -- Always show red side indicator for missing enchants
                sideIndicator.texture:SetColorTexture(1, 0, 0, 0.8) -- Red
                sideIndicator:Show()
                
                -- Show "Missing Enchant" text only if toggle is on
                if showEnchantText then
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
            
            -- Hide all indicators first
            for _, indicator in ipairs(indicators) do
                indicator:Hide()
            end
            
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

-- Toggle enchant text display (side indicators always stay visible)
local function ToggleEnchantText()
    showEnchantText = not showEnchantText
    if showEnchantText then
        toggleButton:SetChecked(true)
        UpdateEnchantIcons() -- This will show the text labels
    else
        toggleButton:SetChecked(false)
        HideAllEnchantText() -- Only hide the text, keep side indicators
    end
end

-- Create the toggle icon button in the title bar
local function CreateToggleButton()
    if toggleButton then return end
    
    toggleButton = CreateFrame("Button", "AmIEnchantedToggleButton", CharacterFrame, "UIPanelButtonTemplate")
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
        if showEnchantText then
            GameTooltip:AddLine("Click to hide enchant details", 0.8, 0.8, 0.8)
        else
            GameTooltip:AddLine("Click to show enchant details", 0.8, 0.8, 0.8)
        end
        GameTooltip:AddLine("Green/Red indicators always visible", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    
    toggleButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Handle clicks
    toggleButton:SetScript("OnClick", function(self)
        showEnchantText = not showEnchantText
        -- Save to SavedVariables
        if PurplePoliceDB then
            PurplePoliceDB.showEnchantText = showEnchantText
        end
        if showEnchantText then
            UpdateEnchantIcons()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        else
            HideAllEnchantText()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        end
    end)
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
        -- Load saved setting, default to false (hidden) if not set
        if PurplePoliceDB.showEnchantText == nil then
            PurplePoliceDB.showEnchantText = false
        end
        showEnchantText = PurplePoliceDB.showEnchantText
        
        -- Create the toggle button
        CreateToggleButton()
        
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
        
        print("|cff00ff00Am I Enchanted?|r loaded! Open your character screen to see enchant ranks.")
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "UNIT_INVENTORY_CHANGED" then
        -- Delay slightly to ensure item data is available
        -- Always update since side indicators are always shown
        C_Timer.After(0.1, UpdateEnchantIcons)
    end
end)

-- Slash command for manual refresh
SLASH_AMIENCHANTED1 = "/amienchanted"
SLASH_AMIENCHANTED2 = "/aie"
SlashCmdList["AMIENCHANTED"] = function(msg)
    if msg == "refresh" then
        UpdateEnchantIcons()
        print("|cff00ff00Am I Enchanted?|r Icons refreshed!")
    else
        print("|cff00ff00Am I Enchanted?|r Commands:")
        print("  /aie refresh - Refresh enchant icons")
    end
end
