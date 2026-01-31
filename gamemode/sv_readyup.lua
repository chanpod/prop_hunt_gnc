-- GNC: Ready-Up System
-- Server-side logic for player ready-up before first round starts
-- This only applies to round 1 - once the game starts, rounds proceed normally

PHX.ReadyUp = PHX.ReadyUp or {}

local ReadyPlayers = {}
local CountdownActive = false
local CountdownStartTime = 0
local FirstRoundStarted = false

-- Check if ready-up system should be active
function PHX.ReadyUp:IsActive()
	if not PHX:GetCVar("ph_readyup_enabled") then return false end
	if FirstRoundStarted then return false end
	return true
end

-- Reset ready states (called on map change)
function PHX.ReadyUp:Reset()
	print("[ReadyUp] Reset called!")

	ReadyPlayers = {}
	CountdownActive = false
	CountdownStartTime = 0
	FirstRoundStarted = false

	if timer.Exists("PHX.ReadyUp.Countdown") then
		timer.Remove("PHX.ReadyUp.Countdown")
	end

	SetGlobalBool("PHX.ReadyUp.Active", true)
	SetGlobalBool("PHX.ReadyUp.CountdownActive", false)
	SetGlobalFloat("PHX.ReadyUp.CountdownEnd", 0)
	SetGlobalInt("PHX.ReadyUp.ReadyCount", 0)
	SetGlobalInt("PHX.ReadyUp.TotalCount", 0)

	print("[ReadyUp] Reset complete - FirstRoundStarted=" .. tostring(FirstRoundStarted))
end

-- Mark first round as started (disables ready-up for rest of map)
function PHX.ReadyUp:MarkFirstRoundStarted()
	FirstRoundStarted = true
	SetGlobalBool("PHX.ReadyUp.Active", false)

	-- Clean up
	ReadyPlayers = {}
	CountdownActive = false

	if timer.Exists("PHX.ReadyUp.Countdown") then
		timer.Remove("PHX.ReadyUp.Countdown")
	end

	-- Notify clients
	net.Start("PHX.ReadyUp.StateUpdate")
		net.WriteUInt(0, 8) -- reset/disable state
	net.Broadcast()
end

-- Get eligible players (those on Props or Hunters team)
function PHX.ReadyUp:GetEligiblePlayers()
	local eligible = {}
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and (ply:Team() == TEAM_PROPS or ply:Team() == TEAM_HUNTERS) then
			table.insert(eligible, ply)
		end
	end
	return eligible
end

-- Get ready count
function PHX.ReadyUp:GetReadyCount()
	local count = 0
	for ply, ready in pairs(ReadyPlayers) do
		if IsValid(ply) and ready and (ply:Team() == TEAM_PROPS or ply:Team() == TEAM_HUNTERS) then
			count = count + 1
		end
	end
	return count
end

-- Check if player is ready
function PHX.ReadyUp:IsPlayerReady(ply)
	return ReadyPlayers[ply] == true
end

-- Set player ready state
function PHX.ReadyUp:SetPlayerReady(ply, ready)
	print("[ReadyUp] SetPlayerReady called for " .. ply:Nick() .. " = " .. tostring(ready))
	print("[ReadyUp] Player team: " .. tostring(ply:Team()))

	if not IsValid(ply) then
		print("[ReadyUp] Invalid player")
		return
	end
	if not PHX.ReadyUp:IsActive() then
		print("[ReadyUp] System not active")
		return
	end
	if ply:Team() ~= TEAM_PROPS and ply:Team() ~= TEAM_HUNTERS then
		print("[ReadyUp] Player not on Props or Hunters team")
		return
	end

	ReadyPlayers[ply] = ready
	print("[ReadyUp] Player ready state set")

	-- Broadcast update
	PHX.ReadyUp:BroadcastState()

	-- Check threshold
	PHX.ReadyUp:CheckThreshold()
end

