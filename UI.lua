local _, ns = ...
local L = ns.L
local T = ns.T

local PANEL_WIDTH = 400
local FLOAT_HEIGHT = 660
local CONTENT_WIDTH = PANEL_WIDTH - 62

local GOLD = { 1, 0.82, 0 }
local GREEN = { 0.25, 0.9, 0.35 }
local GREY = { 0.6, 0.6, 0.6 }
local RED = { 1, 0.3, 0.25 }
local WHITE = { 0.92, 0.9, 0.85 }

local ROLE_ATLAS = {
	DPS = "UI-LFG-RoleIcon-DPS",
	TANK = "UI-LFG-RoleIcon-Tank",
	HEAL = "UI-LFG-RoleIcon-Healer",
	LEVELING = "UI-LFG-RoleIcon-Generic",
}

local panel
local currentTab = 1

local function Color(fs, c)
	fs:SetTextColor(c[1], c[2], c[3])
end

---------------------------------------------------------------------------
-- Scrollable content builder
---------------------------------------------------------------------------

local Content = {}
Content.__index = Content

local function NewContent(parent)
	local self = setmetatable({}, Content)
	local scroll = CreateFrame("ScrollFrame", "TalentCompassScroll", parent, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 8, -8)
	scroll:SetPoint("BOTTOMRIGHT", -28, 8)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(CONTENT_WIDTH, 10)
	scroll:SetScrollChild(child)
	self.scroll, self.child = scroll, child
	self.fontPool = {}
	self.rowPool = {}
	self.used = {}
	self.y = 0
	return self
end

function Content:Clear()
	for _, widget in ipairs(self.used) do
		widget:Hide()
		widget:ClearAllPoints()
		if widget.isRow then
			table.insert(self.rowPool, widget)
		else
			table.insert(self.fontPool, widget)
		end
	end
	wipe(self.used)
	self.y = 0
end

function Content:Finish()
	self.child:SetHeight(math.max(10, self.y + 8))
	self.scroll:SetVerticalScroll(0)
	if self.scroll.UpdateScrollChildRect then
		self.scroll:UpdateScrollChildRect()
	end
end

function Content:Space(px)
	self.y = self.y + (px or 8)
end

function Content:Text(text, font, color, indent)
	local fs = table.remove(self.fontPool) or ns.CreateText(self.child, "OVERLAY")
	fs:SetFontObject(ns.Font(font or "GameFontHighlight"))
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("TOP")
	fs:SetWordWrap(true)
	fs:SetSpacing(2)
	fs:SetWidth(CONTENT_WIDTH - (indent or 0))
	fs:SetPoint("TOPLEFT", self.child, "TOPLEFT", indent or 0, -self.y)
	fs:SetText(text)
	Color(fs, color or WHITE)
	fs:Show()
	table.insert(self.used, fs)
	self.y = self.y + fs:GetStringHeight() + 4
	return fs
end

function Content:Header(text)
	self:Space(4)
	self:Text(text, "GameFontNormalLarge", GOLD)
	self:Space(2)
end

function Content:Bullets(items, numbered)
	for i, item in ipairs(items or {}) do
		local prefix = numbered and ("|cffffd100" .. i .. ".|r ") or "|cffffd100•|r "
		self:Text(prefix .. item, "GameFontHighlight", WHITE, 6)
		self:Space(2)
	end
end

