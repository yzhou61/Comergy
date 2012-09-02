ComergyBarTextures = {
    { "Patt", "Interface\\AddOns\\Comergy\\textures\\Patt" },
    { "Flat", "Interface\\AddOns\\Comergy\\textures\\Flat" },
    { "Smth", "Interface\\AddOns\\Comergy\\textures\\Smth" },
    { "Alum", "Interface\\AddOns\\Comergy\\textures\\Alum" },
    { "3D", "Interface\\AddOns\\Comergy\\textures\\3d" },
    { "Pat2", "Interface\\AddOns\\Comergy\\textures\\Pat2" },
    { "Amry", "Interface\\AddOns\\Comergy\\textures\\Amry" },
    { "Flat2", "Interface\\AddOns\\Comergy\\textures\\Flat2" },
    { "Mini", "Interface\\AddOns\\Comergy\\textures\\Mini" },
    { "Otra", "Interface\\AddOns\\Comergy\\textures\\Otra" },
    { "Blank", nil },
}

ComergyTextFonts = {
    { "Chat", "ChatFontNormal" },
    { "Combat", "NumberFontNormal" },
    { "System", "GameFontNormal" },
}

Comergy_Settings = { }

local PERIODIC_UPDATE_INTERVAL = 0.1

local FLASH_HIGH = 0.8
local FLASH_VALUES = { FLASH_HIGH }
local FLASH_DURATION = 0.3
local FLASH_TIMES = 2
local ONE_VALUES = { 1 }
local ZERO_VALUES = { 0 }

local BAR_SMALL_INC_DURATION = 0.1
local INSTANT_DURATION = 0.01

local DURATIONS = {
    COMBO_SHOW = { 0.1, 0.1 },
    COMBO_HIDE = { 0.2, 0.2 },
    MAINFRAME_SHOW = { 0.1, 0.1 },
    MAINFRAME_HIDE = { 0.2, 0.2 },
    BAR_CHANGE = { 0.1, 0.1 },
}

local ROGUE = 1
local DRUID = 2
local OTHER = 3

local ENERGY_SUBBAR_NUM = 5

local SPELL_ID_PROWL = 5215
local SPELL_NAME_PROWL

local SPELL_ID_SHADOW_DANCE = 51713
local SPELL_NAME_SHADOW_DANCE
local SPELL_ID_VENDETTA = 79140
local SPELL_NAME_VENDETTA
local SPELL_ID_ADRENALINE_RUSH = 13750
local SPELL_NAME_ADRENALINE_RUSH

local status = {
    initialized,
    enabled,
    comboEnabled,
    curPowerType,
    curComboHeight,

    playerGUID,

    playerClass,
    playerInCombat,
    playerInStealth,
    shapeshiftForm,

    maxEnergy,
    curEnergy,
    energyFlashing,
    energyBGFlashing,

    curCombo,
    comboFlashing,

    maxPlayerHealth,
    curPlayerHealth,

    maxTargetHealth,
    curTargetHealth,

    talent,
}

-- Local loop varient
local i, j, v, w

local comboBars = {}
local energyBars = {}
local numEnergyBars
local playerBar, targetBar

local orderedThresholds = {}
local lastPeriodicUpdate

local InitObject, GradientObject, UpdateObject, SetStatusBarValue, MainFrameShow, MainFrameToggle, ResizeEnergyBars, ResizeComboBars
local EnergyChanged, FrameResize, ComboChanged, Initialize, ReadStatus, PopulateDefaultSettings, PopulateSettingsFrom
local EventHandlers, ResetObject, TextChanged, TextStyleChanged, BGResize, OnPeriodicUpdate, OnFrameUpdate
local ToggleOptions, PlayerHealthChanged, TargetHealthChanged, PowerTypeChanged

function InitObject(object, initValues)
    object.curValue = {}
    object.endValue = {}
    object.deltaValue = {}
    for i = 1, #(initValues) do
        object.curValue[i] = initValues[i]
        object.endValue[i] = initValues[i]
        object.deltaValue[i] = 0
    end
end

function ResetObject(object, resetValues)
    for i = 1, #(resetValues) do
        if (resetValues[i] >= 0) then
            object.curValue[i] = resetValues[i]
            object.endValue[i] = resetValues[i]
            object.deltaValue[i] = 0
        end
    end
end

function GradientObject(object, idx, duration, endValue)
    if (object.endValue[idx] ~= endValue) then
        object.deltaValue[idx] = (endValue - object.curValue[idx]) / duration
        object.endValue[idx] = endValue
    end
end

function UpdateObject(object, elapsed)
    local changed = false
    for i = 1, #(object.deltaValue) do
        if (object.deltaValue[i] ~= 0) then
            local curValue = object.curValue[i] + object.deltaValue[i] * elapsed
            if ((curValue - object.endValue[i]) * object.deltaValue[i] >= 0) then
                object.curValue[i] = object.endValue[i]
                object.deltaValue[i] = 0
            else
                object.curValue[i] = curValue
            end
            changed = true
        end
    end
    return changed
end

function SetStatusBarValue(bar, value)
    if (value == 0) then
        bar:GetStatusBarTexture():Hide()
        return
    else
        bar:GetStatusBarTexture():Show()
    end

    value = value / (bar.max - bar.min)

    if (bar.direction < 3) then
        bar:GetStatusBarTexture():SetWidth(bar.len * value)
    else
        bar:GetStatusBarTexture():SetHeight(bar.len * value)
    end

    if (bar.direction == 1) then
        bar:GetStatusBarTexture():SetTexCoord(0, value, 0, 1)
    elseif (bar.direction == 2) then
        bar:GetStatusBarTexture():SetTexCoord(value, 0, 0, 1)
    elseif (bar.direction == 3) then
        bar:GetStatusBarTexture():SetTexCoord(value, 0, 0, 0, value, 1, 0, 1)
    elseif (bar.direction == 4) then
        bar:GetStatusBarTexture():SetTexCoord(0, 1, value, 1, 0, 0, value, 0)
    end
end

function MainFrameShow(show)
    if (show) then
        GradientObject(ComergyMainFrame, 1, DURATIONS["MAINFRAME_SHOW"][1], 1)
        ComergyMainFrame:Show()

        -- Hack to make sure that the energy is drawn to full
        EnergyChanged()
        PlayerHealthChanged()
        TargetHealthChanged()

    else
        GradientObject(ComergyMainFrame, 1, DURATIONS["MAINFRAME_HIDE"][1], 0)
    end
end

function MainFrameToggle()
    local show = false
    if (status.enabled) then
        if (((status.curCombo ~= 0) and (status.comboEnabled)) or (status.playerInCombat)) then
            show = true
        else
            if (not Comergy_Settings.ShowOnlyInCombat) then
                show = true
            else
                if (Comergy_Settings.ShowWhenEnergyNotFull) then
                    if ((status.curPlayerHealth < status.maxPlayerHealth) and (Comergy_Settings.ShowPlayerHealthBar)) then
                        show = true
                    elseif ((status.curEnergy < status.maxEnergy) and ((status.curPowerType == "ENERGY") or (status.curPowerType == "FOCUS"))) then
                        show = true
                    elseif ((status.curEnergy > 0) and ((status.curPowerType == "RAGE") or (status.curPowerType == "RUNIC_POWER"))) then
                        show = true
                    else
                        show = false
                    end
                end
                if ((Comergy_Settings.ShowInStealth) and (status.playerInStealth)) then
                    show = true
                end
            end
        end
    end
    MainFrameShow(show)
