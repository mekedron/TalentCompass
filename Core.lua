local addonName, ns = ...

ns.classes = {}
ns.callbacks = {}

local FIRST_TALENT_LEVEL = 10
local TOTAL_POINTS = 51

local defaults = {
	lang = "auto",
	highlight = true,
	chatHints = true,
	panelShown = true,
}

-- Data files call this to register their class guide.
function ns.RegisterClass(classFile, data)
	ns.classes[classFile] = data
	for _, build in ipairs(data.builds or {}) do
		build.steps = {}
		build.target = {}
		for _, entry in ipairs(build.order) do
			local key, ranks = entry[1], entry[2] or 1
			for _ = 1, ranks do
				table.insert(build.steps, key)
			end
			build.target[key] = (build.target[key] or 0) + ranks
		end
	end
end

function ns.Print(fmt, ...)
	local msg = select("#", ...) > 0 and fmt:format(...) or fmt
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Talent Compass:|r " .. msg)
end

-- Blizzard font objects are font families that pick the Latin or Cyrillic font by the
-- start of a string, so mixed text such as "Protection · 16 ур." shows boxes. Our own
-- copies use the Cyrillic Friz Quadrata, which contains both alphabets.
local CYRILLIC_FONT = "Fonts\\FRIZQT___CYR.TTF"
local fontCache = {}

function ns.Font(base)
	if fontCache[base] then
		return fontCache[base]
	end
	local source = _G[base] or GameFontNormal
	local font = CreateFont("TalentCompass_" .. base)
	font:CopyFontObject(source)
	local _, size, flags = source:GetFont()
	font:SetFont(CYRILLIC_FONT, size or 12, flags or "")
	fontCache[base] = font
	return font
end

function ns.CreateText(parent, layer, base)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	fs:SetFontObject(ns.Font(base or "GameFontHighlight"))
	return fs
end

function ns.OnUpdate(callback)
	table.insert(ns.callbacks, callback)
end

---------------------------------------------------------------------------
-- Class / build selection
---------------------------------------------------------------------------

function ns.GetPlayerClass()
	local _, classFile = UnitClass("player")
	return classFile
end

function ns.GetClassData()
	return ns.classes[ns.GetPlayerClass()]
end

function ns.GetActiveBuild()
	local data = ns.GetClassData()
	if not data or not data.builds or #data.builds == 0 then
		return nil
	end
	local wanted = TalentCompassCharDB.build
	for _, build in ipairs(data.builds) do
		if build.id == wanted then
			return build
		end
	end
	return data.builds[1]
end

function ns.SetActiveBuild(buildID)
	TalentCompassCharDB.build = buildID
	ns.RequestRefresh()
end

---------------------------------------------------------------------------
-- Reading the talent tree (C_Traits)
---------------------------------------------------------------------------

local function Normalize(name)
	if not name then
		return nil
	end
	-- Strip ASCII punctuation and spaces; lower-case ASCII. Cyrillic bytes are kept as-is.
	return (name:lower():gsub("[%s%p]", ""))
end
ns.Normalize = Normalize

local function GetSpellName(spellID)
	if not spellID then
		return nil
	end
	if C_Spell and C_Spell.GetSpellName then
		return C_Spell.GetSpellName(spellID)
	end
	return (GetSpellInfo(spellID))
end

local function GetSpellIcon(spellID)
	if not spellID then
		return nil
	end
	if C_Spell and C_Spell.GetSpellTexture then
		return C_Spell.GetSpellTexture(spellID)
	end
	return select(3, GetSpellInfo(spellID))
end

function ns.GetTalentsFrame()
	return PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
end

function ns.GetConfigID()
	local frame = ns.GetTalentsFrame()
	if frame and frame:IsShown() and frame.GetConfigID and not (frame.IsInspecting and frame:IsInspecting()) then
		local configID = frame:GetConfigID()
		if configID then
			return configID
		end
	end
	if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
		return C_ClassTalents.GetActiveConfigID()
	end
end

