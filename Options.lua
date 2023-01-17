local ADDON_NAME, Core = ...

--<
local UI = Core.UI
local utils = Core.utils
local SM = Core.SM
local L = Core.L
-->

local displayInfo = {
	["tab-container"] = {c = {r=0, g=0, b=0, a=0.3}},
	["toolbar"] = {c = {r=0, g=0, b=0, a=0.2}},
	["chatframe"] = {c = {r=0, g=0, b=0, a=0.5}},
	["title-bar"] = {c = {r=0, g=0, b=0, a=0.1}},
}

local cfg = {
	Version = false,
	LastHistoryCleanUp = false,
	BGOpacity = .70,
	Docked = true,
	BracketedNames = true,
	StripColours = true,
	UILayout = {},
	BodyLayout = {},
	HistoryExpiry = 14,
	CloseOnESC = true,
	KeepMinimized = true,
	ChatOverrideEnabled = true,
	PartyEnabled = false,
	GuildEnabled = false,
	NearbyChatEnabled = false,
	TextSize = 13,
	TextFont = "",
	TextOutline = false,
	Sessions = {},
	DisplayInfo = displayInfo,
	Preferences = {}
}



Core.defaultConfig = cfg


local contextMenu
local whatIsNew


--[[ QuickOptions Context Menu ]]

local function setExpiry (info)
	SESMSG_Profile["HistoryExpiry"] = info.value
end


local function checkExpiry (info)
	return SESMSG_Profile["HistoryExpiry"] == info.value
end


local function setOpacity (info)
	for i, frame in ipairs(UI.frames) do
		frame.BG:SetAlpha(info.value)
	end
	SESMSG_Profile["BGOpacity"] = info.value
end


local function checkOpacity (info)
	return info.value == SESMSG_Profile["BGOpacity"]
end


local function nearbyFilter (self, event, ...)
	if Core.db.NearbyChatEnabled then
		return true
	else return false, ...
	end
end
local function guildFilter (...)
	if Core.db.GuildEnabled then
		return true
	else return false, ...
	end
end


local function toggle_PartyChat (byUser)
	if Core.db.PartyEnabled then
		FrameUtil.RegisterFrameForEvents(UI, SM.partyEvents)
		
		if byUser and IsInGroup(LE_PARTY_CATEGORY_HOME) then
			SM.CreateCustom("Party", "PARTY")
		end
	else
		FrameUtil.UnregisterFrameForEvents(UI, SM.partyEvents)
		SM:CloseIfActive("PARTY")
	end
end


local function toggle_GuildChat (byUser)
	if SESMSG_Profile["GuildEnabled"] and IsInGuild() then
		UI:RegisterEvent("CHAT_MSG_GUILD")
		ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", guildFilter)
		if byUser then
			utils.SMPrint("Now taking over for Guild messages")
			SM.CreateCustom("Guild", "GUILD")
		end
	else
		UI:UnregisterEvent("CHAT_MSG_GUILD")
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_GUILD", guildFilter)
		SM:CloseIfActive("GUILD")
	end
end


local function toggle_NearbyChat (byUser)
	if Core.db.NearbyChatEnabled then
		FrameUtil.RegisterFrameForEvents(UI, SM.nearbyEvents)

		ChatFrame_AddMessageEventFilter("CHAT_MSG_EMOTE", nearbyFilter)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_TEXT_EMOTE", nearbyFilter)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", nearbyFilter)
		
		if byUser then
			SM.CreateCustom("Nearby", "EMOTE", "SAY")
			utils.SMPrint("Now taking over for Say and Emote messages")
		end
	else
		FrameUtil.UnregisterFrameForEvents(UI, SM.nearbyEvents)

		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_EMOTE", nearbyFilter)
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_TEXT_EMOTE", nearbyFilter)
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SAY", nearbyFilter)
		
		SM:CloseIfActive("Nearby")
	end
end


local function toggle_BlizzardKeyBindingFrame ()
	SettingsPanel:Open()
	-- to do: taint issue here
	
	--SettingsPanel:SelectCategory(SettingsPanel.keybindingsCategory)
end


local function toggle_BlizzardOptionsFrame ()
	SettingsPanel:Open()
	SettingsPanel:SelectCategory(Core.settingsCategory)
end