end

function ResizeEnergyBars()
    local n = 1
    energyBars[1].min = 0
    energyBars[1].minColor = Comergy_Settings.EnergyColor0

    for i = 1, #(orderedThresholds) do
        if ((orderedThresholds[i][1] > 0) and (Comergy_Settings["SplitEnergy"..orderedThresholds[i][2]])) then
            n = n + 1
            energyBars[n - 1].max = orderedThresholds[i][1]
            energyBars[n].min = orderedThresholds[i][1]
            energyBars[n - 1].maxColor = Comergy_Settings["EnergyColor"..orderedThresholds[i][2]]
            energyBars[n].minColor = Comergy_Settings["EnergyColor"..orderedThresholds[i][2]]
        end
    end

    energyBars[n].max = status.maxEnergy
    energyBars[n].maxColor = Comergy_Settings["EnergyColor"..ENERGY_SUBBAR_NUM]

    numEnergyBars = n

    local lenPerEnergy = (Comergy_Settings.Width - Comergy_Settings.Spacing * (n - 1)) / status.maxEnergy
    local anchorPointV = "TOP"
    local relAnchorPointV = "BOTTOM"
    local anchorPointH = "RIGHT"
    local relAnchorPointH = "LEFT"
    local direction

    if (Comergy_Settings.FlipBars) then
        if (Comergy_Settings.VerticalBars) then
            anchorPointH, relAnchorPointH = relAnchorPointH, anchorPointH
        else
            anchorPointV, relAnchorPointV = relAnchorPointV, anchorPointV
        end
    end
    if (Comergy_Settings.FlipOrientation) then
        if (Comergy_Settings.VerticalBars) then
            anchorPointV, relAnchorPointV = relAnchorPointV, anchorPointV               
        else
            anchorPointH, relAnchorPointH = relAnchorPointH, anchorPointH
        end
        direction = 2
    else
        direction = 1
    end

    if (Comergy_Settings.VerticalBars) then
        direction = direction + 2
    end

    local left, right, top, bottom
    for i = 1, n do
        left = energyBars[i].min * lenPerEnergy + (i - 1) * Comergy_Settings.Spacing
        right = energyBars[i].max * lenPerEnergy + (i - 1) * Comergy_Settings.Spacing
        top = Comergy_Settings.EnergyHeight
        bottom = 0
        if (Comergy_Settings.ShowPlayerHealthBar) then
            bottom = Comergy_Settings.HealthBarHeight + Comergy_Settings.Spacing
            top = top + bottom
        end
        energyBars[i].len = right - left

        if (Comergy_Settings.FlipBars) then
            top, bottom = -top, -bottom
        end
        if (Comergy_Settings.FlipOrientation) then
            left, right = -left, -right
        end

        energyBars[i].direction = direction
        if (ComergyBarTextures[Comergy_Settings.BarTexture][2]) then
            energyBars[i]:SetStatusBarTexture(ComergyBarTextures[Comergy_Settings.BarTexture][2])
        else
            energyBars[i]:SetStatusBarTexture(energyBars[i]:CreateTexture(nil, "ARTWORK"))
        end

        if (Comergy_Settings.VerticalBars) then
            left, bottom = bottom, left
            right, top = top, right
            energyBars[i]:GetStatusBarTexture():ClearAllPoints()
            energyBars[i]:GetStatusBarTexture():SetPoint(relAnchorPointV, 0, 0)
            energyBars[i]:GetStatusBarTexture():SetWidth(Comergy_Settings.EnergyHeight)
        else
            energyBars[i]:GetStatusBarTexture():ClearAllPoints()
            energyBars[i]:GetStatusBarTexture():SetPoint(relAnchorPointH, 0, 0)
            energyBars[i]:GetStatusBarTexture():SetHeight(Comergy_Settings.EnergyHeight)
        end

        energyBars[i]:ClearAllPoints()
        energyBars[i]:SetPoint(relAnchorPointV .. relAnchorPointH, left, bottom)
        energyBars[i]:SetPoint(anchorPointV .. anchorPointH, energyBars[i]:GetParent(), relAnchorPointV .. relAnchorPointH, right, top)

        if ((top - bottom == 0) or (right - left == 0)) then
            energyBars[i]:Hide()
        else
            energyBars[i]:Show()
        end
    end

    for i = n + 1, ENERGY_SUBBAR_NUM do
        energyBars[i]:Hide()
    end

    if (Comergy_Settings.ShowPlayerHealthBar) then
        left = 0
        right = Comergy_Settings.Width
        top = Comergy_Settings.HealthBarHeight
        bottom = 0
        if (Comergy_Settings.FlipBars) then
            top, bottom = -top, -bottom
        end
        if (Comergy_Settings.FlipOrientation) then
            left, right = -left, -right
        end

        if (Comergy_Settings.VerticalBars) then
            left, bottom = bottom, left
            right, top = top, right
            playerBar:SetOrientation("VERTICAL")
        else
            playerBar:SetOrientation("HORIZONTAL")
        end

        playerBar:ClearAllPoints()
        playerBar:SetPoint(relAnchorPointV .. relAnchorPointH, left, bottom)
        playerBar:SetPoint(anchorPointV .. anchorPointH, ComergyPlayerHealthBar:GetParent(), relAnchorPointV .. relAnchorPointH, right, top)
    end
end

function EnergyChanged(isSmallInc)
    isSmallInc = isSmallInc or false

    local changeDuration = DURATIONS["BAR_CHANGE"][1]
    if (isSmallInc) then
        changeDuration = BAR_SMALL_INC_DURATION
    end

    for i = 1, numEnergyBars do
        if (energyBars[i].min > status.curEnergy) then
            GradientObject(energyBars[i], 1, INSTANT_DURATION, 0)
            if (not Comergy_Settings.UnifiedEnergyColor) then
                for j = 1, 3 do
                    GradientObject(energyBars[i], j + 1, INSTANT_DURATION, energyBars[i].minColor[j])
                end
            end
        elseif (energyBars[i].max < status.curEnergy) then
            GradientObject(energyBars[i], 1, INSTANT_DURATION, energyBars[i].max - energyBars[i].min)
            if (not Comergy_Settings.UnifiedEnergyColor) then
                for j = 1, 3 do
                    GradientObject(energyBars[i], j + 1, INSTANT_DURATION, energyBars[i].maxColor[j])
                end
            end
        else
            GradientObject(energyBars[i], 1, changeDuration, status.curEnergy - energyBars[i].min)
            for j = 1, 3 do
                local color = energyBars[i].minColor[j] + (energyBars[i].maxColor[j] - energyBars[i].minColor[j]) / (energyBars[i].max - energyBars[i].min) * (status.curEnergy - energyBars[i].min)
                if (Comergy_Settings.UnifiedEnergyColor) then
                    local k
                    for k = 1, numEnergyBars do
                        GradientObject(energyBars[k], j + 1, changeDuration, color)
                    end
                else
                    GradientObject(energyBars[i], j + 1, changeDuration, color)
                end
            end
        end
    end

    TextChanged()
end