-- Returns a snapshot of every talent in the player's tree:
-- { treeID, configID, unspent, talents = { {nodeID, entryID, spellID, name, icon, rank, maxRanks, groupID, treeName}, ... },
--   bySpell = {}, byName = {}, byNode = {} }
function ns.ScanTree()
	local configID = ns.GetConfigID()
	if not configID or not C_Traits then
		return nil
	end
	local configInfo = C_Traits.GetConfigInfo(configID)
	local treeID = configInfo and configInfo.treeIDs and configInfo.treeIDs[1]
	if not treeID then
		return nil
	end

	local groupNames, groupOrder = {}, {}
	if C_Traits.GetGroupDisplayInfoByTreeID then
		for i, info in ipairs(C_Traits.GetGroupDisplayInfoByTreeID(treeID) or {}) do
			groupNames[info.groupID] = info.displayName
			groupOrder[info.groupID] = i
		end
	end

	local scan = {
		configID = configID,
		treeID = treeID,
		talents = {},
		bySpell = {},
		byName = {},
		byNode = {},
		unspent = 0,
		spent = 0,
	}

	for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
		local node = C_Traits.GetNodeInfo(configID, nodeID)
		if node and node.ID and node.ID ~= 0 and node.isVisible ~= false then
			local groupID
			for _, gid in ipairs(node.groupIDs or {}) do
				if groupNames[gid] then
					groupID = gid
					break
				end
			end
			local activeEntryID = node.activeEntry and node.activeEntry.entryID
			for _, entryID in ipairs(node.entryIDs or {}) do
				local entry = C_Traits.GetEntryInfo(configID, entryID)
				local def = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
				if def then
					local spellID = def.overriddenSpellID or def.spellID
					local rank = node.ranksPurchased or node.currentRank or 0
					if #node.entryIDs > 1 and activeEntryID ~= entryID then
						rank = 0
					end
					local talent = {
						nodeID = nodeID,
						entryID = entryID,
						spellID = def.spellID,
						name = def.overrideName or GetSpellName(def.spellID) or GetSpellName(spellID) or ("#" .. nodeID),
						icon = def.overrideIcon or GetSpellIcon(def.spellID),
						rank = rank,
						maxRanks = (entry.maxRanks and entry.maxRanks > 0) and entry.maxRanks or node.maxRanks,
						groupID = groupID,
						treeIndex = groupOrder[groupID],
						treeName = groupNames[groupID],
						posX = node.posX,
						posY = node.posY,
						available = node.isAvailable,
					}
					table.insert(scan.talents, talent)
					scan.spent = scan.spent + rank
					if talent.spellID then
						scan.bySpell[talent.spellID] = talent
					end
					local key = Normalize(talent.name)
					if key then
						scan.byName[key] = talent
					end
					scan.byNode[nodeID] = scan.byNode[nodeID] or talent
				end
			end
		end
	end

	if C_Traits.GetTreeCurrencyInfo then
		local currencies = C_Traits.GetTreeCurrencyInfo(configID, treeID, false)
		if currencies and currencies[1] then
			scan.unspent = currencies[1].quantity or 0
		end
	end

	return scan
end

-- Finds the in-game talent for a guide key (English talent name).
function ns.ResolveTalent(scan, key)
	if not scan then
		return nil
	end
	local data = ns.GetClassData()
	local meta = data and data.talents and data.talents[key]
	if meta and meta.spell and scan.bySpell[meta.spell] then
		return scan.bySpell[meta.spell]
	end
	local found = scan.byName[Normalize(key)]
	if not found and meta and meta.ru then
		found = scan.byName[Normalize(meta.ru)]
	end
	return found
end

-- Localized display name for a guide key, preferring the game's own spelling.
function ns.TalentDisplayName(key, talent)
	if talent and talent.name then
		return talent.name
	end
	local data = ns.GetClassData()
	local meta = data and data.talents and data.talents[key]
	if ns.GetLanguage() == "ru" and meta and meta.ru then
		return meta.ru
	end
	return key
end

---------------------------------------------------------------------------
-- Build progress
---------------------------------------------------------------------------

