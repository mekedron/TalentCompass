local _, ns = ...

-- Draws markers over talent buttons of PlayerSpellsFrame.TalentsFrame:
--   * next talent of the active build: pulsing gold glow + "NEXT" label
--   * other unfinished build talents: soft gold frame + target rank badge
--   * finished build talents: green check
--   * ranks outside the build: red badge

local GLOW_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"

local overlays = {}
local active = {}

local function CreateOverlay()
	local f = CreateFrame("Frame")

	f.Glow = f:CreateTexture(nil, "OVERLAY")
	f.Glow:SetTexture(GLOW_TEXTURE)
	f.Glow:SetBlendMode("ADD")
	f.Glow:SetPoint("CENTER")

	f.Pulse = f.Glow:CreateAnimationGroup()
	f.Pulse:SetLooping("BOUNCE")
	local alpha = f.Pulse:CreateAnimation("Alpha")
	alpha:SetFromAlpha(1)
	alpha:SetToAlpha(0.35)
	alpha:SetDuration(0.7)
	alpha:SetSmoothing("IN_OUT")

	f.Label = ns.CreateText(f, "OVERLAY", "GameFontNormalSmall")
	f.Label:SetPoint("BOTTOM", f, "TOP", 0, 4)
	f.Label:SetTextColor(1, 0.82, 0)
	f.Label:SetShadowOffset(1, -1)

	f.Arrow = f:CreateTexture(nil, "OVERLAY")
	f.Arrow:SetAtlas("common-dropdown-icon-next")
	f.Arrow:SetRotation(-math.pi / 2)
	f.Arrow:SetSize(14, 14)
	f.Arrow:SetPoint("BOTTOM", f.Label, "TOP", 0, 0)

	f.Badge = CreateFrame("Frame", nil, f, "BackdropTemplate")
	f.Badge:SetSize(26, 16)
	f.Badge:SetPoint("TOPRIGHT", f, "TOPRIGHT", 8, 8)
	f.Badge:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1,
	})
	f.Badge.Text = ns.CreateText(f.Badge, "OVERLAY", "GameFontHighlightSmall")
	f.Badge.Text:SetPoint("CENTER", 0, 0)

	f.Check = f:CreateTexture(nil, "OVERLAY")
	f.Check:SetAtlas("common-icon-checkmark")
	f.Check:SetSize(16, 16)
	f.Check:SetPoint("TOPRIGHT", f, "TOPRIGHT", 6, 6)

	return f
end

local function AcquireOverlay()
	local f = table.remove(overlays) or CreateOverlay()
	table.insert(active, f)
	return f
end

local function ReleaseAll()
	for _, f in ipairs(active) do
		f.Pulse:Stop()
		f:Hide()
		f:ClearAllPoints()
		f:SetParent(nil)
		table.insert(overlays, f)
	end
	wipe(active)
end

local function SetBadge(f, text, r, g, b)
	f.Badge.Text:SetText(text)
	f.Badge:SetWidth(math.max(18, f.Badge.Text:GetStringWidth() + 8))
	f.Badge:SetBackdropColor(0.05, 0.04, 0.02, 0.9)
	f.Badge:SetBackdropBorderColor(r, g, b, 1)
	f.Badge.Text:SetTextColor(r, g, b)
	f.Badge:Show()
end

local function Attach(f, button)
	f:SetParent(button)
	f:SetFrameLevel(button:GetFrameLevel() + 20)
	f:SetAllPoints(button)
	local w, h = button:GetSize()
	f.Glow:SetSize(w * 1.85, h * 1.85)
	f.Label:Hide()
	f.Arrow:Hide()
	f.Badge:Hide()
	f.Check:Hide()
	f.Glow:Show()
	f:Show()
end

local function Update(plan)
	ReleaseAll()
	local frame = ns.GetTalentsFrame()
	if not frame or not frame:IsVisible() or not TalentCompassDB.highlight or not plan then
		return
	end
	if frame.IsInspecting and frame:IsInspecting() then
		return
	end
	if not frame.EnumerateAllTalentButtons then
		return
	end

	local offBuild = {}
	for _, item in ipairs(plan.offBuild) do
		offBuild[item.talent.nodeID] = item
	end

	for button in frame:EnumerateAllTalentButtons() do
		local nodeID = button.GetNodeID and button:GetNodeID()
		local target = nodeID and plan.nodeTargets[nodeID]
		local wrong = nodeID and offBuild[nodeID]
		if nodeID and (target or wrong) and button:IsShown() then
			local f = AcquireOverlay()
			Attach(f, button)
			local rank = (target and target.talent.rank) or (wrong and wrong.talent.rank) or 0

			if nodeID == plan.nextNodeID then
				f.Glow:SetVertexColor(1, 0.85, 0.2)
				f.Glow:SetAlpha(1)
				f.Pulse:Play()
				f.Label:SetText(ns.L.NEXT_BADGE)
				f.Label:Show()
				f.Arrow:Show()
				SetBadge(f, rank .. "/" .. target.target, 1, 0.82, 0)
			elseif wrong then
				f.Glow:SetVertexColor(1, 0.2, 0.15)
				f.Glow:SetAlpha(0.8)
				SetBadge(f, "+" .. wrong.extra, 1, 0.3, 0.25)
			elseif rank >= target.target then
				f.Glow:Hide()
				f.Check:Show()
			else
				f.Glow:SetVertexColor(1, 0.75, 0.25)
				f.Glow:SetAlpha(0.45)
				SetBadge(f, rank .. "/" .. target.target, 0.95, 0.8, 0.45)
			end
		end
	end
end

ns.OnUpdate(Update)

local function Hook()
	local frame = ns.GetTalentsFrame()
	if not frame or frame.TalentCompassHooked then
		return
	end
	frame.TalentCompassHooked = true
	frame:HookScript("OnShow", ns.RequestRefresh)
	frame:HookScript("OnHide", ReleaseAll)
	EventRegistry:RegisterCallback("TalentFrameBase.ButtonsUpdated", ns.RequestRefresh, ns)
	EventRegistry:RegisterCallback("TalentFrameBase.ConfigUpdated", ns.RequestRefresh, ns)
	EventRegistry:RegisterCallback("TalentButton.OnClick", ns.RequestRefresh, ns)
	if frame.UpdateTreeCurrencyInfo then
		hooksecurefunc(frame, "UpdateTreeCurrencyInfo", ns.RequestRefresh)
	end
	if ns.OnTalentsFrameReady then
		ns.OnTalentsFrameReady(frame)
	end
end

EventUtil.ContinueOnAddOnLoaded("Blizzard_PlayerSpells", Hook)