local function CreateRow(parent)
	local row = CreateFrame("Button", nil, parent)
	row.isRow = true
	row:SetHeight(24)
	row.Bg = row:CreateTexture(nil, "BACKGROUND")
	row.Bg:SetAllPoints()
	row.Bg:SetColorTexture(1, 0.82, 0, 0.12)
	row.Hl = row:CreateTexture(nil, "HIGHLIGHT")
	row.Hl:SetAllPoints()
	row.Hl:SetColorTexture(1, 1, 1, 0.06)
	row.Level = ns.CreateText(row, "OVERLAY", "GameFontNormalSmall")
	row.Level:SetPoint("LEFT", 2, 0)
	row.Level:SetWidth(58)
	row.Level:SetJustifyH("LEFT")
	row.Icon = row:CreateTexture(nil, "ARTWORK")
	row.Icon:SetSize(20, 20)
	row.Icon:SetPoint("LEFT", 62, 0)
	row.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	row.Name = ns.CreateText(row, "OVERLAY", "GameFontHighlight")
	row.Name:SetPoint("LEFT", row.Icon, "RIGHT", 6, 0)
	row.Name:SetPoint("RIGHT", -52, 0)
	row.Name:SetJustifyH("LEFT")
	row.Name:SetWordWrap(false)
	row.Rank = ns.CreateText(row, "OVERLAY", "GameFontHighlightSmall")
	row.Rank:SetPoint("RIGHT", -4, 0)
	row.Check = row:CreateTexture(nil, "OVERLAY")
	row.Check:SetAtlas("common-icon-checkmark")
	row.Check:SetSize(14, 14)
	row.Check:SetPoint("RIGHT", row.Rank, "LEFT", -2, 0)
	row:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if self.spellID then
			GameTooltip:SetSpellByID(self.spellID)
		else
			GameTooltip:SetText(self.Name:GetText() or "")
		end
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", GameTooltip_Hide)
	return row
end

-- state: "done", "next", "partial", "todo", "missing", "off"
function Content:TalentRow(levelText, icon, name, rankText, state, spellID)
	local row = table.remove(self.rowPool) or CreateRow(self.child)
	row:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, -self.y)
	row:SetWidth(CONTENT_WIDTH)
	row.Level:SetText(levelText or "")
	row.Icon:SetTexture(icon or 134400)
	row.Name:SetText(name)
	row.Rank:SetText(rankText or "")
	row.spellID = spellID
	row.Bg:SetShown(state == "next")
	row.Check:SetShown(state == "done")
	row.Icon:SetDesaturated(state == "todo" or state == "missing")
	if state == "done" then
		Color(row.Name, GREEN)
		Color(row.Level, GREY)
	elseif state == "next" or state == "partial" then
		Color(row.Name, GOLD)
		Color(row.Level, GOLD)
	elseif state == "missing" or state == "off" then
		Color(row.Name, RED)
		Color(row.Level, GREY)
	else
		Color(row.Name, WHITE)
		Color(row.Level, GREY)
	end
	Color(row.Rank, state == "done" and GREEN or WHITE)
	row:Show()
	table.insert(self.used, row)
	self.y = self.y + 26
	return row
end

---------------------------------------------------------------------------
-- Tab renderers
---------------------------------------------------------------------------

local function LevelRange(first, last)
	if first == last then
		return L.LEVEL_SHORT:format(first)
	end
	return L.LEVEL_SHORT:format(first) .. "–" .. last
end

local function UpdateNextCard(plan, scan)
	local card = panel.NextCard
	local step = plan and plan.nextIndex and plan.steps[plan.nextIndex]
	if step then
		card.Icon:SetTexture(step.talent and step.talent.icon or 134400)
		card.Icon:SetDesaturated(step.talent == nil)
		card.Name:SetText(ns.TalentDisplayName(step.key, step.talent))
		local tree = step.talent and step.talent.treeName and (step.talent.treeName .. " · ") or ""
		card.Sub:SetText(tree .. L.LEVEL_SHORT:format(step.level) .. " · " .. step.rankAfter .. "/" .. step.maxRanks)
		card.spellID = step.talent and step.talent.spellID
	else
		card.Icon:SetTexture("Interface\\Icons\\Achievement_Level_60")
		card.Icon:SetDesaturated(false)
		card.Name:SetText(plan and L.BUILD_DONE or L.TREE_NOT_READY)
		card.Sub:SetText("")
		card.spellID = nil
	end

	local done = plan and plan.doneCount or 0
	local total = plan and plan.total or ns.TOTAL_POINTS
	panel.Progress:SetMinMaxValues(0, total)
	panel.Progress:SetValue(done)
	panel.Progress.Text:SetText(L.PROGRESS:format(done, total))
end