function ResizeComboBars()
    local comboLength = (Comergy_Settings.Width - 4 * Comergy_Settings.Spacing) / 5

    local anchorPointV = "BOTTOM"
    local relAnchorPointV = "TOP"
    local anchorPointH = "RIGHT"
    local relAnchorPointH = "LEFT"

    if (Comergy_Settings.FlipBars) then
        if (Comergy_Settings.VerticalBars) then
            anchorPointH, relAnchorPointH = relAnchorPointH, anchorPointH
        else
            anchorPointV, relAnchorPointV = relAnchorPointV, anchorPointV
        end
    end
    if (Comergy_Settings.FlipOrientation) then
        if (Comergy_Settings.VerticalBars) then
            anchorPointV, relAnchorPointV = relAnchorPointV, anchorPointV
        else
            anchorPointH, relAnchorPointH = relAnchorPointH, anchorPointH
        end
    end
    if (Comergy_Settings.VerticalBars) then
        anchorPointV, relAnchorPointV = relAnchorPointV, anchorPointV
        anchorPointH, relAnchorPointH = relAnchorPointH, anchorPointH
    end

    local left, right, top, bottom
    local lastLeft = 0
    for i = 1, 5 do
        if (ComergyBarTextures[Comergy_Settings.BarTexture][2]) then
            comboBars[i]:SetStatusBarTexture(ComergyBarTextures[Comergy_Settings.BarTexture][2])
        else
            comboBars[i]:SetStatusBarTexture(comboBars[i].blankTexture)
        end

        left = lastLeft
        right = left + comboLength + (i - 3) * comboLength * Comergy_Settings.ComboDiff
        lastLeft = right + Comergy_Settings.Spacing
        top = -status.curComboHeight
        bottom = 0
        if (Comergy_Settings.ShowTargetHealthBar) then
            bottom = bottom - Comergy_Settings.HealthBarHeight - Comergy_Settings.Spacing
            top = top + bottom
        end

        if (Comergy_Settings.FlipBars) then
            top, bottom = -top, -bottom
        end
        if (Comergy_Settings.FlipOrientation) then
            left, right = -left, -right
        end

        if (Comergy_Settings.VerticalBars) then
            left, bottom = bottom, left
            right, top = top, right
            comboBars[i]:GetStatusBarTexture():SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
        else
            comboBars[i]:GetStatusBarTexture():SetTexCoord(0, 1, 0, 1)
        end

        comboBars[i]:ClearAllPoints()
        comboBars[i]:SetPoint(relAnchorPointV .. relAnchorPointH, left, bottom)
        comboBars[i]:SetPoint(anchorPointV .. anchorPointH, comboBars[i]:GetParent(), relAnchorPointV .. relAnchorPointH, right, top)
    end

    left = 0
    right = Comergy_Settings.Width
    top = -Comergy_Settings.HealthBarHeight
    bottom = 0
    if (Comergy_Settings.FlipBars) then
        top, bottom = -top, -bottom
    end
    if (Comergy_Settings.FlipOrientation) then
        left, right = -left, -right
    end

    if (Comergy_Settings.VerticalBars) then
        left, bottom = bottom, left
        right, top = top, right
        targetBar:SetOrientation("VERTICAL")
    else
        targetBar:SetOrientation("HORIZONTAL")
    end

    targetBar:ClearAllPoints()
    targetBar:SetPoint(relAnchorPointV .. relAnchorPointH, left, bottom)
    targetBar:SetPoint(anchorPointV .. anchorPointH, ComergyTargetHealthBar:GetParent(), relAnchorPointV .. relAnchorPointH, right, top)
end

function ComboChanged()
    local combo = GetComboPoints("player", "target")

    if ((Comergy_Settings.ComboFlash) and (combo == 5)) then
        if (status.comboFlashing == 0) then
            status.comboFlashing = FLASH_TIMES
            for i = 1, #(comboBars) do
                ResetObject(comboBars[i], FLASH_VALUES)
                comboBars[i]:SetAlpha(FLASH_HIGH)
                GradientObject(comboBars[i], 1, FLASH_DURATION, Comergy_Settings.ComboBGAlpha)
                if ((Comergy_Settings.UnifiedComboColor) or (i == 5)) then
                    local color = Comergy_Settings["ComboColor5"]
                    for j = 1, 3 do
                        GradientObject(comboBars[i], j + 1, DURATIONS["COMBO_SHOW"][1], color[j])
                    end
                end
            end
        end
    else
        status.comboFlashing = 0

        for i = 1, combo do
            GradientObject(comboBars[i], 1, DURATIONS["COMBO_SHOW"][1], 1)
            if (Comergy_Settings.UnifiedComboColor) then
                local color = Comergy_Settings["ComboColor"..combo]
                for j = 1, 3 do
                    GradientObject(comboBars[i], j + 1, DURATIONS["COMBO_SHOW"][1], color[j])
                end
            end
        end

        for i = combo + 1, 5 do
            GradientObject(comboBars[i], 1, DURATIONS["COMBO_HIDE"][1], Comergy_Settings.ComboBGAlpha)
            if (Comergy_Settings.UnifiedComboColor) then
                for j = 1, 3 do
                    GradientObject(comboBars[i], j + 1, DURATIONS["COMBO_HIDE"][1], Comergy_Settings.ComboColor0[j])
                end
            end
        end
    end
    
    if ((combo ~= status.curCombo) and (combo ~= 0)) then
        if (Comergy_Settings["SoundCombo"..combo]) then
            PlaySoundFile("Interface\\AddOns\\Comergy\\sound\\combo"..combo..".mp3")
        end
    end

    status.curCombo = combo
    TextChanged()
    MainFrameToggle()
end

function PlayerHealthChanged()
    local healthPerc = status.curPlayerHealth / status.maxPlayerHealth
    GradientObject(playerBar, 1, DURATIONS["BAR_CHANGE"][1], healthPerc)
    for i = 1, 3 do
        GradientObject(playerBar, i + 1, DURATIONS["BAR_CHANGE"][1], playerBar.minColor[i] + healthPerc * (playerBar.maxColor[i] - playerBar.minColor[i]))
    end
end

function TargetHealthChanged()
    local targetName = UnitName("target")
    if (not targetName) then
        targetBar:Hide()
        GradientObject(targetBar, 1, DURATIONS["BAR_CHANGE"][1], 0)
    else
        targetBar:Show()
        GradientObject(targetBar, 1, DURATIONS["BAR_CHANGE"][1], status.curTargetHealth / status.maxTargetHealth)
    end
end

function FrameResize()
    local w = Comergy_Settings.Width
    local h = status.curComboHeight + Comergy_Settings.EnergyHeight
    local space = 0
    if (status.curComboHeight ~= 0) then
        space = space + 1
    end
    if (Comergy_Settings.EnergyHeight ~= 0) then
        space = space + 1
    end
    if (Comergy_Settings.ShowPlayerHealthBar) then
        space = space + 1
        h = h + Comergy_Settings.HealthBarHeight
    end
    if (Comergy_Settings.ShowTargetHealthBar) then
        space = space + 1
        h = h + Comergy_Settings.HealthBarHeight
    end
    if (space == 0) then
        h = Comergy_Settings.TextHeight
    else
        h = h + (space - 1) * Comergy_Settings.Spacing
    end
    if (Comergy_Settings.VerticalBars) then
        w, h = h, w
    end
    ComergyMainFrame:SetWidth(w)
    ComergyMainFrame:SetHeight(h)

    BGResize()

    ResizeEnergyBars()

    ResizeComboBars()

    ComergyEnergyText:ClearAllPoints()
    ComergyComboText:ClearAllPoints()
    if (Comergy_Settings.VerticalBars) then
        ComergyEnergyText:SetPoint("BOTTOM", ComergyMainFrame, "TOP", 0, 3)
        ComergyComboText:SetPoint("TOP", ComergyMainFrame, "BOTTOM", 0, -3)
    else
        ComergyEnergyText:SetPoint("RIGHT", ComergyMainFrame, "LEFT", -3, 0)
        ComergyComboText:SetPoint("LEFT", ComergyMainFrame, "RIGHT", 3, 0)
    end
