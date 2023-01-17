local ADDON_NAME, Core = ...

if true then return end

--<
local UI = Core.UI
local SM = Core.SM
-->

--[[
	This is what we're calling the secure editbox.
	We're just grabbing the ChatFrame10EditBox as it's the least likely to be in use,
	and we play a hide/show game between it and SM's main editbox.
	We -try- to restore it back to normal. Could do a better job, but... eh! If conflicts arise.
]]

local cmdList = {
	emote = {
		["emote"] = true,
		["e"] = true,
		["em"] = true,
		["me"] = true,
	},
	whisper = {
		["whisper"] = true,
		["w"] = true,
	},
	reply = {
		["reply"] = true,
		["r"] = true,
	},
	guild = {
		["guild"] = true,
		["g"] = true,
	},
	party = {
		["party"] = true,
		["p"] = true,
	}
}

local box = ChatFrame10EditBox
local orig_onSpacePressed = box:GetScript("OnSpacePressed")
local orig_onTextChanged = box:GetScript("OnTextChanged")

local function restore ()
	local text = box:GetText()
	box:ClearFocus()
	
	UI.editBox:SetText(text)
	UI:OpenChat()
end


local function onHeaderUpdate (self)
	if self == box then
		ChatFrame10EditBoxHeader:Hide()
		box:SetTextInsets(0, 0, 0, 0)
	end
end


local function onSpacePressed (self)
	local cmd = string.lower(self:GetText():sub(2, -2))

	if cmdList.emote[cmd] and Core.IsTypeEnabled("EMOTE") or cmdList.party[cmd] and Core.IsTypeEnabled("PARTY")
		or cmdList.guild[cmd] and Core.IsTypeEnabled("GUILD") or cmdList.reply[cmd] then
		restore()
		UI.editBox:GetScript("OnSpacePressed")(UI.editBox)
	else
		orig_onSpacePressed(self)
	end
end


local function onTextChanged (self)
	if self:GetText():sub(1, 1) ~= "/" then
		--restore()
	end
end


local point1, rel1, relTo1, x1, y1 = box:GetPoint(1)
local point2, rel2, relTo2, x2, y2 = box:GetPoint(2)


local function onEditFocusLost (self)
	if self == box and self:GetParent() == UI.editBoxScroller then
		local chatFrameInUse = select(9, GetChatWindowInfo(10))
		self:Hide()
		self:SetText("")
		
		if chatFrameInUse then
			self:ClearAllPoints() 
			self:SetParent(UIParent)
			self:SetPoint(point1, rel1, relTo1, x1, y1)
			pcall(self.SetPoint, self, point2, rel2, relTo2, x2, y2) -- I think Prat clears the 2nd point? Just precautions for now.
			self:SetScript("OnTextChanged", orig_onTextChanged)
			self:SetScript("OnSpacePressed", orig_onSpacePressed)
			
			if box.pratFrame then
				box.pratFrame:Show()
			end
		end
		
		UI.editBox:Show()
	end
	
	ChatEdit_SetLastActiveWindow(SELECTED_CHAT_FRAME.editBox)
end


function Core.SecureBox_Show ()
	if box:GetParent() ~= UI.editBoxScroller then
		point1, rel1, relTo1, x1, y1 = box:GetPoint(1)
		point2, rel2, relTo2, x2, y2 = box:GetPoint(2)
		box:ClearAllPoints()
		box:SetParent(UI.editBoxScroller)
		box:SetAllPoints()
		box:SetScript("OnTextChanged", onTextChanged)
		box:SetScript("OnSpacePressed", onSpacePressed)		
	end	

	box:Show()
	if box.pratFrame then
		box.pratFrame:Hide()
	end
	box:SetFocus()	
end


ChatFrame10EditBoxLeft:Hide()
ChatFrame10EditBoxMid:Hide()
ChatFrame10EditBoxRight:Hide()
box.focusLeft:SetAlpha(0)
box.focusMid:SetAlpha(0)
box.focusRight:SetAlpha(0)
box:SetMultiLine(true)
hooksecurefunc("ChatEdit_UpdateHeader", onHeaderUpdate)
box:HookScript("OnEditFocusLost", onEditFocusLost)