local function RenderTalents(c, build, plan, scan)

	if scan and scan.unspent > 0 then
		c:Text(L.UNSPENT:format(scan.unspent), "GameFontNormal", GREEN)
	elseif scan then
		local nextLevel = math.max(ns.FIRST_TALENT_LEVEL, UnitLevel("player") + 1)
		c:Text(L.NO_UNSPENT:format(nextLevel), "GameFontHighlightSmall", GREY)
	end

	if plan and #plan.missing > 0 then
		local names = {}
		for _, key in ipairs(plan.missing) do
			table.insert(names, ns.TalentDisplayName(key))
		end
		c:Text(L.MISSING:format(table.concat(names, ", ")), "GameFontHighlightSmall", RED)
	end

	c:Header(L.ORDER)
	local level = ns.FIRST_TALENT_LEVEL - 1
	local stepIndex = 1
	local before = {}
	for _, entry in ipairs(build.order) do
		local key, ranks = entry[1], entry[2] or 1
		local first, last = stepIndex, stepIndex + ranks - 1
		local talent = plan and plan.steps[first] and plan.steps[first].talent
		local from = before[key] or 0
		local to = from + ranks
		before[key] = to
		local state = "todo"
		if plan then
			local allDone, anyDone = true, false
			for i = first, last do
				if plan.steps[i].done then
					anyDone = true
				else
					allDone = false
				end
			end
			if allDone then
				state = "done"
			elseif plan.nextIndex and plan.nextIndex >= first and plan.nextIndex <= last then
				state = "next"
			elseif anyDone then
				state = "partial"
			end
			if scan and not talent then
				state = "missing"
			end
		end
		local maxRanks = (talent and talent.maxRanks) or build.target[key]
		c:TalentRow(
			LevelRange(level + first, level + last),
			talent and talent.icon,
			ns.TalentDisplayName(key, talent),
			(from + 1 == to and to or ((from + 1) .. ">" .. to)) .. "/" .. maxRanks,
			state,
			talent and talent.spellID
		)
		stepIndex = last + 1
	end

	if plan and #plan.offBuild > 0 then
		c:Header(L.OFF_BUILD)
		c:Text(L.OFF_BUILD_HINT, "GameFontHighlightSmall", GREY)
		for _, item in ipairs(plan.offBuild) do
			local t = item.talent
			c:TalentRow("", t.icon, t.name, "+" .. item.extra, "off", t.spellID)
		end
	end
end

local function RenderRotation(c, build)
	c:Header(L.ROTATION)
	c:Bullets(T(build.rotation), true)
end

local function RenderGear(c, build)
	c:Header(L.STATS)
	c:Text(T(build.stats) or "")
	c:Header(L.GEAR)
	c:Bullets(T(build.gear))
end

local function RenderTips(c, build)
	c:Header(L.TIPS)
	c:Bullets(T(build.tips))
	local data = ns.GetClassData()
	if data and data.changes then
		c:Header(L.ABOUT_CLASS)
		c:Text(T(data.changes))
	end
	c:Space(10)
	c:Text(L.DATA_NOTE, "GameFontDisableSmall", GREY)
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------

