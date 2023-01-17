local ADDON_NAME, Core = ...

--<
local date, time = date, time
local sub, gsub = string.sub, string.gsub
local upper, format, find, match = string.upper, string.format, string.find, string.match
local UI, SM, utils, myInfo = Core.UI, Core.SM, Core.utils, Core.myInfo
local L = Core.L
-->

local cache = {}

local PRESET_NEARBY = {"Nearby", "EMOTE", "SAY"}
local PRESET_PARTY =  {"Party", "PARTY"}
local PRESET_GUILD =  {"Guild", "GUILD"}


local Session = {
	savedText = "",
	missedMessages = 0,
	typeInform_lastSent = 0,
	typeInform_lastUpdated = 0,
	handshakeCD = 0,
	isDM = true,
	isMuted = false,
}

Session.__index = Session

SM.active = {}
SM.listeners = {}
SM.preset = {
	EMOTE = PRESET_NEARBY,
	SAY = PRESET_NEARBY,
	TEXT_EMOTE = PRESET_NEARBY,
	PARTY = PRESET_PARTY,
	PARTY_LEADER = PRESET_PARTY,
	GUILD = PRESET_GUILD
}
SM.partyEvents = {
	"GROUP_JOINED",
	"GROUP_LEFT",
	"CHAT_MSG_PARTY",
	"CHAT_MSG_PARTY_LEADER"
}
SM.nearbyEvents = {
	"CHAT_MSG_SAY",
	"CHAT_MSG_TEXT_EMOTE",
	"CHAT_MSG_EMOTE",
	"ZONE_CHANGED",
	"ZONE_CHANGED_NEW_AREA",
	"ZONE_CHANGED_INDOORS"
}
SM.PRESET_PREFERENCES = {
	tsCustomColour=true,
	tsEnabled=true,
	nameColouredByClass=true,
	textCustomColour=true,
}

-------------------------------------------------------------------
-------------------------------------------------------------------


local function SessionClass_new ()
	local class = table.remove(cache) or {}
	setmetatable(class, Session)
	
	return class
end


local function SessionClass_init (self, info)
	SM.active[self.name] = self
	
	self.page = Core.CreatePage()
	self.tab = Core.CreateTab(self, info)
	self.preferences = {}
	
	for sett, val in pairs(SM.PRESET_PREFERENCES) do
		self.preferences[sett] = val
	end
	
	self.tab:SetScript("OnMouseDown", function(this, b)
		if b == "LeftButton" then
			SM:Switch(self, true)
			UI.main:Show()

		elseif b == "RightButton" then
			if IsLeftShiftKeyDown() then
				self:Deactivate()
			else
				self:ShowMenu()
			end
		end
	end)

	if SM.selected == nil then
		SM.selected = self
		self:SetSelected()
		UI:UpdateHeader(SM.selected)
		UI.editBox:SetTextColor(self:GetRGB())
		
	else
		self:Deselect()
	end
	
	if not self.isDM or self.needsInfo then return end
	
	Core.History:OnSessionInit(self)
end


-------------------------------------------------------------------
-------------------------------------------------------------------


function SM.CreateFromGUID (guid)
	-- Creates a WHISPER session from GUID
	local S = SM:Get(guid)

	if S then
		return S
	elseif not C_PlayerInfo.GUIDIsPlayer(guid) then
		return
	end
	
	S = SessionClass_new()
	local info = {GetPlayerInfoByGUID(guid)}
	S:SetInfo(guid, unpack(info))
	
	SessionClass_init(S, info)
	table.insert(cache, wipe(info))
	return S
end


function SM.CreateFromID (id, name)
	-- Creates a BN_WHISPER session from bnetID
	local S = SM:Get(id)
	
	if S then
		return S
	elseif not BNConnected() then
		return utils.SMPrint("Could not create session: BattleNet not connected")
	end
	
	S = SessionClass_new()
	
	local info = C_BattleNet.GetAccountInfoByID(id)
	
	if not info then -- to do: weird sync issue with BN, can't fetch friend info
		S.senderID = id
		S.chatType = "BN_WHISPER"
		S.name = name
		S.title = name
	else
		S.senderID = info.bnetAccountID
		S.title = info.accountName
		S.name = info.battleTag:upper()
		S.chatType = "BN_WHISPER"
		S.id = info.battleTag
	end
	

	
	SM.listeners[id] = S.name
	SessionClass_init(S, info)
	return S
