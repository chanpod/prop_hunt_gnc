-- GNC: Ready-Up System
-- Client-side UI for pre-game ready-up lobby
-- Only active before round 1 starts

PHX.ReadyUp = PHX.ReadyUp or {}

local ReadyPlayers = {}
local LocalReady = false
local CountdownActive = false
local TotalPlayers = 0
local ReadyCount = 0
local CursorEnabled = false
local LastF4Press = 0

-- Check if system is active (from server global)
function PHX.ReadyUp:IsActive()
	return GetGlobalBool("PHX.ReadyUp.Active", false)
end

-- Check if local player can ready up (on a playing team)
function PHX.ReadyUp:CanReadyUp()
	local ply = LocalPlayer()
	if not IsValid(ply) then return false end
	return ply:Team() == TEAM_PROPS or ply:Team() == TEAM_HUNTERS
end

-- Toggle ready state
function PHX.ReadyUp:ToggleReady()
	if not PHX.ReadyUp:IsActive() then return end
	if not PHX.ReadyUp:CanReadyUp() then return end

	net.Start("PHX.ReadyUp.Toggle")
	net.SendToServer()
	surface.PlaySound("buttons/button14.wav")
end

-- Enable/disable cursor
function PHX.ReadyUp:SetCursor(enabled)
	if enabled == CursorEnabled then return end
	CursorEnabled = enabled
	gui.EnableScreenClicker(enabled)
end

-- Network receiver for state updates
net.Receive("PHX.ReadyUp.StateUpdate", function()
	local msgType = net.ReadUInt(8)

	if msgType == 0 then
		-- Reset/disable
		ReadyPlayers = {}
		LocalReady = false
		CountdownActive = false
		PHX.ReadyUp:SetCursor(false)
		return
	end

	if msgType == 1 then
		-- State update
		ReadyCount = net.ReadUInt(8)
		TotalPlayers = net.ReadUInt(8)
		CountdownActive = net.ReadBool()
		if CountdownActive then
			net.ReadFloat() -- remaining time (we use globals instead)
		end

		local playerCount = net.ReadUInt(8)
		ReadyPlayers = {}
		for i = 1, playerCount do
			local ply = net.ReadEntity()
			local ready = net.ReadBool()
			if IsValid(ply) then
				ReadyPlayers[ply] = ready
				if ply == LocalPlayer() then
					LocalReady = ready
				end
			end
		end
	end
end)

-- Think hook for cursor management and key detection
hook.Add("Think", "PHX.ReadyUp.Think", function()
	-- Keep cursor active whenever ready-up is active (until game starts)
	local shouldShowCursor = PHX.ReadyUp:IsActive()
	PHX.ReadyUp:SetCursor(shouldShowCursor)

	-- F4 key detection (KEY_F4 = 88) - only if on a team
	if shouldShowCursor and PHX.ReadyUp:CanReadyUp() and input.IsKeyDown(KEY_F4) then
		if CurTime() - LastF4Press > 0.3 then -- Debounce
			LastF4Press = CurTime()
			PHX.ReadyUp:ToggleReady()
		end
	end
end)