local function CreateBuildCard(parent, index)
	local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
	card:SetSize(PANEL_WIDTH - 36, 52)
	card:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	card.Icon = card:CreateTexture(nil, "ARTWORK")
	card.Icon:SetSize(38, 38)
	card.Icon:SetPoint("LEFT", 8, 0)
	card.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	card.IconBorder = card:CreateTexture(nil, "OVERLAY")
	card.IconBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
	card.IconBorder:SetPoint("CENTER", card.Icon, "CENTER", 0, 0)
	card.IconBorder:SetSize(62, 62)
	card.Name = ns.CreateText(card, "OVERLAY", "GameFontNormal")
	card.Name:SetPoint("TOPLEFT", card.Icon, "TOPRIGHT", 10, -2)
	card.Name:SetPoint("RIGHT", -34, 0)
	card.Name:SetJustifyH("LEFT")
	card.Name:SetWordWrap(false)
	card.Role = card:CreateTexture(nil, "OVERLAY")
	card.Role:SetSize(16, 16)
	card.Role:SetPoint("BOTTOMLEFT", card.Icon, "BOTTOMRIGHT", 8, 0)
	card.RoleText = ns.CreateText(card, "OVERLAY", "GameFontHighlightSmall")
	card.RoleText:SetPoint("LEFT", card.Role, "RIGHT", 4, 0)
	card.RoleText:SetPoint("RIGHT", -34, 0)
	card.RoleText:SetJustifyH("LEFT")
	card.RoleText:SetWordWrap(false)
	card.Check = card:CreateTexture(nil, "OVERLAY")
	card.Check:SetAtlas("common-icon-checkmark")
	card.Check:SetSize(20, 20)
	card.Check:SetPoint("RIGHT", -10, 0)
	card.Hl = card:CreateTexture(nil, "HIGHLIGHT")
	card.Hl:SetPoint("TOPLEFT", 4, -4)
	card.Hl:SetPoint("BOTTOMRIGHT", -4, 4)
	card.Hl:SetColorTexture(1, 0.82, 0, 0.08)
	card:SetScript("OnClick", function(self)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		ns.SetActiveBuild(self.build.id)
	end)
	card:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(T(self.build.name), 1, 0.82, 0)
		GameTooltip:AddLine(T(self.build.summary), 1, 1, 1, true)
		GameTooltip:Show()
	end)
	card:SetScript("OnLeave", GameTooltip_Hide)
	return card
end

local function BuildIcon(build, scan)
	if build.icon then
		return build.icon
	end
	-- Use the deepest talent of the build as its emblem.
	local data = ns.GetClassData()
	local bestKey, bestTier = nil, -1
	for key in pairs(build.target) do
		local meta = data.talents and data.talents[key]
		local tier = meta and meta.tier or 0
		if tier > bestTier then
			bestKey, bestTier = key, tier
		end
	end
	local talent = bestKey and ns.ResolveTalent(scan, bestKey)
	if talent and talent.icon then
		return talent.icon
	end
	local meta = bestKey and data.talents[bestKey]
	if meta and meta.spell and C_Spell and C_Spell.GetSpellTexture then
		return C_Spell.GetSpellTexture(meta.spell) or 134400
	end
	return 134400
end

local function SetTab(id)
	currentTab = id
	PanelTemplates_SetTab(panel, id)
	ns.RequestRefresh()
end

local function CreateCheckbox(parent, label, getter, setter)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetSize(24, 24)
	cb.Label = ns.CreateText(cb, "OVERLAY", "GameFontHighlightSmall")
	cb.Label:SetPoint("LEFT", cb, "RIGHT", 2, 1)
	cb.getLabel = label
	cb:HookScript("OnShow", function(self)
		self:SetChecked(getter())
	end)
	cb:SetScript("OnClick", function(self)
		setter(self:GetChecked() and true or false)
		ns.RequestRefresh()
	end)
	return cb
end