end


function SM.CreateFromCharacterName (name)
	-- Creates a WHISPER session without GUID. Has limited info: updates later if-when the GUID is encountered.
	if SM:Get(name) then
		return
	end
	
	local S = SessionClass_new()
	
	S.needsInfo = true
	S.senderID = name
	S.title = utils.capitalize(name)
	S.name = string.upper(name)
	S.chatType = "WHISPER"
	
	SessionClass_init(S)
end


function SM.CreateCustom (name, ...)
	-- deprecated?
	if SM:Get(name) then
		return
	end
	
	local S = SessionClass_new()
	
	S.isDM = false
	S.title = name
	S.name = string.upper(name)	
	S.SMIDs = {}
	
	for i=1, select("#", ...) do
		local ctype = select(i, ...)
		if ChatTypeInfo[ctype] then
			--Core.RegisterForChatType(S, ctype)
			
			S.SMIDs[i] = ctype
			SM.listeners[ctype] = S.name
			
			if ctype:match("PARTY") then
				SM.listeners["PARTY_LEADER"] = S.name
			elseif ctype:match("EMOTE") then
				SM.listeners["TEXT_EMOTE"] = S.name
			end
		end
	end
	
	S.chatType = S.SMIDs[1]
	
	if S.chatType:match("CHANNEL") then
		S.senderID = S.chatType:gsub("CHANNEL", "")
	else
		S.senderID = S.chatType
	end

	SessionClass_init(S)
	
	C_Timer.After(2, function()
		if SM:Get(S.name) and S.name == "NEARBY" then 
			S:UpdateTitle()
		end
	end)

	return S
end


function SM.CreateConsole ()
	local S = SessionClass_new()
	S.title = "Console"
	S.name = "_console"
	S.chatType = "SAY"
	
	SessionClass_init(S)
	
	return S
end


function SM:CreateFromUnit ()
	-- Creates a session from current target or mouseover unit using the SMTalkToUnit keybind
	local unit = (UnitIsPlayer("target") and "target") or (UnitIsPlayer("mouseover") and "mouseover")
	
	if not unit then
		return
	end
	
	local guid = UnitGUID(unit)
	local lvl = UnitLevel(unit)
	local S = self:Get(guid)
	
	if not S then
		S = self.CreateFromGUID(guid)
		
		S:UpdateLevel(lvl)	
		if UnitIsVisible(unit) then
			S:UpdatePortrait(unit)
		end
	end
	
	self:Switch(S)
	UI:OpenChat()
	UI:FocusEditBoxFromKeybind()
end


function SM:Switch (to, byUser)
	if type(to) ~= "table" then
		to = self:Get(to)
		
		if not to then
			return
		end
	end
	
	if (self.selected ~= to) then
		self.selected:Deselect()
		self.selected.savedText = UI.editBox:GetText()
		
		self.selected = to
		to:SetSelected()
		to:StopGlowing()
		
		UI:UpdateHeader(self.selected)
		UI.editBox:SetTextColor(self.selected:GetRGB())
		

	elseif (self.selected == to) then
		if byUser then
			UI:OpenChat()
		end
		
		to:StopGlowing()
	end
	
	local numDisplayableTabs = floor(UI.leftFrame:GetHeight() / Core.TAB_TOTALHEIGHT)
	local vsIndex = self.selected.tab.tabIndex - numDisplayableTabs
	
	UI.tabWindow:SetVerticalScroll(vsIndex > 0 and vsIndex * Core.TAB_TOTALHEIGHT or 0)
end


function SM:GetSelectedRGB ()
	if self.selected then
		return self.selected:GetRGB()
		
	else
		return 1, 1, 1
	end
end


function SM:Get (tag)
	if type(tag) == "string" and not tag:match("^Player") then
		tag = upper(tag)
	end
	
	return self.active[tag] or self.active[self.listeners[tag]] or false
end


