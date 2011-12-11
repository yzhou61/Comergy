local sliders = {}
local checkButtons = {}
local colorButtons = {}
local editBoxes = {}
local clickables = {}

local i, j

local SliderOnValueChanged, CheckButtonOnClick
local CreateSlider, CreateCheckButton, CreateEditBox, QuitColor, QuitAlpha, CreateColorButton
local DisableWidget, EnableWidget, SetCheckBox, SetClickables, ChooseTexture, ChooseFont
local Check, Slide, Color, Text, ClearEditBoxFocus, StringToColor

function StringToColor(str)
	local color = { }
	local number = tonumber(str, 16)
	if (not number) then
		return nil
	else
		color.r = floor(number / 65536) % 256 / 256
		color.g = floor(number / 256) % 256 / 256
		color.b = number % 256 / 256
	end
	return color
end

function SliderOnValueChanged(self, value)
	local _, _, name = string.find(self:GetName(),"ComergyOptSlider(.+)")
	Comergy_Settings[name] = self:GetValue()
	if (self.editBox) then
		self.editBox:SetText(value)
	end
	ComergyOnConfigChange()
end

function CheckButtonOnClick(button)
	local _, _, name = string.find(button:GetName(),"ComergyOptCheckButton(.+)")
	
	Comergy_Settings[name] = (button:GetChecked() and true or false)
	PlaySound(button:GetChecked() and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
	SetCheckBox()
	ComergyOnConfigChange()

	ComergyOptEditBoxEnergyThreshold1:ClearFocus()
end

function CreateSlider(name, min, max, parent, x, y, width, valueStep, title, editBox, minText, maxText)
	local slider = CreateFrame("Slider", "ComergyOptSlider"..name, parent, "OptionsSliderTemplate")
	slider:SetMinMaxValues(min, max)
	slider:SetWidth(width)
	slider:SetHeight(16)
	slider:SetPoint("TOPLEFT", x, y)
	slider:SetValueStep(valueStep)
	getglobal(slider:GetName().."Text"):SetText(title)
	if (minText) then
		getglobal(slider:GetName().."Low"):SetText(minText)
		getglobal(slider:GetName().."High"):SetText(maxText)
	else
		getglobal(slider:GetName().."Low"):SetText(min)
		getglobal(slider:GetName().."High"):SetText(max)
	end

	if (editBox) then
		slider.editBox = CreateFrame("EditBox", slider:GetName().."EditBox", slider, "ComergyOptEditBoxTemplate")
		slider.editBox:SetPoint("LEFT", slider, "RIGHT", 15, 0)
		slider.editBox:SetNumeric(true)
		slider.editBox:SetMaxLetters(4)
		slider.editBox:SetWidth(40)

		tinsert(editBoxes, slider.editBox)
	end
	slider:SetScript("OnValueChanged", function(self, value)
		SliderOnValueChanged(self, value)
	end)

	tinsert(sliders, slider)
	tinsert(clickables, slider)
end

function CreateCheckButton(name, parent, x, y)
	local checkButton
	if (COMERGY_CHECKOPTINFO[name]) then
		checkButton = CreateFrame("CheckButton", "ComergyOptCheckButton"..name, parent, "OptionsCheckButtonTemplate")
		getglobal(checkButton:GetName().."Text"):SetTextColor(1, 1, 1)
		getglobal(checkButton:GetName().."Text"):SetText(COMERGY_CHECKOPTINFO[name])
	else
		checkButton = CreateFrame("CheckButton", "ComergyOptCheckButton"..name, parent, "UICheckButtonTemplate")
		checkButton:SetWidth(24)
		checkButton:SetHeight(24)
	end
	checkButton:SetPoint("TOPLEFT", x, y)
	checkButton:SetScript("OnClick", function(self)
		CheckButtonOnClick(self)
	end)

	tinsert(checkButtons, checkButton)
	tinsert(clickables, checkButton)
end

function CreateEditBox(name, parent, x, y)
	local editBox = CreateFrame("EditBox", "ComergyOptEditBox"..name, parent, "ComergyOptEditBoxTemplate")
	editBox:SetPoint("TOPLEFT", x, y)

	tinsert(editBoxes, editBox)
	tinsert(clickables, editBox)
end

function QuitColor(issave, name)
	local r, g, b, a
	if issave then
		r, g, b = ColorPickerFrame:GetColorRGB()
		a = OpacitySliderFrame:GetValue()
	else
		local c = ColorPickerFrame.previousValues
		r, g, b, a = c[1], c[2], c[3], c[4]
	end
	Comergy_Settings[name][1] = r
	Comergy_Settings[name][2] = g
	Comergy_Settings[name][3] = b
	Comergy_Settings[name][4] = a 

	ColorPickerFrame.button:GetNormalTexture():SetVertexColor(r, g, b)
	ComergyOnConfigChange()

	Text()
end

function QuitAlpha(name)
	Comergy_Settings[name][4] = OpacitySliderFrame:GetValue()
	ComergyOnConfigChange()
end

function CreateColorButton(name, parent, x, y, editBox)
	local colorButton = CreateFrame("Button", "ComergyOptColor"..name, parent)
	colorButton:SetNormalTexture("Interface/ChatFrame/ChatFrameColorSwatch")

	local bg = colorButton:CreateTexture(nil, "BACKGROUND")
	bg:SetWidth(14)
	bg:SetHeight(14)
	bg:SetTexture(0, 0, 0)
	bg:SetPoint("CENTER")

	if (editBox) then
		colorButton.editBox = CreateFrame("EditBox", colorButton:GetName().."EditBox", colorButton, "ComergyOptEditBoxTemplate")
		colorButton.editBox:SetPoint("LEFT", colorButton, "RIGHT", 10, 0)
		colorButton.editBox:SetMaxLetters(6)
		colorButton.editBox:SetWidth(60)
		colorButton.editBox:SetNumeric(false)

		tinsert(editBoxes, colorButton.editBox)
	end
	
	local label = colorButton:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	label:SetPoint("RIGHT", colorButton, "LEFT")
	if (COMERGY_COLORPICKERINFO[name]) then
		label:SetText(COMERGY_COLORPICKERINFO[name])
	end
	colorButton:SetWidth(24)
	colorButton:SetHeight(24)
	
	colorButton:RegisterForClicks("LeftButtonUp")
	colorButton:SetScript("OnClick", function(self)
		if ColorPickerFrame:IsShown() then
			ColorPickerFrame:Hide()
		else
			local r, g, b, a = Comergy_Settings[name][1], Comergy_Settings[name][2], Comergy_Settings[name][3], Comergy_Settings[name][4]
			ColorPickerFrame.button = self
			ColorPickerFrame.previousValues = {r, g, b, a}
			
			ColorPickerFrame.func = function() QuitColor(true, name) end
			ColorPickerFrame.cancelFunc = function() QuitColor(false, name) end

			ColorPickerFrame.hasOpacity = true
			if (a) then
				ColorPickerFrame.opacity = a
			else
				ColorPickerFrame.opacity = 1
			end
			ColorPickerFrame.opacityFunc = function() QuitAlpha(name) end
			
			ColorPickerFrame:SetColorRGB(r, g, b)

			ShowUIPanel(ColorPickerFrame)
		end
	end)

	colorButton:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	colorButton:Show()

	tinsert(colorButtons, colorButton)
	tinsert(clickables, colorButton)
end

function DisableWidget(widget)
	widget:Disable()
	widget:SetAlpha(0.5)
end

function EnableWidget(widget)
	widget:Enable()
	widget:SetAlpha(1)
end

function SetCheckBox()
	if (ComergyOptCheckButtonShowOnlyInCombat:GetChecked()) then
		EnableWidget(ComergyOptCheckButtonShowWhenEnergyNotFull)
		EnableWidget(ComergyOptCheckButtonShowInStealth)
	else
		DisableWidget(ComergyOptCheckButtonShowWhenEnergyNotFull)
		DisableWidget(ComergyOptCheckButtonShowInStealth)
	end

	if (ComergyOptCheckButtonTextCenter:GetChecked()) then
		EnableWidget(ComergyOptCheckButtonTextCenterUp)
	else
		DisableWidget(ComergyOptCheckButtonTextCenterUp)
	end

	for i = 1, 4 do
		if (getglobal("ComergyOptCheckButtonSplitEnergy"..i):GetChecked()) then
			local color = getglobal("ComergyOptColorEnergyColor"..i)
			EnableWidget(color)
		else
			local color = getglobal("ComergyOptColorEnergyColor"..i)
			DisableWidget(color)
		end
	end

	if (ComergyOptCheckButtonEnergyFlash:GetChecked()) then
		EnableWidget(ComergyOptColorEnergyFlashColor)
	else
		DisableWidget(ComergyOptColorEnergyFlashColor)
	end
end

function SetClickables()
	for i = 1, #(clickables) do
		clickables[i]:SetScript("OnMouseDown", function()
			ClearEditBoxFocus()
		end)
	end
end

function ChooseTexture(i)
	Comergy_Settings.BarTexture = i
	ComergyTextureDropdownText:SetText(ComergyBarTextures[i][1])
	ComergyOnConfigChange()
end

function ChooseFont(i)
	Comergy_Settings.TextFont = i
	ComergyTextDropdownText:SetText(ComergyTextFonts[i][1])
	ComergyOnConfigChange()
end

function Check()
	for i = 1, #(checkButtons) do
		local _, _, name = string.find(checkButtons[i]:GetName(), "ComergyOptCheckButton(.+)")
		checkButtons[i]:SetChecked(Comergy_Settings[name])
	end
	SetCheckBox()
end

function Slide()
	for i = 1, #(sliders) do
		local _, _, name = string.find(sliders[i]:GetName(), "ComergyOptSlider(.+)")
		sliders[i]:SetValue(Comergy_Settings[name])
	end
end

function Color()
	for i = 1, #(colorButtons) do
		local _, _, name = string.find(colorButtons[i]:GetName(), "ComergyOptColor(.+)")
		local color = Comergy_Settings[name]
		colorButtons[i]:GetNormalTexture():SetVertexColor(color[1], color[2], color[3])
	end
end

function Text()
	for i = 1, #(editBoxes) do
		local _, _, name = string.find(editBoxes[i]:GetName(), "ComergyOptEditBox(.+)")
		if (name) then
			editBoxes[i]:SetText(Comergy_Settings[name])
		else
			_, _, name = string.find(editBoxes[i]:GetName(), "ComergyOptSlider(.+)")
			if (name) then
				editBoxes[i]:SetText(editBoxes[i]:GetParent():GetValue())
			else
				_, _, name = string.find(editBoxes[i]:GetName(), "ComergyOptColor(.+)")
				if (name) then
					local color = { }
					color[1], color[2], color[3] = editBoxes[i]:GetParent():GetNormalTexture():GetVertexColor()
					for j = 1, 3 do
						color[j] = floor(color[j] * 256 + .1)
						if (color[j] > 255) then
							color[j] = 255
						end
					end
					editBoxes[i]:SetText(string.format("%.2X%.2X%.2X", color[1], color[2], color[3]))
				end
			end
		end
	end
end

function ComergyOptReadSettings()
	Check()
	Slide()
	Color()
	Text()

	ComergyTextureDropdownText:SetText(ComergyBarTextures[Comergy_Settings.BarTexture][1])
	ComergyTextDropdownText:SetText(ComergyTextFonts[Comergy_Settings.TextFont][1])

	local talent, name = ComergyGetTalent()
	if (talent == 1) then
		talent = COMERGY_TALENT_PRIMARY
	else
		talent = COMERGY_TALENT_SECONDARY
	end
	ComergyOptTitle:SetText("Comergy "..Comergy_Settings.Version.." - "..talent..COMERGY_TALENT.." ("..name..")")
end

function ComergyOptOnLoad()
	--Options Frame needs to be UISpecialFrame
	tinsert(UISpecialFrames,"ComergyOptFrame")

	CreateSlider("Width", 20, floor(UIParent:GetWidth()), ComergyOptGeneralFrame, 20, -175, 200, 1, COMERGY_WIDTH, true)
	CreateSlider("Spacing", 0, 15, ComergyOptGeneralFrame, 20, -210, 110, 1, COMERGY_SPACING)
	CreateSlider("TextHeight", 6, 26, ComergyOptGeneralFrame, 20, -245, 110, 1, COMERGY_FONT_SIZE, false)
	CreateSlider("DurationScale", 0, 2, ComergyOptGeneralFrame, 20, -280, 110, 0.2, COMERGY_DURATION_SCALE, false, COMERGY_LOW, COMERGY_HIGH)

	CreateSlider("EnergyHeight", 0, 50, ComergyOptEnergyFrame, 20, -220, 110, 1, COMERGY_ENERGY_HEIGHT, false)

	CreateSlider("ComboHeight", 0, 50, ComergyOptComboFrame, 25, -230, 110, 1, COMERGY_COMBO_HEIGHT, false)
	CreateSlider("ComboBGAlpha", 0, 0.3, ComergyOptComboFrame, 160, -230, 110, 0.02, COMERGY_COMBO_BG_ALPHA, false)
	CreateSlider("ComboDiff", -0.3, 0.3, ComergyOptComboFrame, 160, -265, 110, 0.02, COMERGY_COMBO_FANCY, false, COMERGY_LEFT, COMERGY_RIGHT)

	CreateCheckButton("ShowOnlyInCombat", ComergyOptGeneralFrame, 13, -10)
	CreateCheckButton("ShowWhenEnergyNotFull", ComergyOptGeneralFrame, 33, -30)
	CreateCheckButton("ShowInStealth", ComergyOptGeneralFrame, 33, -50)
	CreateCheckButton("Locked", ComergyOptGeneralFrame, 13, -80)
	CreateCheckButton("CritSound", ComergyOptGeneralFrame, 163, -80)
	CreateCheckButton("StealthSound", ComergyOptGeneralFrame, 13, -100)

	CreateCheckButton("FlipBars", ComergyOptGeneralFrame, 13, -310)
	CreateCheckButton("FlipOrientation", ComergyOptGeneralFrame, 13, -330)
	CreateCheckButton("VerticalBars", ComergyOptGeneralFrame, 13, -350)
	CreateCheckButton("TextCenter", ComergyOptGeneralFrame, 163, -330)
	CreateCheckButton("TextCenterUp", ComergyOptGeneralFrame, 183, -350)

	local b = CreateFrame("Button", nil, ComergyOptGeneralFrame, "OptionsButtonTemplate")
	b:SetText(COMERGY_HCENTER)
	b:SetWidth(120)
	b:SetHeight(30)
	b:SetPoint("TOPLEFT", 25, -130)
	b:SetScript("OnClick", function()
		local point = ComergyMainFrame:GetPoint(1)
		if ((point == "TOPLEFT") or (point == "TOPRIGHT")) then
			point = "TOP"
		else
			if ((point == "BOTTOMLEFT") or (point == "BOTTOMRIGHT")) then
				point = "BOTTOM"
			else
				if ((point == "LEFT") or (point == "RIGHT")) then
					point = "CENTER"
				end
			end
		end
		Comergy_Settings.X = 0
		Comergy_Settings.Point = point
		ComergyRestorePosition()
	end)
	tinsert(clickables, b)

	b = CreateFrame("Button", nil, ComergyOptGeneralFrame, "OptionsButtonTemplate")
	b:SetText(COMERGY_VCENTER)
	b:SetWidth(110)
	b:SetHeight(30)
	b:SetPoint("TOPLEFT", 160, -130)
	b:SetScript("OnClick", function()
		local point = ComergyMainFrame:GetPoint(1)
		if ((point == "TOPLEFT") or (point == "BOTTOMLEFT")) then
			point = "LEFT"
		else
			if ((point == "TOPRIGHT") or (point == "BOTTOMRIGHT")) then
				point = "RIGHT"
			else
				if ((point == "TOP") or (point == "BOTTOM")) then
					point = "CENTER"
				end
			end
		end
		Comergy_Settings.Y = 0
		Comergy_Settings.Point = point
		ComergyRestorePosition()
	end)
	tinsert(clickables, b)

	CreateCheckButton("SoundEnergy1", ComergyOptEnergyFrame, 80, -60)
	CreateCheckButton("SoundEnergy2", ComergyOptEnergyFrame, 80, -90)
	CreateCheckButton("SoundEnergy3", ComergyOptEnergyFrame, 80, -120)
	CreateCheckButton("SoundEnergy4", ComergyOptEnergyFrame, 80, -150)
	CreateCheckButton("SoundEnergy5", ComergyOptEnergyFrame, 80, -180)
	CreateCheckButton("SplitEnergy1", ComergyOptEnergyFrame, 130, -60)
	CreateCheckButton("SplitEnergy2", ComergyOptEnergyFrame, 130, -90)
	CreateCheckButton("SplitEnergy3", ComergyOptEnergyFrame, 130, -120)
	CreateCheckButton("SplitEnergy4", ComergyOptEnergyFrame, 130, -150)

	CreateCheckButton("EnergyBGFlash", ComergyOptEnergyFrame, 20, -245)
	CreateCheckButton("EnergyText", ComergyOptEnergyFrame, 20, -265)
	CreateCheckButton("UnifiedEnergyColor", ComergyOptEnergyFrame, 120, -265)
	CreateCheckButton("EnergyFlash", ComergyOptEnergyFrame, 40, -310)

	CreateCheckButton("ShowPlayerHealthBar", ComergyOptEnergyFrame, 20, -345)

	CreateCheckButton("SoundCombo1", ComergyOptComboFrame, 100, -60)
	CreateCheckButton("SoundCombo2", ComergyOptComboFrame, 100, -90)
	CreateCheckButton("SoundCombo3", ComergyOptComboFrame, 100, -120)
	CreateCheckButton("SoundCombo4", ComergyOptComboFrame, 100, -150)
	CreateCheckButton("SoundCombo5", ComergyOptComboFrame, 100, -180)

	CreateCheckButton("ComboText", ComergyOptComboFrame, 20, -265)
	CreateCheckButton("UnifiedComboColor", ComergyOptComboFrame, 20, -285)
	CreateCheckButton("ComboFlash", ComergyOptComboFrame, 20, -305)

	CreateCheckButton("ShowTargetHealthBar", ComergyOptComboFrame, 20, -345)

	CreateEditBox("EnergyThreshold1", ComergyOptEnergyFrame, 30, -53)
	CreateEditBox("EnergyThreshold2", ComergyOptEnergyFrame, 30, -83)
	CreateEditBox("EnergyThreshold3", ComergyOptEnergyFrame, 30, -113)
	CreateEditBox("EnergyThreshold4", ComergyOptEnergyFrame, 30, -143)
	
	CreateColorButton("BGColorAlpha", ComergyOptGeneralFrame, 190, -210, true)
	CreateColorButton("TextColor", ComergyOptGeneralFrame, 190, -235, true)

	CreateColorButton("EnergyColor0", ComergyOptEnergyFrame, 170, -30, true)
	CreateColorButton("EnergyColor1", ComergyOptEnergyFrame, 170, -60, true)
	CreateColorButton("EnergyColor2", ComergyOptEnergyFrame, 170, -90, true)
	CreateColorButton("EnergyColor3", ComergyOptEnergyFrame, 170, -120, true)
	CreateColorButton("EnergyColor4", ComergyOptEnergyFrame, 170, -150, true)
	CreateColorButton("EnergyColor5", ComergyOptEnergyFrame, 170, -180, true)

	CreateColorButton("EnergyBGColorAlpha", ComergyOptEnergyFrame, 190, -215, true)
	CreateColorButton("EnergyFlashColor", ComergyOptEnergyFrame, 190, -310, true)

	CreateColorButton("ComboColor0", ComergyOptComboFrame, 150, -30, true)
	CreateColorButton("ComboColor1", ComergyOptComboFrame, 150, -60, true)
	CreateColorButton("ComboColor2", ComergyOptComboFrame, 150, -90, true)
	CreateColorButton("ComboColor3", ComergyOptComboFrame, 150, -120, true)
	CreateColorButton("ComboColor4", ComergyOptComboFrame, 150, -150, true)
	CreateColorButton("ComboColor5", ComergyOptComboFrame, 150, -180, true)

	ComergyOptTab1:SetText(COMERGY_GENERAL)
	ComergyOptTab2:SetText(COMERGY_ENERGY)
	ComergyOptTab3:SetText(COMERGY_COMBO)
	ComergyOptTab1:Show()
	ComergyOptTab2:Show()
	ComergyOptTab3:Show()

	ComergyOptEnergyTextSound:SetText(COMERGY_TEXT_SOUND)
	ComergyOptEnergyTextSplit:SetText(COMERGY_TEXT_SPLIT)
	ComergyOptEnergyTextColor:SetText(COMERGY_TEXT_COLOR)
	ComergyOptEnergyTextFlash:SetText(COMERGY_TEXT_FLASH)
	ComergyOptComboTextSound:SetText(COMERGY_TEXT_SOUND)
	ComergyOptComboTextColor:SetText(COMERGY_TEXT_COLOR)

	local tdd = CreateFrame("Frame", "ComergyTextureDropdown", ComergyOptGeneralFrame, "UIDropDownMenuTemplate")
	ComergyTextureDropdownMiddle:SetWidth(60)
	tdd:SetPoint("TOPLEFT", 190, -260)

	ComergyTextureDropdownButton:SetScript("OnClick", function()
		if (DropDownList1:IsShown()) then
			DropDownList1:Hide()
		else
			local texturesList = {}
			for i = 1, #(ComergyBarTextures) do
				tinsert(texturesList,
					{ text = ComergyBarTextures[i][1], func = function() ChooseTexture(i) end, checked = false })
			end
			texturesList[Comergy_Settings.BarTexture].checked = true
			EasyMenu(texturesList, ComergyTextureDropdown, ComergyTextureDropdown, 0 , 0, nil)
			ToggleDropDownMenu(1, nil, ComergyTextureDropdown, ComergyTextureDropdown, 0, 0, texturesList)
			DropDownList1:Show()
		end
	end)
	ComergyOptGeneralTextTexture:SetJustifyH("RIGHT")
	ComergyOptGeneralTextTexture:SetPoint("BOTTOMRIGHT", ComergyTextureDropdownButton, "BOTTOMLEFT", -55, 0)
	ComergyOptGeneralTextTexture:SetPoint("TOPLEFT", ComergyTextureDropdownButton, "TOPLEFT", -135, 0)
	ComergyOptGeneralTextTexture:SetText(COMERGY_TEXTURE)
	tinsert(clickables, tdd)
	tinsert(clickables, ComergyTextureDropdownButton)

	tdd = CreateFrame("Frame", "ComergyTextDropdown", ComergyOptGeneralFrame, "UIDropDownMenuTemplate")
	ComergyTextDropdownMiddle:SetWidth(70)
	tdd:SetPoint("TOPLEFT", 180, -290)

	ComergyTextDropdownButton:SetScript("OnClick", function()
		if (DropDownList1:IsShown()) then
			DropDownList1:Hide()
		else
			local fontsList = {}
			for i = 1, #(ComergyTextFonts) do
				tinsert(fontsList,
					{ text = ComergyTextFonts[i][1], func = function() ChooseFont(i) end, checked = false })
			end
			fontsList[Comergy_Settings.TextFont].checked = true
			EasyMenu(fontsList, ComergyTextDropdown, ComergyTextDropdown, 0 , 0, nil)
			ToggleDropDownMenu(1, nil, ComergyTextDropdown, ComergyTextDropdown, 0, 0, fontsList)
			DropDownList1:Show()
		end
	end)
	ComergyOptGeneralTextText:SetJustifyH("RIGHT")
	ComergyOptGeneralTextText:SetPoint("BOTTOMRIGHT", ComergyTextDropdownButton, "BOTTOMLEFT", -65, 0)
	ComergyOptGeneralTextText:SetPoint("TOPLEFT", ComergyTextDropdownButton, "TOPLEFT", -145, 0)
	ComergyOptGeneralTextText:SetText(COMERGY_FONT)
	tinsert(clickables, tdd)
	tinsert(clickables, ComergyTextDropdownButton)

	tinsert(clickables, ComergyOptTab1)
	tinsert(clickables, ComergyOptTab2)
	tinsert(clickables, ComergyOptTab3)
	SetClickables()

	ComergyOptReadSettings()

	ComergyOptTabOnClick(1)

	ComergyOptFrame:Hide()
end

function ComergyOptToggle()
	if (ComergyOptFrame:IsShown()) then
		ComergyOptFrame:Hide()
	else
		ComergyOptReadSettings()
		ComergyOptFrame:Show()
	end
end

function ComergyOptTabOnClick(id)
	PlaySound("GAMEGENERICBUTTONPRESS")
	local tab
	for i = 1, 3 do
		tab = getglobal("ComergyOptTab"..i)
		if (tab) then
			tab:UnlockHighlight()
		end
	end
	getglobal("ComergyOptTab"..id):LockHighlight()
	ComergyOptGeneralFrame:Hide()
	ComergyOptEnergyFrame:Hide()
	ComergyOptComboFrame:Hide()
	if (id == 1) then
		ComergyOptGeneralFrame:Show()
	elseif (id == 2) then
		ComergyOptEnergyFrame:Show()
	elseif (id == 3) then
		ComergyOptComboFrame:Show()
	end
end

function ComergyOptEditBoxOnTextChanged(self)
	local _, _, name = string.find(self:GetName(), "ComergyOptEditBox(.+)")
	if (name) then
		if ((self:GetNumber() > 0) and (self:GetNumber() < UnitManaMax("player"))) then
			Comergy_Settings[name] = self:GetNumber()
		else
			self:SetNumber(Comergy_Settings[name])
		end
	else
		_, _, name = string.find(self:GetName(), "ComergyOptSlider(.+)")
		if (name) then
			local parent = self:GetParent()
			local min, max = parent:GetMinMaxValues()
			local value = self:GetNumber()
			if ((value >= min) and (value <= max)) then
				parent:SetValue(value)
			else
				self:SetText(parent:GetValue())
			end
		else
			_, _, name = string.find(self:GetName(), "ComergyOptColor(.+)")
			if (name) then
				local color = StringToColor(self:GetText())
				if (color) then
					local parent = self:GetParent()
					local _, _, settingName = string.find(parent:GetName(), "ComergyOptColor(.+)")
					parent:GetNormalTexture():SetVertexColor(color.r, color.g, color.b)
					Comergy_Settings[settingName][1] = color.r
					Comergy_Settings[settingName][2] = color.g
					Comergy_Settings[settingName][3] = color.b
				else
					Text()
				end
			end
		end
	end
	ComergyOnConfigChange()
end

function ClearEditBoxFocus()
	for i = 1, #(editBoxes) do
		editBoxes[i]:ClearFocus()
	end
end