end

function BGResize()
    ComergyMovingFrame:ClearAllPoints()

    local left, bottom = -Comergy_Settings.Spacing, -Comergy_Settings.Spacing
    local right, top = Comergy_Settings.Spacing, Comergy_Settings.Spacing

    if (not Comergy_Settings.TextCenter) then
        if (Comergy_Settings.VerticalBars) then
            local diff = (ComergyEnergyText:GetWidth() - ComergyMainFrame:GetWidth()) / 2
            diff = (diff > 0) and diff or 0
            if (Comergy_Settings.EnergyText) then
                top = Comergy_Settings.Spacing + ComergyEnergyText:GetHeight()
                left = left - diff
                right = right + diff
                diff = 0
            end
            if ((Comergy_Settings.ComboText) and (status.comboEnabled)) then
                bottom = -(Comergy_Settings.Spacing + ComergyEnergyText:GetHeight())
                left = left - diff
                right = right + diff
            end
        else
            local diff = (ComergyEnergyText:GetHeight() - ComergyMainFrame:GetHeight()) / 2
            diff = (diff > 0) and diff or 0
            if (Comergy_Settings.EnergyText) then
                left = -(Comergy_Settings.Spacing + ComergyEnergyText:GetWidth())
                top = top + diff
                bottom = bottom - diff
                diff = 0
            end
            if ((Comergy_Settings.ComboText) and (status.comboEnabled)) then
                right = Comergy_Settings.Spacing + ComergyEnergyText:GetWidth()
                top = top + diff
                bottom = bottom - diff
            end
        end
    end

    ComergyMovingFrame:SetPoint("TOPLEFT", ComergyMainFrame, "TOPLEFT", left, top)
    ComergyMovingFrame:SetPoint("BOTTOMRIGHT", ComergyMainFrame, "BOTTOMRIGHT", right, bottom)

end

function TextChanged()
    local combinedText = ""
    if (Comergy_Settings.TextCenter) then
        local text
        if (Comergy_Settings.EnergyText) then
            text = combinedText .. status.curEnergy
            combinedText = text
            if ((Comergy_Settings.ComboText) and (status.comboEnabled)) then
                if (Comergy_Settings.VerticalBars) then
                    text = combinedText .. "\n"
                else
                    text = combinedText .. " / "
                end
                combinedText = text
            end
        end
        if ((Comergy_Settings.ComboText) and (status.comboEnabled)) then
            text = combinedText .. status.curCombo
            combinedText = text .. " P"
        end
        ComergyText:SetText(combinedText)
    else
        if (Comergy_Settings.EnergyText) then
            ComergyEnergyText:SetText(status.curEnergy)
        end
        if ((Comergy_Settings.ComboText) and (status.comboEnabled)) then
            combinedText = status.curCombo .. " P"
            ComergyComboText:SetText(combinedText)
        end
    end
end

function TextStyleChanged()
    ComergyText:SetFont(getglobal(ComergyTextFonts[Comergy_Settings.TextFont][2]):GetFont(), Comergy_Settings.TextHeight)
    ComergyEnergyText:SetFont(getglobal(ComergyTextFonts[Comergy_Settings.TextFont][2]):GetFont(), Comergy_Settings.TextHeight)
    ComergyComboText:SetFont(getglobal(ComergyTextFonts[Comergy_Settings.TextFont][2]):GetFont(), Comergy_Settings.TextHeight)

    ComergyText:SetTextColor(Comergy_Settings.TextColor[1], Comergy_Settings.TextColor[2], Comergy_Settings.TextColor[3])
    ComergyEnergyText:SetTextColor(Comergy_Settings.TextColor[1], Comergy_Settings.TextColor[2], Comergy_Settings.TextColor[3])
    ComergyComboText:SetTextColor(Comergy_Settings.TextColor[1], Comergy_Settings.TextColor[2], Comergy_Settings.TextColor[3])

    if (Comergy_Settings.TextCenter) then
        ComergyText:Show()
        ComergyEnergyText:Hide()
        ComergyComboText:Hide()
        if (Comergy_Settings.TextCenterUp) then
            ComergyText:ClearAllPoints()
            ComergyText:SetPoint("BOTTOM", ComergyText:GetParent(), "TOP", 0, 0)
        else
            ComergyText:ClearAllPoints()
            ComergyText:SetPoint("CENTER", 0, 0)
        end
    else
        ComergyText:Hide()
        if (Comergy_Settings.EnergyText) then
            ComergyEnergyText:Show()
        else
            ComergyEnergyText:Hide()
        end
        if ((Comergy_Settings.ComboText) and (status.comboEnabled)) then
            ComergyComboText:Show()
        else
            ComergyComboText:Hide()
        end
    end

    ComergyEnergyText:SetText("100")
    ComergyEnergyText:SetWidth(ComergyEnergyText:GetStringWidth() + 5)
    ComergyComboText:SetText("0 P")
    ComergyComboText:SetWidth(ComergyComboText:GetStringWidth() + 5)
end

function ToggleOptions()
    if(not IsAddOnLoaded("Comergy_Options")) then
        local loaded, reason = LoadAddOn("Comergy_Options")
        if (loaded) then
            ComergyOptToggle()
        else
            DEFAULT_CHAT_FRAME:AddMessage(reason)
        end
    else
        ComergyOptToggle()
    end
end

function PopulateDefaultSettings()
    local defaultSettings = {
        Version = "1.60r",
        VersionInternal = 16000,
        ShowOnlyInCombat = false,
        ShowInStealth = true,
        ShowWhenEnergyNotFull = true,
        Locked = false,
        CritSound = false,
        StealthSound = false,
        Spacing = 4,
        Width = 220,
        ComboHeight = 10,
        EnergyHeight = 10,
        FlipBars = false,
        FlipOrientation = false,
        VerticalBars = false,

        EnergyThreshold1 = 25,
        EnergyThreshold2 = 35,
        EnergyThreshold3 = 40,
        EnergyThreshold4 = 60,
        
        EnergyColor0 = { 1, 0, 0 },
        EnergyColor1 = { 1, 0, 0 },
        EnergyColor2 = { 1, 0.5, 0 },
        EnergyColor3 = { 1, 1, 0 },
        EnergyColor4 = { 1, 1, 0 },
        EnergyColor5 = { 0, 1, 0 },

        SoundEnergy1 = false,
        SoundEnergy2 = false,
        SoundEnergy3 = false,
        SoundEnergy4 = true,
        SoundEnergy5 = false,
        SplitEnergy1 = false,
        SplitEnergy2 = true,
        SplitEnergy3 = false,
        SplitEnergy4 = true,
        EnergyText = true,
        UnifiedEnergyColor = true,

        EnergyBGColorAlpha = { 0.3, 0.3, 1, 0.5 },
        EnergyBGFlash = true,
        EnergyFlash = false,
        EnergyFlashColor = { 1, 0.2, 0.2 },

        SoundCombo1 = false,
        SoundCombo2 = false,
        SoundCombo3 = false,
        SoundCombo4 = false,
        SoundCombo5 = true,

        ComboColor0 = { 0.5, 0.5, 0.5 },
        ComboColor1 = { 1, 0, 0 },
        ComboColor2 = { 1, 0.5, 0 }, 
        ComboColor3 = { 1, 1, 0 },
        ComboColor4 = { 0, 1, 0 },
        ComboColor5 = { 0, 0.5, 1 },
        ComboText = true,
        ComboBGAlpha = 0.1,
        UnifiedComboColor = false,
        ComboFlash = true,
        ComboDiff = 0,

        TextColor = { 1, 1, 1 },
        TextHeight = 14,
        TextFont = 3,
        TextCenter = true,
        TextCenterUp = true,
        BGColorAlpha = { 0, 0, 0, 0.6 },

        BarTexture = 5,
        DurationScale = 0.8,

        X = 0,
        Y = 0,
        Point = "CENTER",

        ShowPlayerHealthBar = false,
        ShowTargetHealthBar = false,

        HealthBarHeight = 1,
    }
    return defaultSettings