local function toggle_ChatOverride ()
	if InCombatLockdown() then
		return
	end
	SetOverrideBinding(UI.main, true, GetBindingKey("OPENCHAT"), Core.db.ChatOverrideEnabled and "SMChatOverride" or nil)
end


local function toggle_CloseOnESCPressed ()
	if SESMSG_Profile["CloseOnESC"] then
		table.insert(UISpecialFrames, UI.main:GetName())

	else
		for i, frameName in ipairs(UISpecialFrames) do
			if frameName == UI.main:GetName() then
				table.remove(UISpecialFrames, i)
			end
		end
	end
end


local execute = {
	["CloseOnESC"] = toggle_CloseOnESCPressed,
	["ChatOverrideEnabled"] = toggle_ChatOverride,
	["NearbyChatEnabled"] = toggle_NearbyChat,
	["PartyEnabled"] = toggle_PartyChat,
	["GuildEnabled"] = toggle_GuildChat,
}

local function context_changeSetting (info)
	local setting = info.value
	local func = execute[setting]
	Core.db[setting] = not Core.db[setting]
	
	if func then func(true) end
end


local function context_isChecked (info)
	return Core.db[info.value]
end


local function createContextMenu ()
	local titleGradient = "|cFF417dc1Sess|r|cFF2effebions|r |cFFf28500Mess|r|cFFeb2effenger|r"
	contextMenu = {
		{text=titleGradient.." v".. Core.VERSION, isTitle=true, notCheckable=true},
		{text="|cFF417dc1".. L["What's new?"].. "|r", notCheckable=true, keepShownOnClick=true, func=function() utils.SMPrint(whatIsNew) end},
		{text=L["More options"], notCheckable=true, func=toggle_BlizzardOptionsFrame},
		{text=[[|TInterface\COMMON\UI-TooltipDivider:8:144|t]], notClickable=true, notCheckable=true},
		{text="Core", isTitle=true, notCheckable=true},
		{
			text="Close UI On ESC",
			value="CloseOnESC",
			checked=context_isChecked,
			func=context_changeSetting,
			keepShownOnClick=true,
			isNotRadio=true,
		},
		{
			text="Keep Minimized",
			value="KeepMinimized",
			checked=context_isChecked,
			func=context_changeSetting,
			keepShownOnClick=true,
			isNotRadio=true,
			tooltipTitle="Keep Minimized",
			tooltipText="Prevents the main UI from popping up when receiving whispers",
			tooltipOnButton=true,
		},
		{
			text="Enable Chat Override",
			value="ChatOverrideEnabled",
			checked=context_isChecked,
			func=context_changeSetting,
			keepShownOnClick=true,
			isNotRadio=true,
			tooltipTitle="OpenChat Override",
			tooltipText="Pressing the OpenChat key (default <ENTER>) will instead focus SM when the UI is shown.",
			tooltipOnButton=true,
		},
		{
			text="Set Keybinds",
			notCheckable=true,
			func=toggle_BlizzardKeyBindingFrame,
		},
		{
			text=L["Edit appearance"],
			notCheckable=true,
			func=Core.Editmode.SetupScripts,
		},
		{text=[[|TInterface\COMMON\UI-TooltipDivider:8:144|t]], notClickable=true, notCheckable=true},
		{text="History", isTitle=true, notCheckable=true},
		{
			text="Open History Viewer",
			notCheckable=true,
			disabled=true,
			func=Core.History.Open,
		},
		{
			text= "History Expiry",
			hasArrow=true,
			disabled=true,
			notCheckable=true,
			keepShownOnClick=true,
			menuList={
				{text="Disabled", value=0, checked=checkExpiry, func=setExpiry},
				{text="14 Days", value=14, checked=checkExpiry, func=setExpiry},
				{text="1 Month", value=30, checked=checkExpiry, func=setExpiry},
				{text="2 Months", value=60, checked=checkExpiry, func=setExpiry},
				{text="4 Months", value=120, checked=checkExpiry, func=setExpiry},
			}
		},
		{text="Cancel", notCheckable=true},
	}
	
end

function Core.ShowOptions ()
	local xOffset = UI.leftSide and 35 or -180
	EasyMenu(contextMenu, UI.floatingMenu, "cursor", xOffset, 10, "MENU")
end

--[[]]

--[[ Setup / Init ]]