-- Main HUD paint for ready-up lobby
hook.Add("HUDPaint", "PHX.ReadyUp.LobbyHUD", function()
	if not PHX.ReadyUp:IsActive() then return end

	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	local scrW, scrH = ScrW(), ScrH()
	local isOnTeam = PHX.ReadyUp:CanReadyUp()

	-- Main panel dimensions
	local panelW, panelH = 400, 300
	local panelX = scrW / 2 - panelW / 2
	local panelY = scrH / 2 - panelH / 2 + 100

	-- Draw main panel background
	draw.RoundedBox(12, panelX, panelY, panelW, panelH, Color(20, 20, 20, 230))
	draw.RoundedBoxEx(12, panelX, panelY, panelW, 50, Color(40, 80, 120, 255), true, true, false, false)

	-- Title
	draw.SimpleText(PHX:FTranslate("READYUP_TITLE") or "READY UP", "DermaLarge", panelX + panelW / 2, panelY + 25, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	-- Ready count
	local threshold = PHX:GetCVar("ph_readyup_threshold") or 80
	local required = math.max(1, math.ceil(TotalPlayers * (threshold / 100)))
	local countText = string.format("%d / %d %s", ReadyCount, TotalPlayers, PHX:FTranslate("READYUP_PLAYERS_READY") or "players ready")
	draw.SimpleText(countText, "DermaDefaultBold", panelX + panelW / 2, panelY + 70, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	local neededText = string.format(PHX:FTranslate("READYUP_NEEDED") or "(%d needed to start)", required)
	draw.SimpleText(neededText, "DermaDefault", panelX + panelW / 2, panelY + 90, Color(180, 180, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	-- Player list area
	local listY = panelY + 110
	local listH = 120
	draw.RoundedBox(6, panelX + 10, listY, panelW - 20, listH, Color(30, 30, 30, 200))

	-- Draw player list
	local row = 0
	local maxRows = 5
	for p, ready in pairs(ReadyPlayers) do
		if IsValid(p) and row < maxRows then
			local rowY = listY + 5 + row * 22
			local rowColor = ready and Color(50, 120, 50, 200) or Color(120, 50, 50, 200)
			draw.RoundedBox(4, panelX + 15, rowY, panelW - 30, 20, rowColor)

			local name = p:Nick()
			if #name > 25 then name = string.sub(name, 1, 22) .. "..." end
			draw.SimpleText(name, "DermaDefault", panelX + 25, rowY + 10, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			local status = ready and (PHX:FTranslate("READYUP_STATUS_READY") or "READY") or (PHX:FTranslate("READYUP_STATUS_NOT_READY") or "NOT READY")
			draw.SimpleText(status, "DermaDefaultBold", panelX + panelW - 25, rowY + 10, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

			row = row + 1
		end
	end

	if TotalPlayers > maxRows then
		draw.SimpleText("+" .. (TotalPlayers - maxRows) .. " more...", "DermaDefault", panelX + panelW / 2, listY + listH - 15, Color(150, 150, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	-- Button area
	local btnY = panelY + panelH - 90
	local btnX = panelX + 50
	local btnW = panelW - 100
	local btnH = 40

	local mx, my = gui.MousePos()

	if CountdownActive then
		-- Show countdown
		local countdownEnd = GetGlobalFloat("PHX.ReadyUp.CountdownEnd", 0)
		local remaining = math.max(0, math.ceil(countdownEnd - CurTime()))

		local pulse = math.abs(math.sin(CurTime() * 3)) * 55 + 200
		draw.RoundedBox(8, btnX, btnY, btnW, btnH, Color(50, 150, 50, 200))
		draw.SimpleText(string.format(PHX:FTranslate("READYUP_STARTING_IN") or "Starting in %d...", remaining), "DermaLarge", panelX + panelW / 2, btnY + 20, Color(255, 255, 255, pulse), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	elseif isOnTeam then
		-- Show ready button
		local isHovered = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH

		local btnColor
		if LocalReady then
			btnColor = isHovered and Color(180, 60, 60, 255) or Color(150, 50, 50, 200)
		else
			btnColor = isHovered and Color(60, 180, 60, 255) or Color(50, 150, 50, 200)
		end

		local btnText = LocalReady and (PHX:FTranslate("READYUP_UNREADY") or "CANCEL READY") or (PHX:FTranslate("READYUP_READY") or "READY UP!")

		draw.RoundedBox(8, btnX, btnY, btnW, btnH, btnColor)
		draw.SimpleText(btnText, "DermaLarge", panelX + panelW / 2, btnY + 12, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(PHX:FTranslate("READYUP_PRESS_KEY") or "Press F4 or click", "DermaDefault", panelX + panelW / 2, btnY + 30, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	else
		-- Not on a team yet - prompt to join
		draw.RoundedBox(8, btnX, btnY, btnW, btnH, Color(80, 80, 80, 200))
		draw.SimpleText(PHX:FTranslate("READYUP_JOIN_TEAM") or "Join a team to ready up", "DermaDefault", panelX + panelW / 2, btnY + 20, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	-- Change Team button (always visible)
	local teamBtnY = panelY + panelH - 42
	local teamBtnH = 32
	local isTeamHovered = mx >= btnX and mx <= btnX + btnW and my >= teamBtnY and my <= teamBtnY + teamBtnH
	local teamBtnColor = isTeamHovered and Color(80, 80, 120, 255) or Color(60, 60, 90, 200)

	draw.RoundedBox(6, btnX, teamBtnY, btnW, teamBtnH, teamBtnColor)
	draw.SimpleText(PHX:FTranslate("READYUP_CHANGE_TEAM") or "Change Team", "DermaDefaultBold", panelX + panelW / 2, teamBtnY + 16, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

-- Click detection for ready button and change team button
hook.Add("GUIMousePressed", "PHX.ReadyUp.Click", function(mouseCode, aimVec)
	if mouseCode ~= MOUSE_LEFT then return end
	if not PHX.ReadyUp:IsActive() then return end

	local scrW, scrH = ScrW(), ScrH()
	local panelW, panelH = 400, 300
	local panelX = scrW / 2 - panelW / 2
	local panelY = scrH / 2 - panelH / 2 + 100
	local btnX = panelX + 50
	local btnW = panelW - 100

	-- Ready button area
	local btnY = panelY + panelH - 90
	local btnH = 40

	-- Change team button area
	local teamBtnY = panelY + panelH - 42
	local teamBtnH = 32

	local mx, my = gui.MousePos()

	-- Check ready button click (only if on team and not in countdown)
	if PHX.ReadyUp:CanReadyUp() and not CountdownActive then
		if mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH then
			PHX.ReadyUp:ToggleReady()
			return
		end
	end

	-- Check change team button click
	if mx >= btnX and mx <= btnX + btnW and my >= teamBtnY and my <= teamBtnY + teamBtnH then
		if GAMEMODE and GAMEMODE.ShowTeam then
			GAMEMODE:ShowTeam()
		end
		return
	end
end)

-- Console command to toggle ready
concommand.Add("ph_ready", function()
	if not PHX.ReadyUp:IsActive() then
		print("[PHX] Ready-up is not active (only before first round).")
		return
	end
	if not PHX.ReadyUp:CanReadyUp() then
		print("[PHX] You must join a team first.")
		return
	end
	PHX.ReadyUp:ToggleReady()
end, nil, "Toggle your ready status")

-- Cleanup on disconnect
hook.Add("ShutDown", "PHX.ReadyUp.Cleanup", function()
	PHX.ReadyUp:SetCursor(false)
end)
