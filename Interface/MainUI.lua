local ADDON_NAME, Core = ...

--<
local format, gsub, sub, upper, match = string.format, string.gsub, string.sub, string.upper, string.match
local UI, utils, SM, L = Core.UI, Core.utils, Core.SM, Core.L
-->


function UI.OnMouseWheelEvent (this, delta)
	local vs = math.ceil(this:GetVerticalScroll())

	if (vs == 0 and delta ~= -1) then
		return
	end
	
	UI.editBoxSlider:SetValue( (delta == -1 and vs + Core.LINE_HEIGHT) or (delta == 1 and vs - Core.LINE_HEIGHT) )
end


function UI:OnCursorEvent (y)
	local vs = math.ceil(self.editBoxScroller:GetVerticalScroll())

	if (vs + y - Core.LINE_HEIGHT + self.editBoxViewport) < 0 then
		self:SetSliderValues()
		self.editBoxSlider:SetValue(math.ceil((y * -1) - (self.editBoxViewport - Core.LINE_HEIGHT)))

	elseif (vs + y) > 0 then
		self.editBoxSlider:SetValue(y*-1)
	end
end


function UI.RefreshTabContainer ()
	local vs = floor(UI.tabWindow:GetVerticalScroll())
	local range = (#Core.orderedTabs * (Core.TAB_HEIGHT + Core.TAB_SPACING)) - UI.tabWindow:GetHeight()
	
	--UI.leftFrame.upArrow:SetShown(vs > 0)
	--UI.leftFrame.downArrow:SetShown((range > vs) and (range - vs > 20))
end


function UI:SetSliderValues ()
	local ebHeight = self.editBox:GetHeight()
	local viewport = self.editBoxViewport
	
	self.editBoxSlider:SetShown(ebHeight > viewport)
	self.editBoxSlider:SetMinMaxValues(0, ebHeight >= viewport and (ebHeight-viewport) or 0)
end


function UI:Toggle ()
	self:SetShown(not self:IsShown())
end


function UI:SetAnchor ()
	UI.leftSide = self:GetCenter() < (GetScreenWidth() / 2) and true or false
	
	if not UI.leftSide then
		self.leftFrame:ClearAllPoints()
		self.leftFrame:SetPoint("TOPRIGHT", self, "TOPLEFT")
		self.main:ClearAllPoints()
		self.main:SetPoint("TOPRIGHT", self, "TOPLEFT", -self.leftFrame:GetWidth(), 0)
	else
		self.leftFrame:ClearAllPoints()
		self.leftFrame:SetPoint("TOPLEFT", self, "TOPRIGHT")
		self.main:ClearAllPoints()
		self.main:SetPoint("TOPLEFT", self, "TOPRIGHT", self.leftFrame:GetWidth(), 0)
	end
end


function UI:OpenChat ()
	self:Show()

	if not self.leftFrame:IsShown() then
		self.leftFrame:Show()
		self.main:Show()
	end
	
	self.editBox:Show()
	if not IsPlayerMoving() then
		self.editBox:SetFocus()
	end
end


function UI:StopMoving ()
	self:StopMovingOrSizing()
	Core.utils.SaveFramePosition(self, "UILayout")
	self:SetAnchor()
end


function UI:Open (force)
	self:Show()
	self.leftFrame:Show()
	
	if force then	
		self.main:Show()
	end
end


local enableKB = function() UI.editBox:EnableKeyboard(true) end
function UI:FocusEditBoxFromKeybind ()	
	self.editBox:EnableKeyboard(false)
	self.editBox:SetFocus()
	C_Timer.After(0, enableKB)
end


function UI:UpdateHeader (session)
	local r, g, b = SM:GetSelectedRGB()
	local S = SM.selected

	self.title:SetText(S and S.title or "")
	self.title:SetTextColor(r, g, b)
	self.body:SetBackdropBorderColor(r, g, b)
	self.lowerFrame:SetBackdropBorderColor(r, g, b)
	self.lowerFrame.BG:SetGradient("HORIZONTAL", CreateColor(r*0.1,g*0.1,b*0.1, 0.8), CreateColor(0,0,0,1))
end


local function statusIcon_OnEvent (self)
	local status = (UnitIsAFK("player") and "Away") or (UnitIsDND("player") and "DND") or "Online"	
	self.tipTitle = "Appearing ".. status
	self:SetNormalTexture("Interface/FriendsFrame/StatusIcon-".. status)
end


local function tabContainer_OnMouseWheel (self, delta)
	local vs = math.floor(self:GetVerticalScroll())
	local range = self:GetVerticalScrollRange()
	local down = (delta == -1)

	if (down and (range <= 0 or vs > range)) or (not down and vs == 0) then 
		return
	end

	self:SetVerticalScroll(down and vs + Core.TAB_TOTALHEIGHT or vs - Core.TAB_TOTALHEIGHT)
	UI.RefreshTabContainer()
end


local function editBox_CharacterCounter (self)
	local num = self:GetNumLetters()
	
	if num == 0 then
		return
	end
	
	local paras = math.floor(num / 255)
	local currentPara = num % 255
	self.counter.number:SetText(currentPara.."/"..paras)
	self.counter:Show()
end


local function editBox_OnTextChanged (self, byUser)
	if (not byUser) or (self:GetText() == "") then
		return
	end

	local S = Core.SM.selected

	if time() >= S.typeInform_lastSent then
		ChatThrottleLib:SendAddonMessage("NORMAL", "SessionsMSGR", "TI01", "WHISPER", S.senderID)
		S.typeInform_lastSent = time()+7
	end
end


local function editBox_OnEditFocusGained (self)
	ACTIVE_CHAT_EDIT_BOX = self
	self:SetWidth(UI.lowerFrame:GetWidth()-27)
	UI.lowerFrame.BG:Show()
	UI.lowerFrame:SetBackdropBorderColor(Core.SM:GetSelectedRGB())
	self:AddOrRemoveOnTextHandler()
end


local function editBox_OnEditFocusLost (self)
	ACTIVE_CHAT_EDIT_BOX = nil
	Core.G_EditBox:SetAttribute("chatType", Core.G_ChatType)
	UI.lowerFrame.BG:Hide()
	UI.lowerFrame:SetBackdropBorderColor(1, 1, 1)
end


local function editBox_AddOrRemoveOnTextHandler (self)
	if Core.SM.selected and Core.SM.selected.isUsingSM then
		self:SetScript("OnTextChanged", editBox_OnTextChanged)
	else
		self:SetScript("OnTextChanged", nil)
	end
end


local function editBox_OnSizeChanged (self, w, h)
	if h <= UI.editBoxViewport then
		UI:SetSliderValues()
	end
end


local function editBox_OnTabPressed (self)
	if #Core.orderedTabs <= 1 then
		return
	end

	for N, S in pairs(SM.active) do
		if S.missedMessages > 0 then
			SM:Switch(S)
			return
		end
	end
	
	local current = SM.selected.tab.tabIndex
	local nextIndex = Core.orderedTabs[current+1] and current+1 or 1
	
	for N, S in pairs(SM.active) do
		if S.tab.tabIndex == nextIndex then
			SM:Switch(S)
			break
		end
	end
end


local function editBox_OnSpacePressed (self)
	local sample = self:GetText()

	if (sample:sub(1, 1) ~= "/") then
		return
	end
	
	local ctype = sample:sub(2, -2):lower()
	local text = gsub(sample, format("/%s ", ctype), "")
	
	if (ctype == "r" or ctype == "reply") and SM.lastWhisperTarget ~= nil then
		SM:Switch(SM.lastWhisperTarget)
		self:SetText(text)

	elseif ctype == "w" or ctype == "whisper" then
		if match(text, "%a") then
			local target = gsub(text, " ", "")
			self:SetText("")
			SM:MatchTargetName(target)
		end
		
	else
		ctype = (utils.any(ctype, "e", "em", "me", "emote")) and "EMOTE"
			or (ctype == "say" or ctype == "s") and "SAY"
			or (ctype == "p" or ctype == "party") and "PARTY"
			or (ctype == "g" or ctype == "guild") and "GUILD"
			
		if not Core.IsTypeEnabled(ctype) then
			return
		end

		local S = SM:Get(ctype)
		
		if not S then
			S = SM.CreateCustom(unpack(SM.preset[ctype]))
		end
		
		if not S:IsSelected() then
			self:SetText("")
			SM:Switch(S)
		end
		
		S.chatType = ctype
		
		if ctype == "SAY" or ctype == "EMOTE" then
			S:UpdateTitle()
		end
		
		self:SetText(sample:sub(#ctype+3, #sample))
	end

	self:SetTextColor(SM:GetSelectedRGB())
end


local function editBox_OnEnterPressed (self)
	local text = self:GetText()

	if sub(text, 1, 1) == "/" then
		Core.G_EditBox:SetText(text)
		ChatEdit_ParseText(Core.G_EditBox, 1)
		
	elseif self:HasFocus() and SM.selected ~= nil then
		SM:SendMessage(text)
	end
	
	UI:SetSliderValues()
	self:SetText("")
	self:ClearFocus()
end

local function editBox_OnKeyDown (self, key)
	if key == "/" and #self:GetText() == 0 then
		self:Hide()
		Core.SecureBox_Show()
	end
end


local function main_OnSizeChanged (self, width, height)
	if height < 230 and self.editBoxViewport ~= 28 then
		self.editBoxViewport = 2 * Core.LINE_HEIGHT
	elseif height > 230 and self.editBoxViewport ~= 42 then
		self.editBoxViewport = 3 * Core.LINE_HEIGHT
	else return
	end

	self.lowerFrame:SetHeight(self.editBoxViewport + 8)
end


local function main_StartMoving (self)
	UI.main:StartMoving()
end


local function main_StopMovingOrSizing (self)
	UI.main:StopMovingOrSizing()
	utils.SaveFramePosition(UI.main, "BodyLayout")
	
end


local function main_OnShow (self)
	if not InCombatLockdown() and Core.db.ChatOverrideEnabled then
		SetOverrideBinding(self, true, GetBindingKey("OPENCHAT"), "SMChatOverride")
	end
	
	if SM.selected then
		SM.selected:MarkAsRead()
	end
	
	for n, session in pairs(SM.active) do
		if session.isDM and session.missedMessages > 0 then
			session:StartGlowing()
		end
	end
end


local function main_OnHide (self)
	if not InCombatLockdown() then
		SetOverrideBinding(self, true, GetBindingKey("OPENCHAT"), nil)
	end
end

local function titleBar_OnDragStart (self, btn)
	if btn == "LeftButton" and UI.dockMode == true then
		UI:StartMoving()
	else
		UI.dockMode = false
		UI.titleBar.dockToggle:SetEnabled(true)
		main_StartMoving()
	end
end


local function titleBar_OnDragStop (self)
	if UI.dockMode == true then
		UI:StopMoving()
	else
		main_StopMovingOrSizing()
	end
end


local function createModule (displayName)
	local mod = CreateFrame("Frame", nil, self)
	mod.BG = mod:CreateTexture(nil, "BACKGROUND", nil)
	mod.BG:SetPoint("TOPLEFT", 2, -2)
	mod.BG:SetPoint("BOTTOMRIGHT", -2, 2)
	mod.info = {c = {r=0, g=0, b=0, a=1}, name=displayName}
end


local function drawUI ()
	local self = UI

	self:SetClampedToScreen(true)
	self:SetMovable(true)
	self:EnableMouse(true)
	self:RegisterForDrag("LeftButton")
	self:SetScript("OnDragStart", self.StartMoving)
	self:SetScript("OnDragStop", self.StopMoving)
	self:SetSize(26, 220)
	self:SetPoint("CENTER")
	self.BG = self:CreateTexture(nil, "BACKGROUND", nil)
	self.BG:SetPoint("TOPLEFT", 1, -2)
	self.BG:SetPoint("BOTTOMRIGHT", -1, 2)
	self.BG:SetTexture([[Interface\COMMON\ShadowOverlay-Top]])
	self.info = {c = {r=0, g=0, b=0, a=1}, name="toolbar"}
	
	self.minimizeBtn = CreateFrame("Button", nil, self)
	self.minimizeBtn:SetSize(32, 32)
	self.minimizeBtn:SetNormalAtlas("common-button-square-gray-up")
	self.minimizeBtn:SetPushedAtlas("common-button-square-gray-down")
	self.minimizeBtn:SetPoint("TOP", 0, -2)
	self.minimizeBtn.tx = self.minimizeBtn:CreateTexture(nil, "OVERLAY", nil)
	self.minimizeBtn.tx:SetSize(16, 16)
	self.minimizeBtn.tx:SetPoint("CENTER")
	self.minimizeBtn.tx:SetAlpha(0.7)
	self.minimizeBtn.tx:SetTexture([[Interface\CHATFRAME\UI-ChatWhisperIcon]])
	self.minimizeBtn.tx:SetVertexColor(0.2, 0.4, 0.8, 1)
	self.minimizeBtn:SetScript("OnClick", function(this) self.leftFrame:SetShown(not self.leftFrame:IsShown()) end)
	self.minimizeBtn.tipTitle = L["Conversations"]
	Core.utils.RegisterForTooltip(self.minimizeBtn)
	
	self.startBtn = CreateFrame("Button", nil, self)
	self.startBtn:SetSize(32, 32)
	self.startBtn:SetNormalAtlas("common-button-square-gray-up")
	self.startBtn:SetPushedAtlas("common-button-square-gray-down")
	self.startBtn:SetPoint("TOP", 0, -36)
	self.startBtn:SetScript("OnClick", function(this) self.floatingFrame:Open() end)
	self.startBtn.tx = self.startBtn:CreateTexture(nil, "OVERLAY", nil)
	self.startBtn.tx:SetSize(16, 16)
	self.startBtn.tx:SetPoint("CENTER")
	self.startBtn.tx:SetAlpha(0.7)
	self.startBtn.tx:SetTexture([[Interface\FriendsFrame\UI-Toast-ChatInviteIcon]])
	self.startBtn.tipTitle = L["Start a conversation"]
	Core.utils.RegisterForTooltip(self.startBtn)
	
	self.optionsBtn = CreateFrame("Button", nil, self)
	self.optionsBtn:SetSize(32, 32)
	self.optionsBtn:SetNormalAtlas("common-button-square-gray-up")
	self.optionsBtn:SetPushedAtlas("common-button-square-gray-down")
	self.optionsBtn:SetPoint("TOP", 0, -70)
	self.optionsBtn.tx = self.optionsBtn:CreateTexture(nil, "OVERLAY", nil)
	self.optionsBtn.tx:SetSize(24, 24)
	self.optionsBtn.tx:SetPoint("CENTER")
	self.optionsBtn.tx:SetAlpha(0.7)
	self.optionsBtn.tx:SetTexture([[Interface\Worldmap\Gear_64Grey]])
	self.optionsBtn:SetScript("OnClick", function() Core.ShowOptions() end)
	self.optionsBtn.tipTitle = L["Quick options"]
	Core.utils.RegisterForTooltip(self.optionsBtn)
	
	
	self.leftFrame = CreateFrame("Frame", nil, self, "BackdropTemplate")
	self.leftFrame:SetClampedToScreen(true)
	self.leftFrame:EnableMouse(true)
	self.leftFrame:SetPoint("TOPLEFT", self, "TOPRIGHT")
	self.leftFrame:SetPoint("BOTTOMLEFT", self, "BOTTOMRIGHT")
	self.leftFrame:SetFrameStrata("HIGH")
	self.leftFrame:SetSize(130, self:GetHeight())
	self.leftFrame.BG = self.leftFrame:CreateTexture(nil, "BACKGROUND", nil)
	self.leftFrame.BG:SetPoint("TOPRIGHT", -2, -2)
	self.leftFrame.BG:SetPoint("BOTTOMLEFT", 2, 2)
	--self.leftFrame.BG:SetTexture([[Interface\COMMON\SHadowOverlay-Corner]])
	self.leftFrame.BG:SetAtlas("collections-background-shadow-large")
	self.leftFrame:Hide()
	self.leftFrame:SetScript("OnHide", function(this) self.main:Hide() end)
	self.leftFrame.info = {c = {r=0, g=0, b=0, a=1}, name="tab-container"}
	self.leftFrame:SetBackdrop({
		edgeFile=[[Interface\FriendsFrame\UI-Toast-Border]],
		edgeSize=8,
	})
	
	
	self.tabWindow = CreateFrame("ScrollFrame", nil, self.leftFrame)
	self.tabWindow:SetPoint("TOPLEFT", 0, -3)
	self.tabWindow:SetPoint("BOTTOMRIGHT", 0, 3)
	self.tabWindow:EnableMouseWheel(true)
	self.tabWindow:SetScript("OnMouseWheel", tabContainer_OnMouseWheel)

	self.tabContainer = CreateFrame("Frame", nil, self.tabWindow)
	self.tabContainer:SetSize(130, 1)
	self.tabContainer:SetAllPoints()
	self.tabWindow:SetScrollChild(self.tabContainer)
	
	self.main = CreateFrame("Frame", ADDON_NAME.."MainBody", self, "BackdropTemplate")
	self.main:Hide()
	self.main:SetClampedToScreen(true)
	self.main:SetDontSavePosition(true)
	self.main:SetResizeBounds(300, self:GetHeight(), 0, 0)
	self.main:SetSize(300, self:GetHeight())
	self.main:SetPoint("TOPLEFT", self.leftFrame, "TOPRIGHT")
	self.main:SetResizable(true)
	self.main:SetMovable(true)
	self.main.BG = self.main:CreateTexture(nil, "BACKGROUND", nil)
	self.main.BG:SetAllPoints()
	self.main:SetScript("OnHide", main_OnHide)
	self.main:SetScript("OnShow", main_OnShow)
	

	
	self.titleBar = CreateFrame("Frame", nil, self.main)
	self.titleBar:SetPoint("TOPLEFT")
	self.titleBar:SetPoint("TOPRIGHT")
	self.titleBar:SetSize(self.main:GetWidth(), 20)
	self.titleBar.BG = self.titleBar:CreateTexture(nil, "BACKGROUND", nil)
	self.titleBar.BG:SetPoint("TOPRIGHT", -1, 0)
	self.titleBar.BG:SetPoint("BOTTOMLEFT", 2, 0)
	self.titleBar.BG:SetColorTexture(0, 0, 0, 0.1)
	self.titleBar.info = {c = {r=0, g=0, b=0, a=1}, name="title-bar"}
	self.titleBar:EnableMouse(true)
	self.titleBar:RegisterForDrag("LeftButton", "RightButton")
	self.titleBar:SetScript("OnDragStart", titleBar_OnDragStart)
	self.titleBar:SetScript("OnDragStop", titleBar_OnDragStop)

	self.title = self.titleBar:CreateFontString()
	self.title:SetFontObject("QuestFont_Outline_Huge")
	self.title:SetPoint("LEFT", self.titleBar, "LEFT", 5, -1)
	
	self.titleBar.hideBtn = CreateFrame("Button", nil, self.titleBar)
	self.titleBar.hideBtn:SetNormalAtlas("UI-Panel-HideButton-Up")
	self.titleBar.hideBtn:SetPushedAtlas("UI-Panel-HideButton-Down")
	self.titleBar.hideBtn:SetSize(24, 24)
	self.titleBar.hideBtn:SetAlpha(0.7)
	self.titleBar.hideBtn:SetPoint("RIGHT", 4, 0)
	self.titleBar.hideBtn:SetScript("OnClick", function(this) self.main:Hide() end)
	self.titleBar.hideBtn.tipTitle = L["Minimize"]
	Core.utils.RegisterForTooltip(self.titleBar.hideBtn)
	
	self.titleBar.dockToggle = CreateFrame("Button", nil, self.titleBar)
	--self.titleBar.dockToggle:SetNormalAtlas("UI-RefreshButton")
	self.titleBar.dockToggle:SetNormalTexture([[Interface\BUTTONS\UI-Panel-SmallerButton-Up]])
	self.titleBar.dockToggle:SetPushedTexture([[Interface\BUTTONS\UI-Panel-SmallerButton-Down]])
	self.titleBar.dockToggle:SetDisabledTexture([[Interface\BUTTONS\UI-Panel-SmallerButton-Disabled]])
	--self.titleBar.dockToggle:SetEnabled(false)
	self.titleBar.dockToggle:SetMotionScriptsWhileDisabled(true)
	self.titleBar.dockToggle:SetAlpha(0.7)
	self.titleBar.dockToggle:SetSize(24, 24)
	self.titleBar.dockToggle:SetPoint("RIGHT", -15, 0)
	self.titleBar.dockToggle.tipTitle = L["Reattach chatframe"]
	self.titleBar.dockToggle.tipBody = L["Tip: drag the title bar with a right-click to detach"]
	Core.utils.RegisterForTooltip(self.titleBar.dockToggle)
	self.titleBar.dockToggle:SetScript("OnClick", function(this)
		self.main:ClearAllPoints()
		self.main:SetPoint("TOPLEFT", self.leftFrame, "TOPRIGHT")
		self.main:SetSize(300, self:GetHeight())
		self.dockMode = true
		this:SetEnabled(false)
		utils.SaveFramePosition(self.main, "BodyLayout")
		Core.db.BodyLayout.width, Core.db.BodyLayout.height = self.main:GetSize()
	end)
	
	self.lowerFrame = CreateFrame("Frame", nil, self.main, "BackdropTemplate")
	self.lowerFrame:SetHeight(2*Core.LINE_HEIGHT + 8)
	self.lowerFrame:SetPoint("BOTTOMRIGHT")
	self.lowerFrame:SetPoint("BOTTOMLEFT")
	self.lowerFrame.BG = self.lowerFrame:CreateTexture(nil, "BACKGROUND")
	self.lowerFrame.BG:SetPoint("TOPLEFT", 2, -2)
	self.lowerFrame.BG:SetPoint("BOTTOMRIGHT", -2, 2)
	self.lowerFrame.BG:SetColorTexture(1, 1, 1)
	self.lowerFrame.BG:SetGradient("HORIZONTAL", Core.colours.black, Core.colours.black)
	self.lowerFrame.BG:Hide()
	self.lowerFrame:SetBackdrop({
		edgeFile=[[Interface\FriendsFrame\UI-Toast-Border]],
		--edgeFile=[[Interface\FriendsFrame\UI-Toast-Border]],
		edgeSize=8,
		--insets={left=2, right=2, top=2, bottom=2}
	})	
	
	self.editBoxViewport = Core.LINE_HEIGHT*2
	
	self.editBoxScroller = CreateFrame("ScrollFrame", nil, self.lowerFrame)
	self.editBoxScroller:SetPoint("TOPLEFT", 6, -4)
	self.editBoxScroller:SetPoint("BOTTOMRIGHT", -4, 4)
	self.editBoxScroller:EnableMouseWheel(true)
	
	self.editBoxSlider = CreateFrame("Slider", nil, self.editBoxScroller)
	self.editBoxSlider:SetPoint("TOPRIGHT", 3, -2)
	self.editBoxSlider:SetPoint("BOTTOMRIGHT", 3, 2)
	self.editBoxSlider.knob = self:CreateTexture(nil)
	self.editBoxSlider.knob:SetSize(2, 12)
	self.editBoxSlider:SetThumbTexture(self.editBoxSlider.knob)
	self.editBoxSlider.knob:SetColorTexture(.8, .8, .8)
	self.editBoxSlider:SetOrientation("VERTICAL")
	self.editBoxSlider:SetSize(10, self.editBoxViewport)
	self.editBoxSlider:SetMinMaxValues(0, 0)
	self.editBoxSlider:SetValue(0)
	self.editBoxSlider:SetValueStep(Core.LINE_HEIGHT)
	self.editBoxSlider:SetScript("OnValueChanged", function(this, v) self.editBoxScroller:SetVerticalScroll(v) end)
	self.editBoxScroller:SetScript("OnMouseWheel", UI.OnMouseWheelEvent)

	self.editBox = CreateFrame("EditBox", ADDON_NAME.."MainEB", self.editBoxScroller)
	self.editBox:SetHeight(self.editBoxViewport)
	self.editBox:SetPoint("TOPLEFT")
	self.editBox:SetHitRectInsets(0, 0, 0, -self.editBoxViewport + Core.LINE_HEIGHT)
	self.editBox:SetAutoFocus(false)
	self.editBox:SetMultiLine(true)
	self.editBox:SetFontObject("ChatFontNormal")
	self.editBox:SetScript("OnEscapePressed", self.editBox.ClearFocus)
	self.editBox:SetScript("OnEditFocusGained", editBox_OnEditFocusGained)
	self.editBox:SetScript("OnEditFocusLost", editBox_OnEditFocusLost)
	self.editBox:SetScript("OnCursorChanged", function(this, _, y) self:OnCursorEvent(y) end)
	--self.editBox:SetScript("OnEnter", editBox_CharacterCounter)
	--self.editBox:SetScript("OnLeave", function(this, m) if m then self.editBox.counter:Hide() end end)
	self.editBox:SetScript("OnSizeChanged", editBox_OnSizeChanged)
	self.editBox:SetScript("OnTabPressed", editBox_OnTabPressed)
	self.editBox:SetScript("OnEnterPressed", editBox_OnEnterPressed)
	self.editBox:SetScript("OnSpacePressed", editBox_OnSpacePressed)
	--self.editBox:SetScript("OnKeyDown", editBox_OnKeyDown)
	self.editBox.AddOrRemoveOnTextHandler = editBox_AddOrRemoveOnTextHandler
	
	self.editBoxScroller:SetScrollChild(self.editBox)
	
	self.body = CreateFrame("Frame", nil, self.main, "BackdropTemplate")
	self.body:SetPoint("TOPLEFT", self.titleBar, "BOTTOMLEFT")
	self.body:SetPoint("BOTTOMRIGHT", self.lowerFrame, "TOPRIGHT")
	self.body.BG = self.body:CreateTexture(nil, "BACKGROUND", nil)
	self.body.BG:SetPoint("TOPLEFT", 2, -2)
	self.body.BG:SetPoint("BOTTOMRIGHT", -2, 2)
	self.body.info = {c = {r=0, g=0, b=0, a=1}, name="chatframe"}
	--self.body.BG:SetColorTexture(0,0,0, 0.25)
	self.body:SetBackdrop({
		edgeFile=[[Interface\FriendsFrame\UI-Toast-Border]],
		edgeSize=8,
	})
	
	self.resizeBtn = CreateFrame("Button", nil, self.main)
	self.resizeBtn:SetSize(12, 12)
	self.resizeBtn:SetPoint("BOTTOMRIGHT", 6, -6)
	--self.resizeBtn:SetAlpha(0.5)
	self.resizeBtn:SetNormalTexture([[Interface\CHATFRAME\UI-ChatIM-SizeGrabber-UP]])
	self.resizeBtn:SetHighlightTexture([[Interface\CHATFRAME\UI-ChatIM-SizeGrabber-Highlight]])
	self.resizeBtn:RegisterForDrag("LeftButton")
	self.resizeBtn:SetScript("OnDragStart", function(this) self.main:StartSizing("BOTTOMRIGHT") end)
	self.resizeBtn:SetScript("OnDragStop", function(this)
		self.main:StopMovingOrSizing()
		
		if self.dockMode then
			UI:SetAnchor()
		end
		
		self.editBox:SetWidth(self.lowerFrame:GetWidth() -27)
		self.editBoxScroller:SetVerticalScroll(0)	
		--self.RefreshTabContainer()
		Core.db.BodyLayout.width, Core.db.BodyLayout.height = UI.main:GetSize()
	end)
	
	self.floatingMenu = CreateFrame("Frame", ADDON_NAME.."_FloatingMenu", self, "UIDropDownMenuTemplate")
	
	self.frames = {
		self,
		self.leftFrame,
		--self.main,
		self.body,
		self.titleBar,
		--self.lowerFrame,
	}
end

drawUI()


Core.utils.AddOrRemoveEvents(UI, false,
	--"CHAT_MSG_WHISPER","CHAT_MSG_WHISPER_INFORM","CHAT_MSG_AFK","CHAT_MSG_DND", "CHAT_MSG_BN_WHISPER","CHAT_MSG_BN_WHISPER_INFORM","CHAT_MSG_RESTRICTED",
	"BN_FRIEND_INFO_CHANGED","MODIFIER_STATE_CHANGED","PLAYER_TARGET_CHANGED","GROUP_ROSTER_UPDATE","PORTRAITS_UPDATED",
	"WHO_LIST_UPDATE"
)