function Core.IsTypeEnabled (ctype)
	if ctype == "SAY" or ctype == "EMOTE" or ctype == "TEXT_EMOTE" then
		return Core.db.NearbyChatEnabled
		
	elseif ctype == "PARTY" or ctype == "PARTY_LEADER" then
		return Core.db.PartyEnabled
		
	elseif ctype == "GUILD" and IsInGuild() then
		return Core.db.GuildEnabled
	else
		return false
	end
end


local function setFramePosition (frame, setting)
	local layout = Core.db[setting]
	frame:ClearAllPoints()
	
	if not next(layout) then
		frame:SetPoint("CENTER")
		utils.SaveFramePosition(frame, setting)
		return
	end

	frame:SetPoint(layout.point, UIParent, layout.rel, layout.x, layout.y)
end


local function setFrameSize (frame, setting)
	local layout = Core.db[setting]
	
	if not next(layout) or not layout.width then
		frame:SetSize(300, UI:GetHeight())
		layout.width, layout.height = frame:GetSize()
		return 
	end
	
	frame:SetSize(layout.width, layout.height)
end


function Core.LoadPreferences ()
	createContextMenu()
	
	for i, frame in ipairs(UI.frames) do
		for col, val in pairs(SESMSG_Profile["DisplayInfo"][frame.info.name]["c"]) do
			frame.info.c[col] = val
		end
		
		local c = frame.info.c
		frame.BG:SetColorTexture(c.r, c.g, c.b, c.a)
	end

	setFramePosition(UI, "UILayout")
	
	if Core.db.Docked then
		UI.dockMode = true
		UI.titleBar.dockToggle:SetEnabled(false)
		UI.main:ClearAllPoints()
		UI.main:SetPoint("TOPLEFT", UI.leftFrame, "TOPRIGHT")
	else
		UI.dockMode = false
		setFramePosition(UI.main, "BodyLayout")
	end
	
	setFrameSize(UI.main, "BodyLayout")
	UI:SetAnchor()
	
	UI.editBox:SetWidth(UI.lowerFrame:GetWidth())
	toggle_CloseOnESCPressed()
	SM:SetPreferences()
	
	for i=1, NUM_CHAT_WINDOWS do
		local chatFrame = _G["ChatFrame".. tostring(i)]

		if GetChatWindowInfo(i) ~= "" then
			FrameUtil.UnregisterFrameForEvents(chatFrame, ChatTypeGroup["WHISPER"])
			--FrameUtil.UnregisterFrameForEvents(chatFrame, ChatTypeGroup["BN_WHISPER"])
		end
	end
	
	ChatTypeInfo["WHISPER"].sticky = 0
	ChatTypeInfo["BN_WHISPER"].sticky = 0
	
end

-- will clean this up later 


--[[Floating Options Init]]

local types = {
	"INSTANCE", "PARTY", "RAID",
	"SAY", "EMOTES", "GUILD",
}

local prefDescription = {
	tsCustomColour="Use custom colour for timestamps",
	tsEnabled="Enable timestamps",
	nameColouredByClass="Colourise names by class",
	textCustomColour="Use custom colour for my text",
}

local function FF_Close (self)
	local parent = self:GetParent()
	
	parent.editing = false
	parent.convo = false
	parent.delete:Hide()
	parent.title:SetText("Start a Conversation")
	parent.confirm:SetText("Go!")
	parent:ClearAllPoints()
	parent:Hide()
end