-- Broadcast ready state to all clients
function PHX.ReadyUp:BroadcastState()
	local eligible = PHX.ReadyUp:GetEligiblePlayers()
	local readyCount = PHX.ReadyUp:GetReadyCount()
	local totalCount = #eligible

	SetGlobalInt("PHX.ReadyUp.ReadyCount", readyCount)
	SetGlobalInt("PHX.ReadyUp.TotalCount", totalCount)

	-- Send individual ready states
	net.Start("PHX.ReadyUp.StateUpdate")
		net.WriteUInt(1, 8) -- state update
		net.WriteUInt(readyCount, 8)
		net.WriteUInt(totalCount, 8)
		net.WriteBool(CountdownActive)
		if CountdownActive then
			local remaining = math.max(0, (CountdownStartTime + PHX:GetCVar("ph_readyup_countdown")) - CurTime())
			net.WriteFloat(remaining)
		end
		-- Write ready player list
		net.WriteUInt(#eligible, 8)
		for _, ply in ipairs(eligible) do
			net.WriteEntity(ply)
			net.WriteBool(ReadyPlayers[ply] == true)
		end
	net.Broadcast()
end

-- Check if threshold is met
function PHX.ReadyUp:CheckThreshold()
	print("[ReadyUp] CheckThreshold called")
	print("[ReadyUp] IsActive: " .. tostring(PHX.ReadyUp:IsActive()))
	print("[ReadyUp] CVar enabled: " .. tostring(PHX:GetCVar("ph_readyup_enabled")))
	print("[ReadyUp] FirstRoundStarted: " .. tostring(FirstRoundStarted))

	if not PHX.ReadyUp:IsActive() then
		print("[ReadyUp] Not active, returning")
		return
	end

	local eligible = PHX.ReadyUp:GetEligiblePlayers()
	local totalCount = #eligible
	local readyCount = PHX.ReadyUp:GetReadyCount()

	print("[ReadyUp] Eligible: " .. totalCount .. ", Ready: " .. readyCount)

	-- If anyone is ready and all eligible are ready, start immediately
	if readyCount > 0 and readyCount >= totalCount then
		print("[ReadyUp] 100% ready, starting immediately!")
		PHX.ReadyUp:StartImmediately()
		return
	end

	-- Otherwise check threshold for countdown (need at least 2 players)
	if totalCount < 2 then
		print("[ReadyUp] Less than 2 players, waiting...")
		return
	end

	local threshold = PHX:GetCVar("ph_readyup_threshold") or 80
	local requiredPercent = threshold / 100
	local required = math.ceil(totalCount * requiredPercent)

	print("[ReadyUp] Threshold check: " .. readyCount .. "/" .. required .. " needed")

	if readyCount >= required and not CountdownActive then
		print("[ReadyUp] Threshold met, starting countdown!")
		PHX.ReadyUp:StartCountdown()
	end
end

-- Start immediately (when 100% ready)
function PHX.ReadyUp:StartImmediately()
	print("[ReadyUp] StartImmediately called!")

	if not PHX.ReadyUp:IsActive() then
		print("[ReadyUp] StartImmediately aborted - not active")
		return
	end

	-- Cancel any existing countdown
	if timer.Exists("PHX.ReadyUp.Countdown") then
		timer.Remove("PHX.ReadyUp.Countdown")
	end

	print("[ReadyUp] Notifying players and starting game...")

	-- Notify all players
	for _, ply in ipairs(player.GetAll()) do
		ply:PHXChatInfo("NOTICE", "READYUP_ALL_READY")
	end

	-- Mark first round as about to start and trigger it
	PHX.ReadyUp:MarkFirstRoundStarted()

	-- Start the game
	timer.Simple(0.5, function()
		print("[ReadyUp] Starting round based game now!")
		if GAMEMODE and GAMEMODE.StartRoundBasedGame then
			GAMEMODE:StartRoundBasedGame()
		else
			print("[ReadyUp] ERROR: GAMEMODE.StartRoundBasedGame not found!")
		end
	end)
end

-- Start the countdown
function PHX.ReadyUp:StartCountdown()
	if CountdownActive then return end
	if not PHX.ReadyUp:IsActive() then return end

	CountdownActive = true
	CountdownStartTime = CurTime()
	local duration = PHX:GetCVar("ph_readyup_countdown") or 20

	SetGlobalBool("PHX.ReadyUp.CountdownActive", true)
	SetGlobalFloat("PHX.ReadyUp.CountdownEnd", CurTime() + duration)

	-- Notify all players
	for _, ply in ipairs(player.GetAll()) do
		ply:PHXChatInfo("NOTICE", "READYUP_COUNTDOWN_STARTED", duration)
	end

	-- Start countdown timer
	timer.Create("PHX.ReadyUp.Countdown", duration, 1, function()
		PHX.ReadyUp:CountdownComplete()
	end)

	-- Broadcast state
	PHX.ReadyUp:BroadcastState()
end

-- Countdown complete - allow round to start
function PHX.ReadyUp:CountdownComplete()
	if not PHX.ReadyUp:IsActive() then return end

	CountdownActive = false

	-- Notify all players
	for _, ply in ipairs(player.GetAll()) do
		ply:PHXChatInfo("NOTICE", "READYUP_STARTING")
	end

	-- Mark first round as about to start and trigger it
	PHX.ReadyUp:MarkFirstRoundStarted()

	-- Start the game
	timer.Simple(0.5, function()
		if GAMEMODE and GAMEMODE.StartRoundBasedGame then
			GAMEMODE:StartRoundBasedGame()
		end
	end)
end

-- Check if round can start (called by round controller)
function PHX.ReadyUp:CanStartRound()
	if not PHX:GetCVar("ph_readyup_enabled") then
		return true
	end

	-- If first round already happened, always allow
	if FirstRoundStarted then
		return true
	end

	-- Don't allow first round until ready-up completes
	return false
end

-- Network receiver for player ready toggle
net.Receive("PHX.ReadyUp.Toggle", function(len, ply)
	print("[ReadyUp] Toggle received from " .. (IsValid(ply) and ply:Nick() or "invalid"))

	if not IsValid(ply) then return end
	if not PHX.ReadyUp:IsActive() then
		print("[ReadyUp] Toggle ignored - system not active")
		return
	end

	local currentState = PHX.ReadyUp:IsPlayerReady(ply)
	print("[ReadyUp] Current state: " .. tostring(currentState) .. ", toggling to: " .. tostring(not currentState))

	PHX.ReadyUp:SetPlayerReady(ply, not currentState)

	-- Notify player
	if not currentState then
		ply:PHXChatInfo("NOTICE", "READYUP_YOU_READY")
	else
		ply:PHXChatInfo("NOTICE", "READYUP_YOU_UNREADY")
	end
end)

-- Hook: Player joined a team - broadcast update and auto-check threshold
hook.Add("PlayerChangedTeam", "PHX.ReadyUp.TeamChange", function(ply, oldTeam, newTeam)
	if not PHX.ReadyUp:IsActive() then return end

	-- Remove ready state if leaving a playing team
	if oldTeam == TEAM_PROPS or oldTeam == TEAM_HUNTERS then
		if newTeam ~= TEAM_PROPS and newTeam ~= TEAM_HUNTERS then
			ReadyPlayers[ply] = nil
		end
	end

	-- Broadcast updated state
	timer.Simple(0.1, function()
		if PHX.ReadyUp:IsActive() then
			PHX.ReadyUp:BroadcastState()
		end
	end)
end)

-- Hook: Remove player from ready list on disconnect
hook.Add("PlayerDisconnected", "PHX.ReadyUp.PlayerLeft", function(ply)
	if ReadyPlayers[ply] then
		ReadyPlayers[ply] = nil
		if PHX.ReadyUp:IsActive() then
			PHX.ReadyUp:BroadcastState()
			PHX.ReadyUp:CheckThreshold()
		end
	end
end)

-- Hook: Initialize ready system on map load
hook.Add("Initialize", "PHX.ReadyUp.Init", function()
	print("[ReadyUp] Initialize hook fired!")
	print("[ReadyUp] CVar enabled: " .. tostring(PHX:GetCVar("ph_readyup_enabled")))

	PHX.ReadyUp:Reset()

	-- Override CanStartRound
	local oldCanStartRound = GAMEMODE.CanStartRound
	GAMEMODE.CanStartRound = function(self, iNum)
		print("[ReadyUp] CanStartRound called for round " .. tostring(iNum))
		print("[ReadyUp] ReadyUp:CanStartRound() = " .. tostring(PHX.ReadyUp:CanStartRound()))

		-- First check ready-up system
		if not PHX.ReadyUp:CanStartRound() then
			print("[ReadyUp] Blocking round start - waiting for ready-up")
			return false
		end

		-- Then check original conditions
		if oldCanStartRound then
			return oldCanStartRound(self, iNum)
		end
		return true
	end

	print("[ReadyUp] CanStartRound override installed!")
end)

-- Hook: Send state to newly connected players
hook.Add("PlayerInitialSpawn", "PHX.ReadyUp.PlayerJoin", function(ply)
	if not PHX.ReadyUp:IsActive() then return end

	timer.Simple(1, function()
		if IsValid(ply) and PHX.ReadyUp:IsActive() then
			PHX.ReadyUp:BroadcastState()
		end
	end)
end)