local lastSearch = 0
function SM:MatchTargetName (target)
	if target == nil or target == "" then
		return
	end
	
	local id = BNet_GetBNetIDAccount(target)
	local name = utils.capitalize(target)
	local S

	if id == nil then
		local ambName = Ambiguate(name, "short")
		if UnitName("target") == ambName or UnitName("mouseover") == ambName then
			self:CreateFromUnit()
			return
		end
		
		local fullName = utils.getFullName(name)
		local guid = utils.ScanForGUID(name, fullName)
		
		if guid then
			if GetPlayerInfoByGUID(guid) == nil and lastSearch ~= guid then
				C_Timer.After(0.5, function() self:MatchTargetName(target) end)
				lastSearch = guid
				return
			end
			
			S = self.CreateFromGUID(guid)
			lastSearch = 0
		else
			S = self.CreateFromCharacterName(fullName)
		end
	else
		S = self.CreateFromID(id)
	end
	
	if S then
		self:Switch(S)
	end
end


function SM:UpdateIfNeeded (name, guid)
	local S = self:Get(name) 
	if not S then return end

	if S.needsInfo then
		S:SetInfo(guid, GetPlayerInfoByGUID(guid))
	end
end


function SM:CloseIfActive (tag)
	local session = self:Get(tag)
	
	if session then
		session:Deactivate()
	end
end


function SM:SetPreferences ()
	if Core.ChatFont and Core.LSM then
		local path, size, flags = Core.ChatFont:GetFont()
		if (Core.LSM:Fetch("font", Core.db.TextFont) ~= path) or (Core.db.TextSize ~= size) or (Core.db.TextOutline ~= flags) then
			self:UpdateChatFont()
		end
	end
end


function SM:UpdateChatFont ()
	local media = Core.LSM
	Core.ChatFont:SetFont(
		media:Fetch("font", Core.db.TextFont) or media:Fetch("font", media:GetDefault("font")),
		Core.db.TextSize,
		Core.db.TextOutline and "OUTLINE" or ""
	)
	
	--Core.ChatFont:SetShadowOffset(1, -1)
	
	for n, session in pairs(self.active) do
		session.page:SetFontObject(Core.ChatFont)
	end
end


