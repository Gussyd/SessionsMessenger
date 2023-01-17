local ADDON_NAME, Core = ...

--<
local date, time = date, time
local sub, gsub = string.sub, string.gsub
local upper, format, find, match = string.upper, string.format, string.find, string.match
local RGBToColorCode = RGBToColorCode
local UI = Core.UI
local utils = Core.utils
local Sessions = Core.Sessions
-->

local myCharacterName, myBattleTag, myRPAlias, myGUID
local cache = {}


local formatPatterns = {
	generic = "%s%s: %s",
	emoteApostrophe = "%s%s%s",
	emoteSpecial = [[%s%s|TInterface\FriendsFrame\BroadcastIcon:16:16|t %s]],
	EMOTE = "%s* %s %s",

	verbose = {
		WHISPER = "%s%s whispers: %s",
		WHISPER_INFORM = "%sTo %s: %s",
		BN_WHISPER = "%s%s whispers: %s",
		BN_WHISPER_INFORM = "%sTo %s: %s",
		SAY = "%s%s says: %s",
	}
}


local function chatMsgRestrictedHandler (...)
	local err, target = ...
	local S = Sessions:Get(target)

	if err == "ChatIgnoredHandler" and S then
		S.page:AddMessage(_G.CHAT_RESTRICTED, 1, 0, 0)
	end
end



local function sendEmote (cmd, msg, session)
	if msg == nil and not UnitName("target") and session then
		msg = session:GetName()
	end
	
	cmd = gsub(cmd, "/", "")
	
	DoEmote(cmd, msg)
end


local function bnetFriendUpdateHandler (...)
	local friendIndex = ...
	if friendIndex == nil then 
		return 
	end
	
	local payload = C_BattleNet.GetFriendAccountInfo(friendIndex)
	if not payload then
		return
	end
	
	local S = Sessions:Get(payload.bnetAccountID)
	if not S then return end
	
	Core.BNetDisplayUpdate(S.tab, payload.gameAccountInfo)
end


local function replyHook ()
	if Sessions.lastWhisperTarget == nil then
		return
	end	

	if not UI.main:IsShown() then
		UI.main:Show()
	end

	Sessions:Switch(Sessions.lastWhisperTarget)
	UI:FocusEditBoxFromKeybind()
end



local function updateHeaderHook (editBox)
	if editBox:GetAttribute("chatType"):match("WHISPER") == nil then
		Core.G_ChatType = editBox:GetAttribute("chatType")
	end	
end


local function insertItemLink (item)
	if UI.editBox:HasFocus() and IsModifiedClick("CHATLINK") then
		local loc = PaperDollFrame:IsMouseOver() and ItemLocation:CreateFromEquipmentSlot(item:GetID()) or ItemLocation:CreateFromBagAndSlot(item:GetParent():GetID(), item:GetID())
		UI.editBox:Insert(C_Item.GetItemLink(loc))
		
		if StackSplitFrame:IsShown() then
			StackSplitFrame:Hide()
		end
	end
end


local function extractTellTargetHook (editBox, msg)
	local target = msg:match("%s*(.*)")
	
	if ( not target or not target:find("%s") ) then
		return false;
	end
	
	if target:sub(1, 1) == "|" then
		return false
	end
	
	while target:find("%s") do
		target = target:match("(.+)%s+[^%s]*")
		if #GetAutoCompleteResults(target, 1, 0, true, AUTOCOMPLETE_LIST.ALL.include,
			AUTOCOMPLETE_LIST.ALL.exclude) > 0 then 
			break
		end
		
	end

	Sessions:MatchTargetName(target)
	
	UI:Open(true)
	editBox:Hide()
	UI.editBox:SetFocus()
	
end


local function sendBNetTellHook (name)
	Core.G_EditBox:Hide()
	UI:Show()
	Sessions:MatchTargetName(name)
end


local function onPortraitsUpdated ()
	if #Core.orderedTabs == 0 or InCombatLockdown() or not IsInGroup(LE_PARTY_CATEGORY_HOME) then
		return
	end
	
	local numPartyMembers = GetNumGroupMembers(LE_PARTY_CATEGORY_HOME)-1
	
	if numPartyMembers > 0 then		
		for i=1, numPartyMembers do
			local unit = "party".. tostring(i)
			local S = Sessions:Get(UnitGUID(unit))
			
			if S and UnitIsVisible(unit) then
				S:UpdatePortrait(unit)
			end
		end
	end
end


local function GetPattern (ctype, msg)
	if ctype == "EMOTE" and (msg:sub(1, 1) == "|" or msg:match("^%u")) then
		return formatPatterns.emoteSpecial
	elseif ctype == "EMOTE" and msg:sub(1, 1) == "'" then
		return formatPatterns.emoteApostrophe
	else
		return formatPatterns[ctype]
	end
end