end

function PopulateSettingsFrom(curSettings, fromSettings)
    local defaultSettings = PopulateDefaultSettings()

    if (not fromSettings) then
        fromSettings = defaultSettings
    end
    if (not curSettings) then
        curSettings = { }
    end

    for i, v in pairs(fromSettings) do
        if ((curSettings[i] == nil) and (defaultSettings[i] ~= nil)) then
            if (type(v) == "table") then
                curSettings[i] = { }
                for j, w in pairs(v) do
                    curSettings[i][j] = w
                end
            else
                curSettings[i] = v
            end
        end
    end
    -- Complete all the settings from default
    for i, v in pairs(defaultSettings) do
        if (curSettings[i] == nil) then
            if (type(v) == "table") then
                curSettings[i] = { }
                for j, w in pairs(v) do
                    curSettings[i][j] = w
                end
            else
                curSettings[i] = v
            end
        end
    end
    -- Discard deprecated settings
    for i, v in pairs(curSettings) do
        if (defaultSettings[i] == nil) then
            curSettings[i] = nil
        end
    end

    curSettings.VersionInternal = defaultSettings.VersionInternal
    curSettings.Version = defaultSettings.Version
    return curSettings
end

function Initialize()
    lastPeriodicUpdate = 0

    SPELL_NAME_PROWL = GetSpellInfo(SPELL_ID_PROWL)
    SPELL_NAME_SHADOW_DANCE = GetSpellInfo(SPELL_ID_SHADOW_DANCE)
    SPELL_NAME_VENDETTA = GetSpellInfo(SPELL_ID_VENDETTA)
    SPELL_NAME_ADRENALINE_RUSH = GetSpellInfo(SPELL_ID_ADRENALINE_RUSH)

    for i = 1, ENERGY_SUBBAR_NUM do
        energyBars[i] = getglobal("ComergyEnergyBar" .. i)
        local initValues = { 0, 1, 1, 1, 1 }
        InitObject(energyBars[i], initValues)

        energyBars[i].bg = energyBars[i]:CreateTexture(nil, "BORDER")
        energyBars[i].bg:SetAllPoints(energyBars[i])
        initValues = { 0.3 }
        InitObject(energyBars[i].bg, initValues)
    end

    for i = 1, 5 do
        comboBars[i] = getglobal("ComergyComboBar"..i)
        comboBars[i]:SetMinMaxValues(0, 1)
        comboBars[i]:SetValue(1)
        comboBars[i]:SetAlpha(0)

        local initValues = { 0, 0, 0, 0 }
        InitObject(comboBars[i], initValues)

        comboBars[i].blankTexture = comboBars[i]:CreateTexture(nil, "ARTWORK")

        comboBars[i].verticalInit = 0
    end

    playerBar = getglobal("ComergyPlayerHealthBar")
    playerBar:SetMinMaxValues(0, 1)
    playerBar:SetValue(0)
    playerBar:SetStatusBarTexture(playerBar:CreateTexture(nil, "ARTWORK"))
    playerBar.maxColor = { 0, 1, 0 }
    playerBar.minColor = { 1, 0, 0.1 }

    local initValues = { 0, 0, 1, 0 }
    InitObject(playerBar, initValues)

    targetBar = getglobal("ComergyTargetHealthBar")
    targetBar:SetMinMaxValues(0, 1)
    targetBar:SetValue(1)
    targetBar:SetStatusBarTexture(targetBar:CreateTexture(nil, "ARTWORK"))

    initValues = { 0, 1, 1, 1 }
    InitObject(targetBar, initValues)

    ComergyMainFrame:SetAlpha(0)
    InitObject(ComergyMainFrame, ZERO_VALUES)

    SlashCmdList["COMERGY"] = function()
            ToggleOptions()
        end

    SLASH_COMERGY1 = "/comergy"
    SLASH_COMERGY2 = "/cmg"

    local f = CreateFrame("Frame")
    f.name = "Comergy"
    
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Comergy")
    title:SetTextHeight(20)

    local text = f:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    text:SetPoint("TOPLEFT", 16, -44)
    text:SetPoint("BOTTOMRIGHT", text:GetParent(), "TOPRIGHT", -16, -56)
    text:SetJustifyH("LEFT")
    text:SetTextHeight(12)
    text:SetText(COMERGY_OPTION_FRAME_MESSAGE)

    local button = CreateFrame("Button", nil, f, "OptionsButtonTemplate")
    button:SetPoint("TOPLEFT", 16, -70)
    button:SetText(COMERGY_OPTION_FRAME_BUTTON)
    button:SetHeight(24)
    button:SetWidth(150)
    button:SetScript("OnClick", function()
        InterfaceOptionsFrameCancel_OnClick()
        HideUIPanel(GameMenuFrame)
        ToggleOptions()
    end)

    InterfaceOptions_AddCategory(f)

    ComergyMainFrame:Hide()
end

function PowerTypeChanged()
    local _, powerType = UnitPowerType("player")

    if (status.curPowerType ~= powerType) then
        status.enabled = false
        status.comboEnabled = false

        if ((powerType == "RAGE") or (powerType == "FOCUS") or (powerType == "ENERGY") or (powerType == "RUNIC_POWER")) then
            status.enabled = true
        end
        if (powerType == "ENERGY") then
            status.comboEnabled = true
        end
        status.curPowerType = powerType

        if (status.comboEnabled) then
            status.curComboHeight = Comergy_Settings.ComboHeight
        else
            status.curComboHeight = 0
        end
    end

    TextStyleChanged()
end

function ReadStatus()
    status.playerInCombat = false

    status.shapeshiftForm = GetShapeshiftForm()
    if (status.playerClass == ROGUE) then
        status.playerInStealth = ((status.shapeshiftForm > 0) and (status.shapeshiftForm < 4))
    end

    PowerTypeChanged()

    status.curEnergy = UnitPower("player")
    status.maxEnergy = UnitPowerMax("player")
    status.energyFlashing = 0
    status.energyBGFlashing = 0

    status.curCombo = GetComboPoints("player", "target")
    status.comboFlashing = 0

    status.maxPlayerHealth = UnitHealthMax("player")
    status.curPlayerHealth = UnitHealth("player")

    status.maxTargetHealth = UnitHealthMax("target")
    status.curTargetHealth = UnitHealth("target")

    if (not status.enabled) then
        return
    end

    ComergyOnConfigChange()

    ComergyRestorePosition()