function SM:SendMessage (msg)
	local queue = table.remove(cache) or {}
	local S = self.selected
	local _max = 255
	local ctype = S.chatType
	local target = S:GetID()
	
	
	if ctype == "EMOTE" and msg:find(myInfo.character) == 1 then
		msg = msg:sub(#myInfo.character+1)
		
	elseif ctype:match("CHANNEL") then
		ctype = ctype:sub(1, 7)	
	end

	if #msg > _max then
		
		while #msg ~= 0 do
			local lastChar = msg:sub(_max, _max)
			
			if lastChar == "" and #msg <= _max then 
				queue[#queue+1] = msg
				msg = ""
				break

			elseif lastChar ~= " " then
				local decrement = _max
				local isWhiteSpace = false
				
				while not isWhiteSpace do
					if msg:sub(decrement, decrement) == " " then
						queue[#queue+1] = msg:sub(0, decrement)
						msg = msg:sub(decrement+1)
						isWhiteSpace = true
						
					elseif decrement == 0 then
						queue[#queue+1] = msg:sub(0, _max)
						msg = ""
						break
						
					else					
						decrement = decrement - 1
					end
					
				end
			
			else
				queue[#queue+1] = msg:sub(0, _max)
				msg = msg:sub(_max+1)
			end
			
		end
	
	elseif msg == "" then
		return UI.editBox:ClearFocus()
	
	else
		queue[1] = msg		
	end

	for i, v in ipairs(queue) do
		queue[i] = v:gsub("^%s", "")
	end	
	
	if type(target) == "string" then
		for i, v in ipairs(queue) do
			ChatThrottleLib:SendChatMessage("NORMAL", "SessionsMSGR", v, ctype, nil, target)
		end

	else
		for i, v in ipairs(queue) do
			BNSendWhisper(target, v)
		end

	end

	S.page:Update(true)
	
	if S.isDM then
		SM.lastWhisperTarget = S
	end
	
	table.insert(cache, wipe(queue))
end


-------------------------------------------------------------------
-------------------------------------------------------------------


local numPool = {}
for i=1, 9 do
	numPool[i] = tostring(i)
end
numPool[10] = "9+"


function Session:SetInfo (guid, ...)
	local class, engClass, race, engRace, gender, name, realm = ...
	if not guid or not name then return end
	
	self.senderID = utils.getFullName(name, realm)
	self.title = realm ~= "" and ( string.format("%s (%s)", name, realm) ) or name
	self.name = string.upper(self.senderID)
	self.chatType = "WHISPER"
	self.id = guid
	self.needsInfo = nil

	SM.listeners[guid] = self.name	
	
	if self.tab then
		gender = (gender == 2 and "-male") or (gender == 3 and "-female")
		--self.tab.portrait:SetTexture("Interface/CHARACTERFRAME/TemporaryPortrait-"..gender.."-"..race)
		local atlas = "raceicon128-".. engRace:lower().. gender
		self.tab.portrait:SetAtlas(atlas)
		self.tab.sessionName:SetText(name)
		self.classColour = CreateColor(GetClassColor(engClass))
		self.tab.sessionName:SetTextColor(self.classColour:GetRGB())
		self.tab.infoString:SetText(utils.capitalize(engClass))
		
		Core.History:OnSessionInit(self)
		self:UpdateTitle()
	end
end

function Session:GetRGB (override)
	local c = ChatTypeInfo[override or self.chatType]
	return c.r, c.g, c.b
end

function Session:GetName ()
	return self.tab.sessionName:GetText()
end

function Session:GetID ()
	return self.senderID
end

function Session:Handshake ()
	if not(time() > self.handshakeCD) then
		return
	end

	ChatThrottleLib:SendAddonMessage("NORMAL", "SessionsMSGR", "SMCHK", "WHISPER", self.senderID)
	self.handshakeCD = time() + 5
	C_Timer.After(4, function() if self.isUsingSM == nil then self.isUsingSM = false end end)
end

function Session:UpdatePortrait (unit)
	SetPortraitTexture(self.tab.portrait, unit)
end

function Session:UpdateLevel (lvl)
	local infoString = self.tab.infoString:GetText()
	local startPoint, endPoint = infoString:find("%d+")

	if endPoint then
		infoString = infoString:sub(endPoint+2, #infoString)
	end
	
	self.tab.infoString:SetText(tostring(lvl).. " ".. infoString)
end

function Session:UpdateNotice (ctype)
	self.missedMessages = self.missedMessages+1
	if self.missedMessages > 10 then
		return
	end
	
	local numString = numPool[self.missedMessages] or numPool[10]
	
	if not self.tab.notification:IsShown() then
		self.tab.notification:Show()
	end
	self.tab.notification.num:SetText(numString)
end

function Session:UpdateTitle ()
	if self:IsSelected() then
		UI:UpdateHeader(self)
	end
end

function Session:UpdatePreferences (payload)
	for pref, cb in pairs(payload) do
		self.preferences[pref] = cb:GetChecked()
	end
end

function Session:StartGlowing ()
	if not self.isMuted then
		self.tab.animation:Play()
	end
end

function Session:StopGlowing ()
	self.tab.animation:Stop()
end

function Session:SetSelected ()
	self.tab:SetBackdropBorderColor(1, 1, 1, 1)
	UI.main:Show()
	self.page:Show()
	self.page.slider:SetController(self.page)
	self:MarkAsRead()
	
	UI.editBox:SetText(self.savedText)
	UI.editBox:HighlightText()
	if not IsPlayerMoving() and not InCombatLockdown() then
		UI.editBox:SetFocus()
	end
	
	if not self.isDM then
		self.page:ResetAllFadeTimes()
	end
end

function Session:IsSelected ()
	return SM.selected == self
end

function Session:MarkAsRead ()
	self.missedMessages = 0
	self.tab.notification:Hide()
	
	if self.notice then
		self.notice = Core.hub:RemoveNotice(self.notice)
	end	
end

function Session:Deselect ()
	self.tab:SetBackdropBorderColor(0, 0, 0, 1)
	self.page:Hide()
end

function Session:SetTyping ()
	if not(time() >= self.typeInform_lastUpdated) and not self.page:IsShown() then
		return
	end

	self.page:SetTypingStatus(self:GetName())
	self.typeInform_lastUpdated = time()+5

	C_Timer.After(6, function() if self.page then self.page:ClearTypingStatus() end end)
end

function Session:ShowMenu ()
	if self.menu == nil then
		local name = self:GetName()
		local hide = not self.isDM or self.needsInfo or false
		
		if not hide then
			name = format("%s%s|r", RGBToColorCode(self.tab.sessionName:GetTextColor()), name)
		end

		self.menu = {
			{text=name, isTitle=true, notCheckable=true},
			{
				text=L["Edit conversation"],
				notCheckable=true,
				func=function() UI.floatingFrame:Open(self) end
			},
			{
				text="View history",
				notCheckable=true,
				disabled=true,
				func=function() Core.History:Fetch(self.name) end
			},
			{
				text="Add friend",
				notCheckable=true,
				disabled=hide,
				func=function() C_FriendList.AddFriend(self.name) end
			},
			{
				text="Invite to group",
				notCheckable=true,
				disabled=hide,
				func=function() C_PartyInfo.InviteUnit(self:GetName()) end
			},
			{text="|TInterface/COMMON/UI-TooltipDivider:8:144|t", notClickable=true, notCheckable=true},
			{
				text="Ignore",
				isNotRadio=true,
				disabled=hide,
				keepShownOnClick=true,
				checked=function() if not hide then return C_FriendList.IsIgnoredByGuid(self.id or UnitGUID("Player")) end end,
				func=function() C_FriendList.AddOrDelIgnore(self.name) end,
			},			
			{
				text="Mute notifications",
				isNotRadio=true,
				checked=function() return self.isMuted end,
				func=function() self.isMuted = not self.isMuted; self:MarkAsRead() end,
			},
			{text="Close conversation", notCheckable=true, func=function() self:Deactivate() end},
			{text="|TInterface/COMMON/UI-TooltipDivider:8:144|t", notClickable=true, notCheckable=true},
			{text="Cancel", notCheckable=true},
		}
	end	
	
	EasyMenu(self.menu, UI.floatingMenu, "cursor", 0, 0, "MENU")	
end

function Session:AddHistory (inbound, isBnet, ts, msg)
	if not Core.History:HasHistorySlot(self.name) then
		Core.History:NewEntry(self.name, self.id)
	end
	
	local link = SESMSG_History[self.name]
	local dt = date("%Y-%m-%d")
	
	if not link.INFO.MEM then
		local author = (inbound and Ambiguate(self:GetName(), "short")) or (Core.myCharacterName)
		
		link.INFO.MEM = {
			["MSG"] = author.. ": ".. msg,
			["DT"] = dt,
			["ON"] = Core.myCharacterName
		}
	end	
	
	if link.HISTORY[dt] == nil then
		link.HISTORY[dt] = {}
	end
	
	local slot = link.HISTORY[dt]
	
	slot[#slot+1] = {
		IN = inbound or (isBnet and false or Core.myCharacterName),
		TS = ts:gsub(" ", ""),
		MSG = msg
	}

end

function Session:Deactivate ()
	self:Deselect()
	Core.CloseTab(self.tab)
	self.page:Close()
	
	local DMTabsRemaining = false
	
	if #Core.orderedTabs == 0 then
		SM.selected = nil
		UI.editBox:SetText("")
		UI.editBox:SetTextColor(.8, .8, .8)
		UI:UpdateHeader(nil)
		UI.main:Hide()
		
	else
		for N, S in pairs(SM.active) do
			if S.tab.tabIndex == 1 then
				SM:Switch(S)
			end
			
			if S.isUsingSM == true then
				DMTabsRemaining = true
			end			
		end
	end
	
	for ctype, pointer in pairs(SM.listeners) do
		if pointer == self.name then
			SM.listeners[ctype] = nil
		end
	end

	SM.active[self.name] = nil
	if SM.lastWhisperTarget == self then SM.lastWhisperTarget = nil end
	if not DMTabsRemaining then UI:UnregisterEvent("CHAT_MSG_ADDON") end
	self:MarkAsRead()
	table.insert(cache, wipe(self))
end



Core.Sessions = SM
AddOn_SessionsMessenger = SM