local function ParseText (ctype, msg)
	local pattern, hex
	
	if ctype ~= "SAY" then
		pattern = '%b""'; hex = RGBToColorCode(utils.GetRGB("SAY"))
	elseif ctype ~= "EMOTE" then
		pattern = '%b**'; hex = RGBToColorCode(utils.GetRGB("EMOTE"))
	end
	
	msg = gsub(msg, pattern, function(catch)
		local _, pos = msg:find(catch)
		
		if pos and msg:sub(pos+1, pos+2) == "|r" then
			return catch
		else
			return format("%s%s|r", hex, catch)
		end		
	end)
	
	if ctype ~= "EMOTE" then
		msg = gsub(msg, "<?https?://[%w%p]+", function(url)
			if url:match("<") then
				return url
			else
				return format("|H%s|h|cFFC845FA<%s>|r|h", url, url)
			end
		end)
	end
	
	return msg
end

UI:SetScript("OnEvent", function(self, e, ...)
	if e:match("CHAT_MSG_") then
		--onChatMessageReceived(e, ...)
	
	elseif e == "BN_FRIEND_INFO_CHANGED" then
		bnetFriendUpdateHandler(...)

	elseif e == "GROUP_JOINED" then
		local S = Sessions:Get("PARTY") or Sessions.CreateCustom("Party", "PARTY")
		S.page:AddMessage(format(_G.ERR_JOINED_GROUP_S, myCharacterName), 1, 1, 0)
		
	elseif e == "GROUP_LEFT" then
		local S = Sessions:Get("PARTY")
		if S then S.page:AddMessage(_G.ERR_LEFT_GROUP_YOU, 1, 0, 0) end

	elseif e == "MODIFIER_STATE_CHANGED" and UI.main:IsShown() then
		local key, state = ...
		if key ~= "LCTRL" then return end
		
		if Sessions.selected ~= nil then
			Sessions.selected.page:SetTextCopyable(state > 0 and 1 or nil)
		end
		--[[
		if state == 1 then
			self.resizeBtn:Show()
			
		else
			self.main:StopMovingOrSizing()
			self.resizeBtn:Hide()
		end
		--]]
	elseif e == "PLAYER_TARGET_CHANGED" then
		if not UnitIsPlayer("target") or not UnitIsVisible("target") then
			return
		end
		
		local S = Sessions:Get(UnitGUID("target"))

		if S then
			S:UpdatePortrait("target")
		end
	
	elseif (e == "GROUP_ROSTER_UPDATE" and not IsInRaid()) or (e == "PORTRAITS_UPDATED") then
		onPortraitsUpdated()
		
	elseif e == "WHO_LIST_UPDATE" then
		Sessions:OnWhoReceived()
		
	elseif e:match("ZONE_CHANGED") and Sessions:Get("NEARBY") then
		Sessions:Get("NEARBY"):UpdateTitle()
	end	
end)


hooksecurefunc("ChatEdit_ExtractTellTarget", extractTellTargetHook)
hooksecurefunc("ChatEdit_UpdateHeader", updateHeaderHook)
hooksecurefunc("ChatFrame_ReplyTell", replyHook)
hooksecurefunc("ChatFrame_ReplyTell2", replyHook)
--hooksecurefunc("ChatFrame_SendTell")
hooksecurefunc("ChatFrame_SendBNetTell", sendBNetTellHook)
--hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", insertItemLink)
--hooksecurefunc("PaperDollItemSlotButton_OnModifiedClick", insertItemLink)


local function debug ()
	if Core.debugging then
		for i=1, #Core.debugging do
			local err = Core.debugging[i]
			utils.SMPrint(err)
		end
	end
end

SlashCmdList["SESSIONS_OPEN"] = function()
	UI:Show()
end

SLASH_SESSIONS_OPEN1 = "/sessions"

SlashCmdList["SESSIONS_TALKTO"] = function(msg)
	onTellTargetIntercept(msg)
	UI:Show()
end

SLASH_SESSIONS_TALKTO1 = "/talkto"
SLASH_SESSIONS_TALKTO2 = "/tt"


SlashCmdList["SESSIONS_DEBUG"] = debug

SLASH_SESSIONS_DEBUG1 = "/smdebug"

function Core.UpdatePlayerInfo ()
	myCharacterName = UnitName("Player")
	myGUID = UnitGUID("Player")
	local btag = BNet_GetTruncatedBattleTag(select(2, BNGetInfo()))
	myBattleTag = btag ~= "" and btag or "Me"
	Core.myCharacterName = myCharacterName
	Core.myRealmName = gsub(GetRealmName(), " ", "")
	
	Core.myInfo.character = myCharacterName
	Core.myInfo.battleTag = myBattleTag
	Core.myInfo.fullName = myCharacterName.. "-".. Core.myRealmName
	Core.myInfo.GUID = myGUID
	Core.myInfo.guildName = GetGuildInfo("player")
end