end

function ComergyOnConfigChange()
    if (Comergy_Settings.DurationScale ~= 0) then
        for i, v in pairs(DURATIONS) do
            DURATIONS[i][1] = DURATIONS[i][2] * Comergy_Settings.DurationScale
        end
    else
        for i, v in pairs(DURATIONS) do
            DURATIONS[i][1] = INSTANT_DURATION
        end
    end

    if (Comergy_Settings.Locked) then
        ComergyMovingFrame:EnableMouse(false)
    else
        ComergyMovingFrame:EnableMouse(true)
    end

    for i = 1, ENERGY_SUBBAR_NUM - 1 do
        local th = Comergy_Settings["EnergyThreshold"..i]
        if ((th) and (th < status.maxEnergy) and (th > 0)) then
            local temp = { th, i }
            orderedThresholds[i] = temp
        end
    end
    table.sort(orderedThresholds, function(a, b) return a[1] < b[1] end)

    local lastThreshold = 0
    for i = 1, #(orderedThresholds) do
        if (orderedThresholds[i][1] == lastThreshold) then
            orderedThresholds[i][1] = -1
        else
            lastThreshold = orderedThresholds[i][1]
        end
    end

    FrameResize()

    for i = 1, 5 do
        ResetObject(comboBars[i], { comboBars[i].curValue[1], comboBars[i].curValue[2], comboBars[i].curValue[3], comboBars[i].curValue[4] + 0.01 })
        if (not Comergy_Settings.UnifiedComboColor) then
            local color = Comergy_Settings["ComboColor"..i]
            for j = 1, 3 do
                GradientObject(comboBars[i], j + 1, DURATIONS["COMBO_SHOW"][1], color[j])
            end
        end
    end

    if (not status.comboEnabled) then
        status.curComboHeight = 0
    else
        status.curComboHeight = Comergy_Settings.ComboHeight
    end

    for i = 1, numEnergyBars do
        GradientObject(energyBars[i].bg, 1, INSTANT_DURATION, Comergy_Settings.EnergyBGColorAlpha[4] * 0.3)
        ResetObject(energyBars[i], { energyBars[i].curValue[1], energyBars[i].curValue[2], energyBars[i].curValue[3], energyBars[i].curValue[4] + 0.01, 1 })
    end

    ComergyBG:SetTexture(Comergy_Settings.BGColorAlpha[1], Comergy_Settings.BGColorAlpha[2], Comergy_Settings.BGColorAlpha[3], Comergy_Settings.BGColorAlpha[4])

    if (Comergy_Settings.ShowPlayerHealthBar) then
        playerBar:Show()
    else
        playerBar:Hide()
    end

    if (Comergy_Settings.ShowTargetHealthBar) then
        targetBar:Show()
    else
        targetBar:Hide()
    end

    EnergyChanged()
    ComboChanged()
    TextStyleChanged()
    PlayerHealthChanged()

    MainFrameToggle()
end

function ComergyOnLoad(self)
    status.initialized = false

    local playerClass = select(2, UnitClass("player"))

    if ((playerClass == "ROGUE") or (playerClass == "DRUID") or (playerClass == "WARRIOR") or (playerClass == "DEATHKNIGHT") or
         (playerClass == "HUNTER")) then

        if (playerClass == "ROGUE") then
            status.playerClass = ROGUE
        elseif (playerClass == "DRUID") then
            status.playerClass = DRUID
        else
            status.playerClass = OTHER
        end

        self:SetScript("OnEvent", function(self, event, ...)
            if ((event == "ADDON_LOADED") or (event == "PLAYER_ENTERING_WORLD") or (event == "PLAYER_LOGIN")) then
                -- Execute any time
                EventHandlers[event](...)
            else
                if (not status.initialized) then
                    return
                end
                -- Events that need to be associated with player
                if ((event == "UNIT_COMBO_POINTS") or (event == "UNIT_MAXPOWER") or (event == "UNIT_POWER")
                    or (event == "UNIT_MAXHEALTH") or (event == "UNIT_HEALTH")) then
                    if (select(1, ...) ~= "player") then
                        return
                    end
                end
                EventHandlers[event](...)
            end
        end)
        
        self:RegisterEvent("ADDON_LOADED")
        self:RegisterEvent("PLAYER_LOGIN")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")

        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_UNGHOST")
        self:RegisterEvent("PLAYER_ALIVE")
        self:RegisterEvent("PLAYER_TARGET_CHANGED")
        self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        self:RegisterEvent("UPDATE_SHAPESHIFT_FORM")

        self:RegisterEvent("UNIT_COMBO_POINTS")
        self:RegisterEvent("UNIT_MAXPOWER")
        self:RegisterEvent("UNIT_POWER")
        self:RegisterEvent("UNIT_MAXHEALTH")
        self:RegisterEvent("UNIT_HEALTH")

        self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    else
        ComergyMainFrame:Hide()
    end
end

function ComergyGetTalent()
    local _, primaryName = GetSpecializationInfo(GetSpecialization())
    return status.talent, primaryName
end

-- Event Handlers --

EventHandlers = {}

function EventHandlers.ADDON_LOADED(addonName)
    if (addonName == "Comergy") then
        Initialize()
    end
end

function EventHandlers.PLAYER_LOGIN()
    status.talent = GetActiveSpecGroup()

    if (not Comergy_Config) then
        Comergy_Config = { }
    end
    if (not Comergy_Config[status.talent]) then
        Comergy_Config[status.talent] = PopulateSettingsFrom(Comergy_Config[status.talent], Comergy_Config)
    end

    for i, v in pairs(Comergy_Config) do
        if ((i ~= 1) and (i ~= 2)) then
            Comergy_Config[i] = nil
        end
    end

    Comergy_Config[status.talent] = PopulateSettingsFrom(Comergy_Config[status.talent], Comergy_Config[3 - status.talent])

    Comergy_Settings = Comergy_Config[status.talent]
end

function EventHandlers.PLAYER_ENTERING_WORLD()
    status.playerGUID = UnitGUID("player")
    ReadStatus()

    ComergyRestorePosition()

    ComergyOnConfigChange()

    EnergyChanged()
    ComboChanged()
    PlayerHealthChanged()
    TargetHealthChanged()

    status.initialized = true
end

-- For Druid cat form change and rogue stealth
function EventHandlers.UPDATE_SHAPESHIFT_FORM()

    PowerTypeChanged()

    if (status.playerClass == DRUID) then
        if (status.enabled) then
            status.maxEnergy = UnitPowerMax("player")
            ResizeEnergyBars()
            FrameResize()
        end
        MainFrameToggle()
    end

    -- Rogue's Shadow Dance and Stealth
    if (status.playerClass == ROGUE) then
        local form = GetShapeshiftForm()
        status.playerInStealth = ((form > 0) and (form < 4))
        MainFrameToggle()

        if ((form > 0) and (form < 4) and (Comergy_Settings.StealthSound) and (status.shapeshiftForm == 0)) then        
            PlaySoundFile("Sound\\interface\\iQuestUpdate.wav")
        end
        status.shapeshiftForm = form
    end
end