-- Compares the current tree with a build.
-- Returns { steps = { {key, level, rankAfter, talent, done} }, nextIndex, doneCount, offBuild = {}, missing = {} }
function ns.ComputePlan(build, scan)
	local plan = { steps = {}, doneCount = 0, offBuild = {}, missing = {}, total = #build.steps }
	local used, missingSeen = {}, {}
	local resolved = {}

	for key in pairs(build.target) do
		resolved[key] = ns.ResolveTalent(scan, key)
		if scan and not resolved[key] and not missingSeen[key] then
			missingSeen[key] = true
			table.insert(plan.missing, key)
		end
	end
	table.sort(plan.missing)

	for i, key in ipairs(build.steps) do
		used[key] = (used[key] or 0) + 1
		local talent = resolved[key]
		local done = talent ~= nil and talent.rank >= used[key]
		table.insert(plan.steps, {
			key = key,
			level = FIRST_TALENT_LEVEL + i - 1,
			rankAfter = used[key],
			maxRanks = build.target[key],
			talent = talent,
			done = done,
		})
		if done then
			plan.doneCount = plan.doneCount + 1
		else
			plan.firstOpen = plan.firstOpen or i
			-- Prefer a step the tree lets you take right now (points spent out of order
			-- or outside the build can leave an earlier step locked).
			if not plan.nextIndex and talent and talent.available ~= false then
				plan.nextIndex = i
			end
		end
	end
	plan.nextIndex = plan.nextIndex or plan.firstOpen

	if scan then
		local inBuild = {}
		for key, talent in pairs(resolved) do
			if talent then
				inBuild[talent.nodeID] = build.target[key]
			end
		end
		for _, talent in ipairs(scan.talents) do
			if talent.rank > 0 then
				local allowed = inBuild[talent.nodeID] or 0
				if talent.rank > allowed then
					table.insert(plan.offBuild, { talent = talent, extra = talent.rank - allowed })
				end
			end
		end
	end

	-- Per-node target lookup for the tree highlight.
	plan.nodeTargets = {}
	for key, talent in pairs(resolved) do
		if talent then
			plan.nodeTargets[talent.nodeID] = { key = key, target = build.target[key], talent = talent }
		end
	end
	local nextStep = plan.nextIndex and plan.steps[plan.nextIndex]
	plan.nextNodeID = nextStep and nextStep.talent and nextStep.talent.nodeID

	return plan
end

-- How well the points already spent fit a build: { matched, off, percent }.
function ns.MatchBuild(build, scan)
	local matched, off = 0, 0
	if not scan then
		return { matched = 0, off = 0, percent = 0 }
	end
	local allowed = {}
	for key, target in pairs(build.target) do
		local talent = ns.ResolveTalent(scan, key)
		if talent then
			allowed[talent.nodeID] = target
		end
	end
	for _, talent in ipairs(scan.talents) do
		if talent.rank > 0 then
			local cap = allowed[talent.nodeID] or 0
			matched = matched + math.min(talent.rank, cap)
			off = off + math.max(0, talent.rank - cap)
		end
	end
	local spent = matched + off
	return { matched = matched, off = off, percent = spent > 0 and math.floor(matched * 100 / spent + 0.5) or 0 }
end

-- Build that best fits the talents the character already has.
function ns.BestBuild(scan)
	local data = ns.GetClassData()
	local best, bestScore
	for _, build in ipairs(data and data.builds or {}) do
		local m = ns.MatchBuild(build, scan)
		local score = m.matched - m.off
		if not bestScore or score > bestScore then
			best, bestScore = build, score
		end
	end
	return best
end

ns.TOTAL_POINTS = TOTAL_POINTS
ns.FIRST_TALENT_LEVEL = FIRST_TALENT_LEVEL

---------------------------------------------------------------------------
-- Refresh pipeline
---------------------------------------------------------------------------

local refreshPending = false

function ns.Refresh()
	refreshPending = false
	local scan = ns.ScanTree()
	-- First time on this character: pick the build that fits the points already spent.
	if not TalentCompassCharDB.build and scan and scan.spent > 0 then
		local best = ns.BestBuild(scan)
		if best then
			TalentCompassCharDB.build = best.id
			ns.Print(ns.L.AUTO_PICKED, ns.T(best.name), ns.MatchBuild(best, scan).percent)
		end
	end
	local build = ns.GetActiveBuild()
	ns.scan = scan
	ns.plan = build and ns.ComputePlan(build, scan) or nil
	for _, callback in ipairs(ns.callbacks) do
		local ok, err = pcall(callback, ns.plan, build, scan)
		if not ok then
			geterrorhandler()(err)
		end
	end
end

function ns.RequestRefresh()
	if refreshPending then
		return
	end
	refreshPending = true
	C_Timer.After(0.05, ns.Refresh)
end

local function ChatHint()
	if not TalentCompassDB.chatHints then
		return
	end
	local build = ns.GetActiveBuild()
	local scan = ns.ScanTree()
	if not build or not scan or scan.unspent <= 0 then
		return
	end
	local plan = ns.ComputePlan(build, scan)
	local step = plan.nextIndex and plan.steps[plan.nextIndex]
	if step then
		ns.Print(ns.L.CHAT_NEXT, ns.T(build.name), ns.TalentDisplayName(step.key, step.talent), step.rankAfter, step.maxRanks)
	end
end

---------------------------------------------------------------------------
-- Talent dump (helps keeping Data\*.lua in sync with the live game)
---------------------------------------------------------------------------

local function Dump()
	local scan = ns.ScanTree()
	if not scan then
		ns.Print(ns.L.TREE_NOT_READY)
		return
	end
	local list = {}
	for _, t in ipairs(scan.talents) do
		table.insert(list, {
			name = t.name,
			spellID = t.spellID,
			nodeID = t.nodeID,
			tree = t.treeName,
			maxRanks = t.maxRanks,
			posX = t.posX,
			posY = t.posY,
		})
	end
	table.sort(list, function(a, b)
		if (a.tree or "") ~= (b.tree or "") then
			return (a.tree or "") < (b.tree or "")
		end
		if a.posY ~= b.posY then
			return a.posY < b.posY
		end
		return a.posX < b.posX
	end)
	TalentCompassDB.dump = TalentCompassDB.dump or {}
	TalentCompassDB.dump[ns.GetPlayerClass() .. "-" .. GetLocale()] = list
	ns.Print(ns.L.DUMP_DONE, #list)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		TalentCompassDB = TalentCompassDB or {}
		TalentCompassCharDB = TalentCompassCharDB or {}
		for key, value in pairs(defaults) do
			if TalentCompassDB[key] == nil then
				TalentCompassDB[key] = value
			end
		end
	elseif event == "PLAYER_LOGIN" then
		for _, e in ipairs({
			"TRAIT_CONFIG_UPDATED",
			"TRAIT_NODE_CHANGED",
			"TRAIT_TREE_CURRENCY_INFO_UPDATED",
			"PLAYER_TALENT_UPDATE",
			"ACTIVE_TALENT_GROUP_CHANGED",
			"PLAYER_LEVEL_UP",
			"SPELLS_CHANGED",
		}) do
			pcall(events.RegisterEvent, events, e)
		end
		C_Timer.After(3, function()
			ns.Refresh()
			ChatHint()
		end)
	elseif event == "PLAYER_LEVEL_UP" then
		C_Timer.After(1.5, ChatHint)
		ns.RequestRefresh()
	else
		ns.RequestRefresh()
	end
end)

SLASH_TALENTCOMPASS1 = "/tc"
SLASH_TALENTCOMPASS2 = "/talentcompass"
SlashCmdList.TALENTCOMPASS = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	if msg == "dump" then
		Dump()
	elseif msg == "reset" then
		if ns.ResetPanelPosition then
			ns.ResetPanelPosition()
		end
	elseif msg == "help" then
		ns.Print(ns.L.SLASH_HELP)
	else
		if ns.TogglePanel then
			ns.TogglePanel()
		end
	end
end