local function CreatePanel()
	panel = CreateFrame("Frame", "TalentCompassPanel", UIParent, "PortraitFrameTemplate")
	panel:SetSize(PANEL_WIDTH, FLOAT_HEIGHT)
	panel:SetToplevel(true)
	panel:SetMovable(true)
	panel:SetClampedToScreen(true)
	panel:EnableMouse(true)
	panel:Hide()
	if panel.SetTitle then
		panel:SetTitle(L.TITLE)
	end
	if panel.SetPortraitToClassIcon then
		panel:SetPortraitToClassIcon(ns.GetPlayerClass())
	end
	panel.CloseButton:SetScript("OnClick", function()
		TalentCompassDB.panelShown = false
		panel:Hide()
	end)

	local drag = panel.TitleContainer or panel
	drag:EnableMouse(true)
	drag:RegisterForDrag("LeftButton")
	drag:SetScript("OnDragStart", function()
		if not panel.docked then
			panel:StartMoving()
		end
	end)
	drag:SetScript("OnDragStop", function()
		panel:StopMovingOrSizing()
		if not panel.docked then
			local point, _, relPoint, x, y = panel:GetPoint()
			TalentCompassDB.position = { point, relPoint, x, y }
		end
	end)

	-- Language dropdown
	local lang = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
	lang:SetWidth(120)
	lang:SetPoint("TOPRIGHT", -14, -28)
	lang:SetupMenu(function(_, root)
		local function IsSelected(value)
			return TalentCompassDB.lang == value
		end
		local function SetSelected(value)
			TalentCompassDB.lang = value
			ns.RefreshStatic()
			ns.RequestRefresh()
		end
		root:CreateRadio(ns.strings[ns.GetLanguage()].LANG_AUTO, IsSelected, SetSelected, "auto")
		root:CreateRadio("English", IsSelected, SetSelected, "en")
		root:CreateRadio("Русский", IsSelected, SetSelected, "ru")
	end)
	panel.LangDropdown = lang

	panel.BuildsLabel = ns.CreateText(panel, "OVERLAY", "GameFontNormal")
	panel.BuildsLabel:SetPoint("TOPLEFT", 64, -34)

	panel.cards = {}
	for i = 1, 3 do
		local card = CreateBuildCard(panel, i)
		card:SetPoint("TOPLEFT", 18, -62 - (i - 1) * 56)
		panel.cards[i] = card
	end

	panel.Empty = ns.CreateText(panel, "OVERLAY", "GameFontHighlight")
	panel.Empty:SetPoint("TOP", 0, -90)

	-- Next talent card + progress bar
	local nextCard = CreateFrame("Button", nil, panel)
	nextCard:SetSize(PANEL_WIDTH - 36, 46)
	nextCard:SetPoint("TOPLEFT", 18, -234)
	nextCard.Glow = nextCard:CreateTexture(nil, "BACKGROUND")
	nextCard.Glow:SetAllPoints()
	nextCard.Glow:SetColorTexture(1, 0.82, 0, 0.07)
	nextCard.Icon = nextCard:CreateTexture(nil, "ARTWORK")
	nextCard.Icon:SetSize(38, 38)
	nextCard.Icon:SetPoint("LEFT", 6, 0)
	nextCard.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	nextCard.IconGlow = nextCard:CreateTexture(nil, "OVERLAY")
	nextCard.IconGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	nextCard.IconGlow:SetBlendMode("ADD")
	nextCard.IconGlow:SetVertexColor(1, 0.85, 0.2)
	nextCard.IconGlow:SetSize(72, 72)
	nextCard.IconGlow:SetPoint("CENTER", nextCard.Icon)
	nextCard.Label = ns.CreateText(nextCard, "OVERLAY", "GameFontNormalSmall")
	nextCard.Label:SetPoint("TOPLEFT", nextCard.Icon, "TOPRIGHT", 10, 0)
	nextCard.Name = ns.CreateText(nextCard, "OVERLAY", "GameFontHighlightLarge")
	nextCard.Name:SetPoint("TOPLEFT", nextCard.Label, "BOTTOMLEFT", 0, -2)
	nextCard.Name:SetPoint("RIGHT", -4, 0)
	nextCard.Name:SetJustifyH("LEFT")
	nextCard.Name:SetWordWrap(false)
	nextCard.Sub = ns.CreateText(nextCard, "OVERLAY", "GameFontHighlightSmall")
	nextCard.Sub:SetPoint("TOPLEFT", nextCard.Name, "BOTTOMLEFT", 0, -2)
	Color(nextCard.Sub, GREY)
	nextCard:SetScript("OnEnter", function(self)
		if self.spellID then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetSpellByID(self.spellID)
			GameTooltip:Show()
		end
	end)
	nextCard:SetScript("OnLeave", GameTooltip_Hide)
	panel.NextCard = nextCard

	local progress = CreateFrame("StatusBar", nil, panel, "BackdropTemplate")
	progress:SetSize(PANEL_WIDTH - 40, 14)
	progress:SetPoint("TOPLEFT", nextCard, "BOTTOMLEFT", 2, -6)
	progress:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	progress:SetStatusBarColor(0.85, 0.65, 0.1)
	progress:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	progress:SetBackdropColor(0, 0, 0, 0.6)
	progress:SetBackdropBorderColor(0.4, 0.33, 0.15, 1)
	progress.Text = ns.CreateText(progress, "OVERLAY", "GameFontHighlightSmall")
	progress.Text:SetPoint("CENTER", 0, 0)
	panel.Progress = progress

	-- Tabs
	local tabKeys = { "TAB_TALENTS", "TAB_ROTATION", "TAB_GEAR", "TAB_TIPS" }
	panel.Tabs = {}
	for i, key in ipairs(tabKeys) do
		local tab = CreateFrame("Button", "TalentCompassPanelTab" .. i, panel, "PanelTopTabButtonTemplate")
		tab:SetID(i)
		tab.textKey = key
		tab:SetText(L[key])
		if i == 1 then
			tab:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -312)
		else
			tab:SetPoint("LEFT", panel.Tabs[i - 1], "RIGHT", -6, 0)
		end
		tab:SetScript("OnClick", function(self)
			PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
			SetTab(self:GetID())
		end)
		panel.Tabs[i] = tab
	end
	PanelTemplates_SetNumTabs(panel, #tabKeys)
	PanelTemplates_SetTab(panel, 1)

	local inset = CreateFrame("Frame", nil, panel, "InsetFrameTemplate")
	inset:SetPoint("TOPLEFT", 10, -340)
	inset:SetPoint("BOTTOMRIGHT", -8, 40)
	panel.Inset = inset
	panel.content = NewContent(inset)

	-- Options
	panel.HighlightCheck = CreateCheckbox(panel, "HIGHLIGHT",
		function() return TalentCompassDB.highlight end,
		function(v) TalentCompassDB.highlight = v end)
	panel.HighlightCheck:SetPoint("BOTTOMLEFT", 12, 10)
	panel.ChatCheck = CreateCheckbox(panel, "CHAT_HINTS",
		function() return TalentCompassDB.chatHints end,
		function(v) TalentCompassDB.chatHints = v end)
	panel.ChatCheck:SetPoint("BOTTOMLEFT", 200, 10)

	tinsert(UISpecialFrames, "TalentCompassPanel")
	panel:SetScript("OnShow", function()
		ns.RefreshStatic()
		ns.RequestRefresh()
	end)
	ns.RefreshStatic()
end

-- Texts that only change with language.
function ns.RefreshStatic()
	if not panel then
		return
	end
	if panel.SetTitle then
		panel:SetTitle(L.TITLE)
	end
	panel.BuildsLabel:SetText(L.CHOOSE_BUILD)
	panel.NextCard.Label:SetText(L.NEXT_TALENT)
	for _, tab in ipairs(panel.Tabs) do
		tab:SetText(L[tab.textKey])
		PanelTemplates_TabResize(tab, 6)
	end
	panel.HighlightCheck.Label:SetText(L.HIGHLIGHT)
	panel.ChatCheck.Label:SetText(L.CHAT_HINTS)
	panel.LangDropdown:GenerateMenu()
	if panel.toggleButton then
		panel.toggleButton:SetText(L.BUILDS_BUTTON)
	end
end

local function UpdatePanel(plan, build, scan)
	if not panel or not panel:IsVisible() then
		return
	end
	local data = ns.GetClassData()
	local builds = data and data.builds or {}
	panel.Empty:SetShown(#builds == 0)
	panel.Empty:SetText(L.NO_DATA)

	for i, card in ipairs(panel.cards) do
		local b = builds[i]
		card:SetShown(b ~= nil)
		if b then
			card.build = b
			card.Icon:SetTexture(BuildIcon(b, scan))
			card.Name:SetText(T(b.name))
			card.Role:SetAtlas(ROLE_ATLAS[b.role] or ROLE_ATLAS.DPS)
			local roleText = L["ROLE_" .. (b.role or "DPS")]
			if scan and scan.spent > 0 then
				roleText = roleText .. " · |cff80ff80" .. L.MATCH:format(ns.MatchBuild(b, scan).percent) .. "|r"
			end
			card.RoleText:SetText(roleText .. " — " .. (T(b.summary) or ""))
			local selected = build and b.id == build.id
			card.Check:SetShown(selected)
			if selected then
				card:SetBackdropBorderColor(1, 0.82, 0, 1)
				card.Name:SetTextColor(1, 0.82, 0)
			else
				card:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
				card.Name:SetTextColor(0.9, 0.9, 0.9)
			end
		end
	end

	UpdateNextCard(plan, scan)
	local c = panel.content
	c:Clear()
	if build then
		if currentTab == 1 then
			RenderTalents(c, build, plan, scan)
		elseif currentTab == 2 then
			RenderRotation(c, build)
		elseif currentTab == 3 then
			RenderGear(c, build)
		else
			RenderTips(c, build)
		end
	end
	c:Finish()
end

ns.OnUpdate(UpdatePanel)

---------------------------------------------------------------------------
-- Docking to the talent window
---------------------------------------------------------------------------

local function Float()
	panel.docked = false
	panel:SetParent(UIParent)
	panel:SetScale(1)
	panel:SetFrameStrata("HIGH")
	panel:ClearAllPoints()
	local pos = TalentCompassDB.position
	if pos then
		panel:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
	else
		panel:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
	end
	panel:SetHeight(FLOAT_HEIGHT)
end

local function Dock()
	local host = PlayerSpellsFrame
	panel.docked = true
	panel:SetParent(host)
	panel:SetScale(1)
	panel:SetFrameStrata(host:GetFrameStrata())
	panel:SetFrameLevel(host:GetFrameLevel() + 1500)
	panel:ClearAllPoints()
	local scale = host:GetEffectiveScale()
	local roomRight = (UIParent:GetRight() * UIParent:GetEffectiveScale()) - ((host:GetRight() or 0) * scale)
	if roomRight >= PANEL_WIDTH * scale then
		panel:SetPoint("TOPLEFT", host, "TOPRIGHT", 2, 0)
	else
		-- Not enough screen space: overlay the right part of the talent window.
		panel:SetPoint("TOPRIGHT", host, "TOPRIGHT", -4, -24)
	end
	panel:SetHeight(math.max(FLOAT_HEIGHT, host:GetHeight()))
end

function ns.ShowPanel()
	if not panel then
		CreatePanel()
	end
	local talentsFrame = ns.GetTalentsFrame()
	if talentsFrame and talentsFrame:IsVisible() then
		Dock()
	else
		Float()
	end
	panel:Show()
end

function ns.TogglePanel()
	if panel and panel:IsVisible() then
		TalentCompassDB.panelShown = false
		panel:Hide()
	else
		TalentCompassDB.panelShown = true
		ns.ShowPanel()
	end
end

function ns.ResetPanelPosition()
	TalentCompassDB.position = nil
	if panel and panel:IsShown() and not panel.docked then
		Float()
	end
end

function ns.OnTalentsFrameReady(talentsFrame)
	if not panel then
		CreatePanel()
	end

	local button = CreateFrame("Button", nil, talentsFrame, "UIPanelButtonTemplate")
	button:SetSize(110, 22)
	button:SetText(L.BUILDS_BUTTON)
	if talentsFrame.SearchBox then
		button:SetPoint("RIGHT", talentsFrame.SearchBox, "LEFT", -14, 0)
	else
		button:SetPoint("TOPRIGHT", talentsFrame, "TOPRIGHT", -200, -8)
	end
	button:SetFrameLevel(talentsFrame:GetFrameLevel() + 1000)
	button.Icon = button:CreateTexture(nil, "OVERLAY")
	button.Icon:SetTexture("Interface\\Icons\\INV_Misc_Book_11")
	button.Icon:SetSize(16, 16)
	button.Icon:SetPoint("LEFT", 6, 0)
	button:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		ns.TogglePanel()
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(L.TITLE, 1, 0.82, 0)
		GameTooltip:AddLine(L.BUILDS_BUTTON_TOOLTIP, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	panel.toggleButton = button

	talentsFrame:HookScript("OnShow", function()
		if TalentCompassDB.panelShown then
			ns.ShowPanel()
		end
	end)
	talentsFrame:HookScript("OnHide", function()
		if panel.docked then
			panel:Hide()
		end
	end)
	if talentsFrame:IsVisible() and TalentCompassDB.panelShown then
		ns.ShowPanel()
	end
end