function Core.FloatingOptions_Init ()
	local self = UI
	Core.CreateSuggestionFrame()
	
	local floatingFrame = CreateFrame("Frame", nil, self, "BackdropTemplate")
	floatingFrame.typeSelection = {}
	floatingFrame.prefSelection = {}
	floatingFrame:SetClampedToScreen(true)
	floatingFrame.title = floatingFrame:CreateFontString()
	floatingFrame.title:SetFontObject("QuestFont_Outline_Huge")
	floatingFrame.title:SetPoint("TOP", 0, -5)
	floatingFrame.title:SetText(L["Start a conversation"])
	
	floatingFrame.searchBar = CreateFrame("EditBox", nil, floatingFrame, "SearchBoxTemplate")
	floatingFrame.searchBar:SetPoint("TOP", 0, -30)
	floatingFrame.searchBar:SetSize(132, 24)
	floatingFrame.searchBar.Instructions:SetText("Search player...")
	floatingFrame.searchBar:SetAutoFocus(true)
	floatingFrame:SetSize(250, 330)
	floatingFrame:SetPoint("LEFT", self, "RIGHT")
	floatingFrame:SetBackdrop({
		bgFile=[[Interface\DialogFrame\UI-DialogBox-Background-Dark]],
		edgeFile=[[Interface\GLUES\COMMON\TextPanel-Border]],
		edgeSize=8,
	})
	floatingFrame.subTitle = floatingFrame:CreateFontString()
	floatingFrame.subTitle:SetFontObject("GameFontWhite")
	floatingFrame.subTitle:SetPoint("TOP", 0, -60)
	--floatingFrame.subTitle:SetText("Include messages from:  (NYI)")
	floatingFrame:SetFrameStrata("DIALOG")
	
	floatingFrame.close = CreateFrame("Button", nil, floatingFrame)
	floatingFrame.close:SetPoint("TOPRIGHT", 6, 6)
	floatingFrame.close:SetSize(16, 16)
	floatingFrame.close:SetNormalTexture([[Interface\FriendsFrame\ClearBroadcastIcon]])
	floatingFrame.close:SetScript("OnClick", FF_Close)
	
	floatingFrame.delete = CreateFrame("Button", nil, floatingFrame, "UIPanelButtonTemplate")
	floatingFrame.delete:SetText("Delete")
	floatingFrame.delete:SetPoint("BOTTOMRIGHT", -2, 2)
	floatingFrame.delete:SetWidth(60)
	floatingFrame.delete:SetScript("OnClick", function(this) floatingFrame.sessionConvo:Deactivate() FF_Close(this) end)
	floatingFrame.delete:Hide()
	
	floatingFrame.confirm = CreateFrame("Button", nil, floatingFrame, "UIPanelButtonTemplate")
	floatingFrame.confirm:SetText("Go!")
	floatingFrame.confirm:SetPoint("BOTTOM", 0, 10)
	floatingFrame.confirm:SetScript("OnClick", function(this)
		if floatingFrame.editing then
			floatingFrame:Commit()
		else
			SM:MatchTargetName(floatingFrame.searchBar:GetText())
		end
		
		FF_Close(this)
	end)
	floatingFrame:Hide()
	
	floatingFrame.searchBar:HookScript("OnEnterPressed", function(this)
		if this:GetText() ~= "" then
			SM:MatchTargetName(this:GetText())
			UI.main:Show()
		end
		
		this:ClearFocus()
		
		this:GetParent():Hide()
	end)
	
	floatingFrame:SetScript("OnHide", function() Core.suggestionFrame:Detach() end)
	floatingFrame.searchBar:HookScript("OnEditFocusGained", function(this) this:SetAutoFocus(true) Core.suggestionFrame:Attach(this) end)
	floatingFrame.searchBar:HookScript("OnHide", function(this) this:SetText("") end)
	floatingFrame.searchBar:SetScript("OnEscapePressed", function(this) this:SetAutoFocus(false) this:ClearFocus() end)
	--floatingFrame.searchBar:HookScript("OnEditFocusLost", function(this) if Core.suggestionFrame:IsMouseOver() then return end Core.suggestionFrame:Detach() end)

	floatingFrame.searchBar:HookScript("OnTextChanged", function(this, byUser)
		if not byUser then
			return
		end
		
		local text = utils.capitalize(this:GetText())

		Core.suggestionFrame:ClearList()
		
		if text == "" then
			return Core.suggestionFrame:Hide() 
		end	
		
		local results = GetAutoCompleteResults(text, 4, this:GetCursorPosition(), true, AUTOCOMPLETE_FLAG_ONLINE, AUTOCOMPLETE_FLAG_NONE)
		
		if not next(results) then
			Core.suggestionFrame:Hide()
			return
		else
			Core.suggestionFrame:Show()
			
			for i, v in ipairs(results) do
				if Core.suggestionFrame:HasSpace() then
					Core.suggestionFrame:Add(Ambiguate(v.name, "none"), function() this:SetText(v.name) end)
				end
			end
		end
	end)
	--[[
	local row = ceil(100 / #types)
	for i, t in ipairs(types) do
		local b = CreateFrame("CheckButton", nil, floatingFrame, "SessionsCheckButtonTemplate")
		b:SetSize(24, 24)
		b.label:SetText(t)
		b.label:SetFontObject("SystemFont_Outline_Small")
		b:SetScript("OnHide", function(this) this:SetChecked(false) end)
		if (i % 2) == 1 then
			b:SetPoint("TOPLEFT", 30, (1-i) * row - 85)
		else 
			b:SetPoint("TOPLEFT", 140, (2-i) * row - 85)
		end
		floatingFrame.typeSelection[t] = b

	end
	]]
	local index = 0
	for pref, bool in pairs(SM.PRESET_PREFERENCES) do
		local b = CreateFrame("CheckButton", nil, floatingFrame, "SessionsCheckButtonTemplate")
		b:SetSize(16, 16)
		b.label:SetFontObject("SystemFont_Outline_Small")
		b.label:SetText(prefDescription[pref])
		b:SetPoint("TOPLEFT", 10, -100 - (index*17))
		floatingFrame.prefSelection[pref] = b
		index = index+1
	end
	
	floatingFrame.Open = function(self, convo)
		UI:Open()
		
		if convo then
			self.editing = true
			self.delete:Show()
			self.sessionConvo = convo
			self.title:SetText("Edit Conversation")
			self.confirm:SetText("OK")
			self:ClearAllPoints()
			
			self:SetPoint("CENTER", convo.tab)
			
			for sett, cb in pairs(self.typeSelection) do

			end
			for pref, cb in pairs(self.prefSelection) do
				cb:SetChecked(convo.preferences[pref])
			end
		else
			for pref, cb in pairs(self.prefSelection) do
				cb:SetChecked(SM.PRESET_PREFERENCES[pref])
			end
			
			self:ClearAllPoints()
			self:SetPoint("CENTER", UI.leftFrame)
		end
		
		if not self:IsShown() then
			self:Show()
		end
	end
	
	floatingFrame.Commit = function(self)
		if self.editing then
			SM.selected:UpdatePreferences(self.prefSelection)
		else
			
		end
		
		self.editing = false
	end
	
	self.floatingFrame = floatingFrame
end




--[[]]

--[[ Options Panel ]]

local options = CreateFrame("Frame", ADDON_NAME.."_SettingsFrame")
options.settings = {}
options.anchor = -15
local cat = Settings.RegisterCanvasLayoutCategory(options, "Sessions Messenger")
Settings.RegisterAddOnCategory(cat)
Core.settingsCategory = cat

function options:Commit (setting, value)
	SESMSG_Profile[setting] = value
end

function options:AdjustAnchor (widget)
	self.anchor = self.anchor - widget:GetHeight() - 10
end


local function addCheckButton (setting, desc)
	local cb = CreateFrame("CheckButton", nil, options, "SessionsCheckButtonTemplate")
	cb:SetScript("OnClick", function(this) SESMSG_Profile[setting] = this:GetChecked() SM:UpdateChatFont() end)
	cb.label:SetText(desc)
	cb:SetPoint("TOPLEFT", options, 15, options.anchor)
	cb:SetChecked(Core.db[setting])
	options.anchor = options.anchor - cb:GetHeight() - 5
	
	return cb
end

local function addSelection (setting, desc)
	local menu = CreateFrame("Button", nil, options)
	menu:SetNormalAtlas("charactercreate-customize-dropdownbox")
	menu:SetHighlightAtlas("charactercreate-customize-dropdownbox-hover")
	menu:SetNormalFontObject("GameFontNormal")
	menu:SetDisabledFontObject("GameFontDisable")
	menu:SetSize(240, 40)
	menu.description = menu:CreateFontString()
	menu.description:SetFontObject("GameFontNormal")
	menu.description:SetText(desc)
	menu.description:SetPoint("TOPLEFT", options, 15, options.anchor)
	menu:SetPoint("LEFT", menu.description, "LEFT", 150, 0)
	menu.popout = CreateFrame("ScrollFrame", nil, menu, "SessionsQuickListTemplate")
	menu.popout.items = {}
	menu.popout:SetFrameStrata("HIGH")
	menu.popout:SetPoint("TOPLEFT", menu, "BOTTOMLEFT", 10, 0)
	menu.popout:SetHitRectInsets(-20, -40, 0, 0)
	menu.popout:Hide()
	
	menu:SetScript("OnClick", function(this) this.popout:SetShown(not this.popout:IsShown()) end)
	menu.popout:SetScript("OnLeave", function(this) this:Hide() end)
	
	options:AdjustAnchor(menu)
	
	return menu
end

local function addSlider (setting, desc)
	local slider = CreateFrame("Slider", nil, options, "MinimalSliderTemplate")
	slider:SetMinMaxValues(10, 18)
	slider:SetValueStep(1)
	slider.description = slider:CreateFontString()
	slider.description:SetFontObject("GameFontNormal")
	slider.description:SetText(desc)
	slider.description:SetPoint("TOPLEFT", options, 15, options.anchor)
	
	slider.label = slider:CreateFontString()
	slider.label:SetFontObject("GameFontNormal")
	slider.label:SetPoint("RIGHT", slider, "LEFT", -10, 0)
	
	slider:SetPoint("LEFT", slider.description, "LEFT", 150, 0)
	slider:SetScript("OnValueChanged", function(this, val)
		if val == this.label:GetText() then return end
		this.label:SetText("(".. val.. ")")
		SESMSG_Profile[setting] = val
		SM:UpdateChatFont()
	end)
	
	slider:SetValue(Core.db[setting])
	options:AdjustAnchor(slider)
	
	return slider
end

options.sound = {}

options.display = {
	BGOpacity = {build=addSlider, desc="Background opacity:"},
}

options.text = {
	TextSize = {build=addSlider, desc="Chat text size:"},
	TextFont = {build=addSelection, desc="Chat text font:"},
	TextOutline = {build=addCheckButton, desc="Enable text outline"},
}


local function createFS (fObject, text)
	local fs = options:CreateFontString(nil, "ARTWORK", nil)
	fs:SetFontObject(fObject)
	fs:SetText(text)
	fs:SetPoint("TOPLEFT", options, 15, options.anchor)
	options:AdjustAnchor(fs)
	
	return fs
end

local drawn = false

function options:Init ()
	if drawn then return end

	self.mainTitle = self:CreateFontString(nil, "ARTWORK", nil)
	self.mainTitle:SetFontObject("GameFontNormalLarge")
	self.mainTitle:SetText(L["SM: My Settings"])
	self.mainTitle:SetPoint("TOPLEFT", self, 15, self.anchor)
	self:AdjustAnchor(self.mainTitle)

	self.title2 = createFS("GameFontWhite", "CHAT TEXT & FONT!")
	
	for setting, info in pairs(self.text) do
		self[setting] = info.build(setting, info.desc)
	end
	
	do --Add font list from LibSharedMedia
		local fauxDropDown = self["TextFont"]
		local function item_OnClick (btn)
			for i=1, #fauxDropDown.popout.items do
				fauxDropDown.popout.items[i]:UnlockHighlight()
			end
			btn:LockHighlight()
			local fontPath = btn.label:GetText()
			fauxDropDown:SetNormalFontObject(btn.label:GetFontObject())
			fauxDropDown:SetText(fontPath)
			fauxDropDown.popout:Hide()
			SESMSG_Profile["TextFont"] = fontPath
			SM:UpdateChatFont()
		end
		
		fauxDropDown:SetNormalFontObject(Core.ChatFont:GetFontObject())
		

		local index = 0
		for name, path in pairs(Core.LSM:HashTable("font")) do
			local fontObject = CreateFont("SM_Demo16_".. name)
			fontObject:SetFont(path, 16, "")
			
			if fontObject:GetFont() then
				local b = CreateFrame("Button", nil, fauxDropDown.popout.ListFrame, "SessionsQuickItemTemplate")
				fauxDropDown.popout.items[#fauxDropDown.popout.items+1] = b
				b:SetPoint("TOPLEFT", fauxDropDown.popout.ListFrame, "TOPLEFT", 2, -index * b:GetHeight())
				b.label:SetFontObject(fontObject)
				b:SetMouseMotionEnabled(false)
				b.label:SetText(name)
				b:SetScript("OnClick", item_OnClick)
				if Core.ChatFont:GetFont() == path then
					b:LockHighlight()
					fauxDropDown:SetText(name)
				end
				index = index+1
			else
				utils.AddError(string.format("Found an oddity with font %s (%s): Font skipped.", name, path))
			end
		end
	end
	
	drawn = true
end

SettingsPanel:HookScript("OnShow", function()
	if not drawn then
		options:Init()
	end
end)

whatIsNew =
([[Thank you for trying SM! Here's what's new in v%s:
- Improved show/hide logic for all UI elements
- UI will now change anchors dynamically (left/right side of screen)
- Lots of bug fixes and more to go
]]):format(Core.VERSION)


