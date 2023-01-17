local ADDON_NAME, Core = ...

--<
local UI = Core.UI
local SM = Core.SM
local myInfo = Core.myInfo
local utils = Core.utils
-->

local TS = "%I:%M "
local TS_NONE = ""
local TS_GREY = "|cFFB3B3B3%I:%M |r"
local FORMAT_GENERIC = "%s[%s]: %s"


local log = setmetatable({}, {
	__newindex = function(self, guid, msg)
		self[guid] = {msg}
		--MessageHandler:NewMessage(guid, msg)
	end
})

local registry = {
	privateEvents = {
		["CHAT_MSG_DND"] = true,
		["CHAT_MSG_AFK"] = true,
		["CHAT_MSG_IGNORED"] = true,
		["CHAT_MSG_WHISPER_INFORM"] = true,
		["CHAT_MSG_WHISPER"] = true,
		["CHAT_MSG_BN_WHISPER"] = true,
		["CHAT_MSG_BN_WHISPER_INFORM"] = true,
	},
}

local handler = CreateFrame("Frame")
handler:RegisterEvent("CHAT_MSG_FILTERED")
handler:RegisterEvent("CHAT_MSG_RESTRICTED")
for ev, _ in pairs(registry.privateEvents) do
	handler:RegisterEvent(ev)
end


local prefixes = {
	EMOTE = "%s* %s ",
	
	classic = {
		WHISPER = "%s".. CHAT_WHISPER_GET,
		WHISPER_INFORM = "%s".. CHAT_WHISPER_INFORM_GET,
		BN_WHISPER = "%s".. CHAT_WHISPER_GET,
		BN_WHISPER_INFORM = "%s".. CHAT_WHISPER_INFORM_GET,
		SAY = "%s".. CHAT_SAY_GET
	}
}


local function CheckForPatternHighlight (ctype, msg)
	local pattern, hex
	
	if ctype ~= "SAY" then
		pattern = '%b""'; hex = RGBToColorCode(utils.GetRGB("SAY"))
	elseif ctype ~= "EMOTE" then
		pattern = '%b**'; hex = RGBToColorCode(utils.GetRGB("EMOTE"))
	end
	
	msg = msg:gsub(pattern, function(catch)
		local _, pos = msg:find(catch)
		
		if pos and msg:sub(pos+1, pos+2) == "|r" then
			return catch
		else
			return format("%s%s|r", hex, catch)
		end
	end)
	
	return msg
end


local function Filter (event, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12, A13, A14, A15, A16)
	local chatFilters = ChatFrame_GetMessageEventFilters(event)
	local filtered = false
	
	if chatFilters then
		local a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15,a16
		
		for _, func in next, chatFilters do
			filtered, a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15,a16 = func(handler, event, A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,A16)
			
			if filtered then
				return true
				
			elseif a2 then
				A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,A16 = a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15,a16
			end
		end
	end
	
	return filtered, A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,A16
end


local function ColouriseName (e, a1, author, a2,a3,a4,a5,a6,a7,a8,a9,a10, guid)
	local _, engClass = GetPlayerInfoByGUID(guid)
	local colour = CreateColor(RAID_CLASS_COLORS[engClass])
	return colour:WrapTextInColor(author)
end


function Core.RegisterForChatType (session, ctype)
	registry[ctype] = registry[ctype] or {}
	table.insert(registry[ctype], session)
end

local function RegisterForChatEvent (e)
	handler:RegisterEvent(e)
end

handler:SetScript("OnEvent", function(self, e, unfilteredMsg, ...)
	local filtered, msg, author, lang, chan, target, flag, zone, chanID, a9, a10, lineID, guid, bnetID = Filter(e, unfilteredMsg, ...)
	if filtered then
		return
	end


	local ctype = e:gsub("CHAT_MSG_", "")
	--msg = C_ChatInfo.ReplaceIconAndGroupExpressions(msg, false, false)

	if not registry.privateEvents[e] then

	else
		SM:UpdateIfNeeded(author, guid)
		
		local inbound = (not ctype:match("INFORM") and true) or false
		local sessionTab, playerLink, displayName
		
		if ctype:match("BN_") then
			sessionTab = SM:Get(bnetID)
			if not sessionTab then
				sessionTab = SM.CreateFromID(bnetID, author)
			end
			
			playerLink = inbound and GetBNPlayerLink(author, author, bnetID, lineID, ctype) or myInfo.battleTag

		else
			sessionTab = SM:Get(guid)
			if not sessionTab then
				sessionTab = SM.CreateFromGUID(guid)
			end
			
			local nameForLink = inbound and author or myInfo.fullName
			local guidForLink = inbound and guid or myInfo.GUID
			
			if sessionTab.preferences.nameColouredByClass then
				displayName = GetColoredName(e, msg, nameForLink, lang,nil,target,flag,nil, chan, nil,nil,lineID, guidForLink)
				playerLink = inbound and GetPlayerLink(author, displayName) or displayName
				
			else
				playerLink = inbound and GetPlayerLink(author, Ambiguate(author, "none")) or myInfo.character
			end
		end
		

		local prefs = sessionTab.preferences
		local ts
		
		if prefs.tsEnabled then
			ts = prefs.tsCustomColour and date(TS_GREY) or date(TS)
		else
			ts = TS_NONE
		end

		local body = FORMAT_GENERIC:format(ts, playerLink, msg)
		local r, g, b
		
		if (prefs.textCustomColour and not(inbound)) or (prefs.textCustomColour and guid == myInfo.GUID) then
			r, g, b = Core.colours.greyText:GetRGB()
		else
			local info =  ChatTypeInfo[ctype]
			r, g, b = info.r, info.g, info.b
		end

		sessionTab.page:AddMessage(body, r, g, b)
		
		UI:Open()
		
		local mained = UI.main:IsShown()
		

		if not mained or not SM.lastWhisperTarget then
			UI.main:SetShown(not Core.db.KeepMinimized)
		end
		
		if (not sessionTab:IsSelected() or not mained or not SM.lastWhisperTarget) and inbound then
			sessionTab:UpdateNotice(ctype)
			
			if not InCombatLockdown() then
				sessionTab:StartGlowing()
			end
		end



		if inbound or SM.lastWhisperTarget == nil then
			SM.lastWhisperTarget = sessionTab
			PlaySound(3081, "Master")
			FlashClientIcon()
		end

		if sessionTab.tab.tabIndex ~= 1 then
			table.insert(Core.orderedTabs, 1, table.remove(Core.orderedTabs, sessionTab.tab.tabIndex))
			Core.Tab_ReanchorAll()
		end
	end
end)