function EventHandlers.COMBAT_LOG_EVENT_UNFILTERED(...)
    if (select(4, ...) == status.playerGUID) then
        local type = select(2, ...)
        if ((type == "SPELL_DAMAGE") and (Comergy_Settings.CritSound)) then
            if (select(21, ...)) then
                PlaySoundFile("Interface\\AddOns\\Comergy\\Sound\\critical.mp3")
            end
        elseif ((type == "SPELL_CAST_FAILED") and ((select(15, ...) == ERR_OUT_OF_ENERGY) or (select(15, ...) == ERR_OUT_OF_FOCUS))
                and (Comergy_Settings.EnergyBGFlash)) then
            if (status.energyBGFlashing == 0) then
                status.energyBGFlashing = FLASH_TIMES
                for i = 1, numEnergyBars do
                    ResetObject(energyBars[i].bg, FLASH_VALUES)
                    GradientObject(energyBars[i].bg, 1, FLASH_DURATION, Comergy_Settings.EnergyBGColorAlpha[4] * 0.3)
                end
            end
        elseif ((type == "SPELL_AURA_APPLIED") or (type == "SPELL_AURA_REFRESH")) then
            local name = select(13, ...)
            if (name == SPELL_NAME_PROWL) then
                status.playerInStealth = true
                MainFrameToggle()
            elseif ((name == SPELL_NAME_SHADOW_DANCE) or (name == SPELL_NAME_VENDETTA) or (name == SPELL_NAME_ADRENALINE_RUSH)) then
                if (Comergy_Settings.EnergyFlash) then
                    status.energyFlashing = 1
                    local newValues = { -1, -1, -1, -1, 1 }
                    for i = 1, numEnergyBars do
                        ResetObject(energyBars[i], newValues)
                        energyBars[i]:SetAlpha(1)
                        GradientObject(energyBars[i], 5, FLASH_DURATION, 0)
                    end
                end
            end
        elseif (type == "SPELL_AURA_REMOVED") then
            local name = select(13, ...)
            if (name == SPELL_NAME_PROWL) then
                status.playerInStealth = false
                MainFrameToggle()
            elseif ((name == SPELL_NAME_SHADOW_DANCE) or (name == SPELL_NAME_VENDETTA) or (name == SPELL_NAME_ADRENALINE_RUSH)) then
                if (status.energyFlashing == 1) then
                    status.energyFlashing = 0
                    local newValues = { -1, -1, -1, -1, 1 }
                    for i = 1, numEnergyBars do
                        ResetObject(energyBars[i], newValues)
                        energyBars[i]:SetAlpha(1)
                        if (ComergyBarTextures[Comergy_Settings.BarTexture][2]) then
                            energyBars[i]:SetStatusBarColor(energyBars[i].curValue[2], energyBars[i].curValue[3], energyBars[i].curValue[4])
                        else
                            energyBars[i]:GetStatusBarTexture():SetTexture(energyBars[i].curValue[2], energyBars[i].curValue[3], energyBars[i].curValue[4])
                        end
                    end
                end
            end
        end
    end
end

function EventHandlers.PLAYER_REGEN_DISABLED()
    status.playerInCombat = true
    MainFrameToggle()
end

function EventHandlers.PLAYER_REGEN_ENABLED()
    status.playerInCombat = false
    MainFrameToggle()
end

function EventHandlers.PLAYER_ALIVE()
    ReadStatus()

    ResizeEnergyBars()
    EnergyChanged()
    PlayerHealthChanged()
    TargetHealthChanged()
end

function EventHandlers.PLAYER_UNGHOST()
    ReadStatus()

    ResizeEnergyBars()
    EnergyChanged()
    PlayerHealthChanged()
    TargetHealthChanged()
end

function EventHandlers.UNIT_COMBO_POINTS()
    if (not status.comboEnabled) then
        return
    end

    ComboChanged()
end

function EventHandlers.PLAYER_TARGET_CHANGED()
    if (not status.enabled) then
        return
    end

    ComboChanged()

    if (Comergy_Settings.ShowTargetHealthBar) then
        status.maxTargetHealth = UnitHealthMax("target")
        TargetHealthChanged()

        local className
        _, className = UnitClass("target")
        if (className) then
            local color = RAID_CLASS_COLORS[className]
            GradientObject(targetBar, 2, DURATIONS["BAR_CHANGE"][1], color.r)
            GradientObject(targetBar, 3, DURATIONS["BAR_CHANGE"][1], color.g)
            GradientObject(targetBar, 4, DURATIONS["BAR_CHANGE"][1], color.b)
        end
    end
end

function EventHandlers.UNIT_MAXPOWER()
    status.maxEnergy = UnitPowerMax("player")
    ResizeEnergyBars()
end

function EventHandlers.UNIT_POWER()
    if (not status.playerInCombat) then
        status.curEnergy = UnitPower("player")
        MainFrameToggle()
    end
end

function EventHandlers.UNIT_MAXHEALTH()
    if (Comergy_Settings.showPlayerHealthBar) then
        status.maxPlayerHealth = UnitHealthMax("player")
        PlayerHealthChanged()
        MainFrameToggle()
    end
end

function EventHandlers.UNIT_HEALTH()
    if (Comergy_Settings.showPlayerHealthBar) then
        status.curPlayerHealth = UnitHealth("player")
        PlayerHealthChanged()
        MainFrameToggle()
    end
end

function EventHandlers.ACTIVE_TALENT_GROUP_CHANGED()
    status.talent = GetActiveSpecGroup()

    if (not Comergy_Config[status.talent]) then
        Comergy_Config[status.talent] = { }
    end

    Comergy_Config[status.talent] = PopulateSettingsFrom(Comergy_Config[status.talent], Comergy_Config[3 - status.talent])
    Comergy_Settings = Comergy_Config[status.talent]
    ComergyOnConfigChange()

    ComergyRestorePosition()

    if (IsAddOnLoaded("Comergy_Options")) then
        ComergyOptReadSettings()
    end
end

function ComergySavePosition()
    Comergy_Settings.Point, _, _, Comergy_Settings.X, Comergy_Settings.Y = ComergyMainFrame:GetPoint(1)
end


function ComergyRestorePosition()
    ComergyMainFrame:ClearAllPoints()
    ComergyMainFrame:SetPoint(Comergy_Settings.Point, UIParent, Comergy_Settings.Point, Comergy_Settings.X, Comergy_Settings.Y)
end

function ComergyOnUpdate(self, elapsed)
    if (not status.initialized) then
        return
    end

    OnFrameUpdate(elapsed)

    if (not status.enabled) then
        return
    end

    local count = 0
    lastPeriodicUpdate = lastPeriodicUpdate + elapsed
    while (lastPeriodicUpdate >= PERIODIC_UPDATE_INTERVAL) do
        count = count + 1
        lastPeriodicUpdate = lastPeriodicUpdate - PERIODIC_UPDATE_INTERVAL
    end
    if (count > 0) then
        OnPeriodicUpdate()
    end
end

