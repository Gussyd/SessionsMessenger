local ADDON_NAME, Core = ...

--<
local match, gsub, format = string.match, string.gsub, string.format
local UI, utils, SM = Core.UI, Core.utils, Core.SM
-->

local frameCache = {}

local typingStatus = CreateFrame("Frame", nil, UI.body)
typingStatus:Hide()
typingStatus:SetSize(220, 16)
typingStatus:SetPoint("BOTTOMLEFT", 3, 5)
typingStatus:SetFrameStrata("HIGH")
typingStatus.BG = typingStatus:CreateTexture(nil)
typingStatus.BG:SetTexture([[Interface\Cooldown\LoC-ShadowBG]])
typingStatus.BG:SetAllPoints()
typingStatus.BG:SetTexCoord(0.3, 1, 0, 1)
typingStatus.text = typingStatus:CreateFontString(nil)
typingStatus.text:SetFontObject("NumberFont_Shadow_Med")
typingStatus.text:SetPoint("LEFT")
typingStatus.text:SetJustifyH("LEFT")

local highlight = CreateFrame("Frame")
highlight:Hide()
highlight.BG = highlight:CreateTexture(nil, "OVERLAY")
highlight.BG:SetColorTexture(1, 1, 1, 0.1)
highlight.BG:SetAllPoints()


local function onHyperLinkEnter (self, link, text)
	if Core.RPAddOn and not SM.selected.isDM and link:find("^player") then
		link = link:gsub("player:", "")
		GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
		GameTooltip_SetTitle(GameTooltip, link)
		GameTooltip:Show()
	end
end


local function onHyperLinkClick (self, link, text, button)
	if link:match("^https?://") then
		StaticPopup_Show("SESSIONS_COPYTEXT", nil, nil, link)
		return
	end

	ChatFrame_OnHyperlinkShow(self, link, text, button)
end


local function onMouseWheel (self, delta)
	if delta == -1 and not self:AtBottom() then
		self:ScrollDown()

	elseif delta == 1 then
		self:ScrollUp()
	end

	self.slider:SetValue(-self:GetScrollOffset())
end


local function onMouseDown (self, btn)
	if btn ~= "RightButton" then
		return
	end

	local _, lineIndex = self:FindCharacterAndLineIndexAtCoordinate(self:GetScaledCursorPosition())
	local line = self.visibleLines[lineIndex]
	
	if not line then
		return
	end

	if IsLeftControlKeyDown() or IsRightControlKeyDown() then
		StaticPopup_Show("SESSIONS_COPYTEXT", nil, nil, line:GetText())
		
	elseif match(line:GetText(), ": Right%-Click To Show]") then
		local pending = select(6, self:UnpackageEntry(line.messageInfo))
		line.messageInfo.message = pending
		line:SetText(pending)
	end
end


local function onLayoutRefreshed (self)
	local lineOne = self.visibleLines[1]
	if lineOne ~= nil then
		lineOne:ClearAllPoints()
		lineOne:SetPoint("BOTTOMLEFT", 0, 2)
	end
end

local function onMessage (self)
	
end

local elapsed = 0
local currentIndex = 0
local function onUpdate (self, ms)
	elapsed = elapsed + ms
	
	if elapsed > 0.2 then
		local _, lineIndex = self:FindCharacterAndLineIndexAtCoordinate(self:GetScaledCursorPosition())
		local line = self.visibleLines[lineIndex]
		
		if currentIndex == lineIndex then
			return
			
		elseif not line or not line:IsShown() then
			if highlight:IsShown() then
				highlight:Hide()
			end
			return
		end
		
		highlight:ClearAllPoints()
		highlight:SetPoint("TOPLEFT", line, "TOPLEFT")
		highlight:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT")
		highlight:Show()
		
		currentIndex = lineIndex
		elapsed = 0
	end
end

local function linetest (self)
		highlight:ClearAllPoints()
		highlight:SetPoint("TOPLEFT", self, "TOPLEFT")
		highlight:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT")
		highlight:Show()
end

local function onEnter (self)
	if highlight:GetParent() ~= self then
		highlight:SetParent(self)
	end
	
	for i,v in ipairs(self.visibleLines) do
		if not v:GetScript("OnEnter") and v:IsShown() then
			v:HookScript("OnEnter", linetest)
			v:EnableMouse(true)
		end
	end

end


local function onLeave (self)
	highlight:Hide()
end


local function Update (self, force)
	if not self:IsShown() then return end
	
	self.slider:SetSize(10, self:GetHeight())
	self.slider:SetMinMaxValues(-self:GetMaxScrollRange(), 0)
	
	if force then
		self.slider:SetValue(self:GetMaxScrollRange())
	end
end


local function ClearTypingStatus (self)
	typingStatus.text:SetText("")
	typingStatus:Hide()
end

local function SetTypingStatus (self, name)
	if not typingStatus:IsShown() and self:IsShown() then
		typingStatus.text:SetText([[|TInterface\CHATFRAME\UI-ChatWhisperIcon:16:16|t]].. name.. " is typing...")
		typingStatus:Show()
	end
end


local function Close (self)
	self:Clear()
	frameCache[#frameCache+1] = self
end



function Core.CreatePage (parent)
	if #frameCache > 0 then
		return table.remove(frameCache)
	end

	local f = CreateFrame("ScrollingMessageFrame", nil, parent or UI.body)
	f:SetPoint("BOTTOMLEFT", 7, 6)
	f:SetPoint("TOPRIGHT", -10, -5)
	f:SetFontObject(Core.ChatFont)
	f:SetJustifyH("LEFT")
	f:SetFading(false)
	f:SetIndentedWordWrap(true)
	f:SetInsertMode(2)
	f:EnableMouseWheel(1)
	f:SetHyperlinksEnabled(1)
	f:EnableMouse(true)
	f:SetTimeVisible(120)
	
	if not UI.body.slider and not parent then
		UI.body.slider = Core.CreateSlider(UI.body)
		UI.body.slider:ClearAllPoints()
		UI.body.slider:SetPoint("TOPRIGHT", -1, -5) ; UI.body.slider:SetPoint("BOTTOMRIGHT", -1, 5)
	end
	
	f.slider = UI.body.slider
	f.Update = Update
	f.Close = Close
	--f.SetTypingStatus = SetTypingStatus
	--f.ClearTypingStatus = ClearTypingStatus
	
	f:SetScript("OnMouseWheel", onMouseWheel)
	f:SetScript("OnMouseDown", onMouseDown)	
	f:HookScript("OnHyperlinkClick", onHyperLinkClick)
	--f:HookScript("OnHyperlinkEnter", onHyperLinkEnter)
	--f:HookScript("OnHyperlinkLeave", GameTooltip_Hide)
	--hooksecurefunc(f, "RefreshLayout", onLayoutRefreshed)
	--f:SetScript("OnEnter", onEnter)
	--f:SetScript("OnLeave", onLeave)
	
	return f
	
end