function OnFrameUpdate(elapsed)

    if (UpdateObject(ComergyMainFrame, elapsed)) then
        ComergyMainFrame:SetAlpha(ComergyMainFrame.curValue[1])
        if (ComergyMainFrame.curValue[1] == 0) then
            ComergyMainFrame:Hide()
        end
    end

    if (not status.enabled) then
        return
    end

    if (status.comboEnabled) then
        for i = 1, 5 do
            if (UpdateObject(comboBars[i], elapsed)) then
                -- Very nasty hack for rotating textures...
                if ((comboBars[i].verticalInit < 2) and (Comergy_Settings.VerticalBars)) then
                    comboBars[i]:GetStatusBarTexture():SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
                    comboBars[i].verticalInit = comboBars[i].verticalInit + 1
                end
                comboBars[i]:SetAlpha(comboBars[i].curValue[1])
                if (ComergyBarTextures[Comergy_Settings.BarTexture][2]) then
                    comboBars[i]:SetStatusBarColor(comboBars[i].curValue[2], comboBars[i].curValue[3], comboBars[i].curValue[4])
                else
                    comboBars[i]:GetStatusBarTexture():SetTexture(comboBars[i].curValue[2], comboBars[i].curValue[3], comboBars[i].curValue[4])
                end
            end
        end

        if ((status.comboFlashing > 0) and (comboBars[1].curValue[1] == Comergy_Settings.ComboBGAlpha)) then
            status.comboFlashing = status.comboFlashing - 1
            if (status.comboFlashing > 0) then
                for i = 1, #(comboBars) do
                    ResetObject(comboBars[i], FLASH_VALUES)
                    comboBars[i]:SetAlpha(comboBars[i].curValue[1])
                    GradientObject(comboBars[i], 1, FLASH_DURATION, Comergy_Settings.ComboBGAlpha)
                end
            else
                for i = 1, #(comboBars) do
                    ResetObject(comboBars[i], ONE_VALUES)
                    comboBars[i]:SetAlpha(comboBars[i].curValue[1])
                end
            end
        end
    end

    for i = 1, numEnergyBars do
        if (UpdateObject(energyBars[i], elapsed)) then
            SetStatusBarValue(energyBars[i], energyBars[i].curValue[1])
            local r, g, b
            if (status.energyFlashing > 0) then
                energyBars[i]:SetAlpha(energyBars[i].curValue[5])
                r = Comergy_Settings.EnergyFlashColor[1]
                g = Comergy_Settings.EnergyFlashColor[2]
                b = Comergy_Settings.EnergyFlashColor[3]
            else
                r = energyBars[i].curValue[2]
                g = energyBars[i].curValue[3]
                b = energyBars[i].curValue[4]
            end

            if (ComergyBarTextures[Comergy_Settings.BarTexture][2]) then
                energyBars[i]:SetStatusBarColor(r, g, b)
            else
                energyBars[i]:GetStatusBarTexture():SetTexture(r, g, b)
            end
        end

        if (UpdateObject(energyBars[i].bg, elapsed)) then
            energyBars[i].bg:SetTexture(Comergy_Settings.EnergyBGColorAlpha[1], Comergy_Settings.EnergyBGColorAlpha[2], 
                Comergy_Settings.EnergyBGColorAlpha[3], energyBars[i].bg.curValue[1])
        end
    end

    if ((status.energyFlashing > 0) and (energyBars[1].curValue[5] == 0)) then
        local newValues = { -1, -1, -1, -1, 1 }
        for i = 1, numEnergyBars do
            ResetObject(energyBars[i], newValues)
            energyBars[i]:SetAlpha(1)
            GradientObject(energyBars[i], 5, FLASH_DURATION, 0)
        end
    end

    if ((status.energyBGFlashing > 0) and (energyBars[1].bg.curValue[1] == Comergy_Settings.EnergyBGColorAlpha[4] * 0.3)) then
        status.energyBGFlashing = status.energyBGFlashing - 1
        if (status.energyBGFlashing > 0) then
            for i = 1, numEnergyBars do
                ResetObject(energyBars[i].bg, FLASH_VALUES)
                energyBars[i].bg:SetTexture(Comergy_Settings.EnergyBGColorAlpha[1], Comergy_Settings.EnergyBGColorAlpha[2],
                    Comergy_Settings.EnergyBGColorAlpha[3], energyBars[i].bg.curValue[1])
                GradientObject(energyBars[i].bg, 1, FLASH_DURATION, Comergy_Settings.EnergyBGColorAlpha[4] * 0.3)
            end
        else
            for i = 1, numEnergyBars do
                ResetObject(energyBars[i].bg, { Comergy_Settings.EnergyBGColorAlpha[4] * 0.3 })
                energyBars[i].bg:SetTexture(Comergy_Settings.EnergyBGColorAlpha[1], Comergy_Settings.EnergyBGColorAlpha[2],
                    Comergy_Settings.EnergyBGColorAlpha[3], energyBars[i].bg.curValue[1])
            end
        end
    end

    if (Comergy_Settings.ShowPlayerHealthBar) then
        if (UpdateObject(playerBar, elapsed)) then
            playerBar:SetValue(playerBar.curValue[1])
            playerBar:GetStatusBarTexture():SetTexture(playerBar.curValue[2], playerBar.curValue[3], playerBar.curValue[4])
        end
    end

    if (Comergy_Settings.ShowTargetHealthBar) then
        if (UpdateObject(targetBar, elapsed)) then
            targetBar:SetValue(targetBar.curValue[1])
            targetBar:GetStatusBarTexture():SetTexture(targetBar.curValue[2], targetBar.curValue[3], targetBar.curValue[4])
        end
    end
end

function OnPeriodicUpdate()
    local curEnergy = UnitPower("player")
    if (status.curEnergy ~= curEnergy) then
        if ((curEnergy > status.curEnergy) and ((not Comergy_Settings.ShowOnlyInCombat) or (status.playerInCombat))) then
            local sound = false
            for i = 1, ENERGY_SUBBAR_NUM - 1 do
                if ((Comergy_Settings["EnergyThreshold"..i] > status.curEnergy) and (Comergy_Settings["EnergyThreshold"..i] <= curEnergy) and (Comergy_Settings["SoundEnergy"..i])) then
                    sound = true
                    break
                end
            end
            if ((status.maxEnergy == curEnergy) and (Comergy_Settings["SoundEnergy"..ENERGY_SUBBAR_NUM])) then
                sound = true
            end
            if (sound) then
                PlaySoundFile("Interface\\AddOns\\Comergy\\sound\\energytick.mp3")
            end
        end

        local diff = curEnergy - status.curEnergy
        local isSmallInc = (diff >= 1) and (diff <= 3)
        status.curEnergy = curEnergy

        if ((status.curEnergy == status.maxEnergy) and ((status.curPowerType == "ENERGY") or (status.curPowerType == "FOCUS"))) then
            MainFrameToggle()
        end
        if ((status.curEnergy == 0) and ((status.curPowerType == "RAGE") or (status.curPowerType == "RUNIC_POWER"))) then
            MainFrameToggle()
        end

        EnergyChanged(isSmallInc)
    end

    if (Comergy_Settings.ShowPlayerHealthBar) then
        local curHealth = UnitHealth("player")
        local maxHealth = UnitHealthMax("player")
        if (status.curPlayerHealth ~= curHealth) then
            status.curPlayerHealth = curHealth
            PlayerHealthChanged()
            MainFrameToggle()
        end
        if (status.maxPlayerHealth ~= maxHealth) then
            status.maxPlayerHealth = maxHealth
            PlayerHealthChanged()
            MainFrameToggle()
        end
    end

    if (Comergy_Settings.ShowTargetHealthBar) then
        local curHealth = UnitHealth("target")
        if (status.curTargetHealth ~= curHealth) then
            status.curTargetHealth = curHealth
            TargetHealthChanged()
        end
    end
end
