/*  ------------------
	Auto Taunt Section
	------------------  */

-- GNC: Stationary tracking for experimental stationary taunt feature
local PlayerStationaryData = {}

local function IsPlayerStationary(ply)
	if !PHX:GetCVar("ph_exp_stationary_taunt_enabled") then
		if IsValid(ply) then ply:SetNWBool("PHX.IsStationary", false) end
		return false
	end
	if !IsValid(ply) then return false end

	local steamId = ply:SteamID()
	local currentPos = ply:GetPos()
	local currentTime = CurTime()

	if !PlayerStationaryData[steamId] then
		PlayerStationaryData[steamId] = { pos = currentPos, lastMoveTime = currentTime }
		ply:SetNWBool("PHX.IsStationary", false)
		return false
	end

	local data = PlayerStationaryData[steamId]
	local moveDist = currentPos:Distance(data.pos)

	-- If player moved more than 5 units, reset timer
	if moveDist > 5 then
		data.pos = currentPos
		data.lastMoveTime = currentTime
		ply:SetNWBool("PHX.IsStationary", false)
		return false
	end

	-- Check if stationary long enough
	local threshold = PHX:GetCVar("ph_exp_stationary_threshold") or 30
	local isStationary = (currentTime - data.lastMoveTime) >= threshold
	ply:SetNWBool("PHX.IsStationary", isStationary)
	return isStationary
end

local function GetTauntWithMinDuration(minDuration)
	local taunts = PHX.CachedTaunts[TEAM_PROPS]
	if table.IsEmpty(taunts) then return nil end

	-- Build list of taunts meeting duration requirement
	local validTaunts = {}
	for _, taunt in pairs(taunts) do
		local duration = PHX:SoundDuration(taunt)
		if duration and duration >= minDuration then
			table.insert(validTaunts, taunt)
		end
	end

	-- If no taunts meet the requirement, fall back to any taunt
	if #validTaunts == 0 then
		return table.Random(taunts)
	end

	return table.Random(validTaunts)
end

-- GNC: Check if panic mode is active (round timer running low)
local function IsPanicModeActive()
	if !PHX:GetCVar("ph_autotaunt_panic_enabled") then return false end
	local roundEndTime = GetGlobalFloat("RoundEndTime", 0)
	if roundEndTime == 0 then return false end
	local timeLeft = roundEndTime - CurTime()
	local threshold = PHX:GetCVar("ph_autotaunt_panic_threshold") or 60
	return timeLeft > 0 and timeLeft <= threshold
end

local function TauntTimeLeft(ply)
	-- Always return 1 when the conditions are not met
	if !IsValid(ply) || !ply:Alive() || ply:Team() != TEAM_PROPS then return 1; end

	local lastTauntTime = ply:GetLastTauntTime( "LastTauntTime" )
	local baseDelay = PHX:GetCVar( "ph_autotaunt_delay" )

	-- GNC: Panic mode takes priority - overrides everything
	if IsPanicModeActive() then
		baseDelay = PHX:GetCVar("ph_autotaunt_panic_delay") or 10
	-- GNC: Apply stationary delay multiplier ONLY if NOT in panic mode
	elseif IsPlayerStationary(ply) then
		local mult = PHX:GetCVar("ph_exp_stationary_delay_mult") or 0.5
		baseDelay = baseDelay * mult
	end

	local nextTauntTime = lastTauntTime + baseDelay
	local currentTime = CurTime()
	return nextTauntTime - currentTime
end

local function AutoTauntThink()

	if PHX:GetCVar( "ph_autotaunt_enabled" ) then

		for _, ply in ipairs(team.GetPlayers(TEAM_PROPS)) do
			local timeLeft = TauntTimeLeft(ply)

			if IsValid(ply) && ply:Alive() && ply:Team() == TEAM_PROPS && timeLeft <= 0 then
				local pitch = 100
				local pitchRandEnabled 	= ply:GetInfoNum( "ph_cl_pitch_apply_random", 0 )
				local pitchlevel 		= ply:GetInfoNum( "ph_cl_pitch_level", 100 )
				local isRandomized 		= ply:GetInfoNum( "ph_cl_pitch_randomized_random", 0 )

				-- GNC: Select taunt based on stationary state (but NOT during panic mode)
				local rand_taunt
				if !IsPanicModeActive() and IsPlayerStationary(ply) then
					local minDuration = PHX:GetCVar("ph_exp_stationary_min_duration") or 5
					rand_taunt = GetTauntWithMinDuration(minDuration)
				else
					rand_taunt = table.Random(PHX.CachedTaunts[TEAM_PROPS])
				end

				if !isstring(rand_taunt) then rand_taunt = tostring(rand_taunt); end

				-- Play random HL2 cheer sound because taunt is empty.
				if (TAUNT_FALLBACK) then
					PHX:PlayTaunt( ply, "vo/coast/odessa/male01/nlo_cheer0"..math.random(1,4)..".wav", 0, 100, 0, "LastTauntTime" )
					return;
				end

				PHX:PlayTaunt( ply, rand_taunt, pitchRandEnabled, pitchlevel, isRandomized, "LastTauntTime" )

			end
		end

	end
end
timer.Create("PHX.AutoTauntThinkTimer", 1, 0, AutoTauntThink)

-- GNC: Clean up stationary data when player disconnects
hook.Add("PlayerDisconnected", "PHX.CleanupStationaryData", function(ply)
	if IsValid(ply) then
		PlayerStationaryData[ply:SteamID()] = nil
	end
end)

/*  --------------------------
	Proximity Panic Section
	--------------------------  */

-- GNC: Track player movement state for proximity panic
local PlayerProximityData = {}
local RUNNING_SPEED_THRESHOLD = 100 -- units per second to be considered "running"

local function GetNearestHunterDistance(ply)
	if !IsValid(ply) then return 99999 end

	local propPos = ply:GetPos()
	local nearestDist = 99999

	for _, hunter in ipairs(team.GetPlayers(TEAM_HUNTERS)) do
		if IsValid(hunter) and hunter:Alive() then
			local dist = propPos:Distance(hunter:GetPos())
			if dist < nearestDist then
				nearestDist = dist
			end
		end
	end

	return nearestDist
end

local function ProximityPanicThink()
	if !PHX:GetCVar("ph_exp_proximity_panic_enabled") then return end

	local triggerDistance = PHX:GetCVar("ph_exp_proximity_panic_distance") or 200
	local cooldown = PHX:GetCVar("ph_exp_proximity_panic_cooldown") or 10
	local panicSound = PHX:GetCVar("ph_exp_proximity_panic_sound") or "taunts/props/nein.wav"
	local currentTime = CurTime()

	for _, ply in ipairs(team.GetPlayers(TEAM_PROPS)) do
		if !IsValid(ply) or !ply:Alive() then continue end

		local steamId = ply:SteamID()
		local currentSpeed = ply:GetVelocity():Length2D() -- Horizontal speed only

		-- Initialize tracking data
		if !PlayerProximityData[steamId] then
			PlayerProximityData[steamId] = {
				wasRunning = false,
				lastPanicTime = 0
			}
		end

		local data = PlayerProximityData[steamId]
		local isRunning = currentSpeed > RUNNING_SPEED_THRESHOLD

		-- Detect transition from not running to running
		if isRunning and !data.wasRunning then
			-- Check cooldown
			if (currentTime - data.lastPanicTime) >= cooldown then
				-- Check if hunter is nearby
				local hunterDist = GetNearestHunterDistance(ply)
				if hunterDist <= triggerDistance then
					-- Play panic sound!
					ply:EmitSound(panicSound, 90, 100)
					data.lastPanicTime = currentTime
				end
			end
		end

		data.wasRunning = isRunning
	end
end
timer.Create("PHX.ProximityPanicTimer", 0.25, 0, ProximityPanicThink)

-- GNC: Clean up proximity data when player disconnects
hook.Add("PlayerDisconnected", "PHX.CleanupProximityData", function(ply)
	if IsValid(ply) then
		PlayerProximityData[ply:SteamID()] = nil
	end
end)

/*  --------------------
	Custom Taunt Section
	--------------------   */

-- Validity check to prevent some sort of spam
local function IsDelayed(ply)
	local delay = ply:GetLastTauntTime( "CLastTauntTime" ) + PHX:GetCVar( "ph_customtaunts_delay" )
	return { delay > CurTime(), delay - CurTime() }
end
local function CheckValidity( tauntName, sndFile, plyTeam )
	return file.Exists("sound/"..sndFile, "GAME") and (PHX.CachedTaunts[plyTeam][tauntName] ~= nil) and table.HasValue( PHX.CachedTaunts[plyTeam], sndFile )
end

local function SetLastTauntDelay( ply )
	ply:SetLastTauntTime( "CLastTauntTime", CurTime() )
	ply:SetLastTauntTime( "LastTauntTime", CurTime() )
end

net.Receive("CL2SV_PlayThisTaunt", function(len, ply)
	local name		= net.ReadString()
	local snd 		= net.ReadString()
	local bool 		= net.ReadBool()	-- enable fake taunt
	
	local isPitchEnabled = PHX:GetCVar( "ph_taunt_pitch_enable" )
	
	if (ply and IsValid(ply)) then
	
		local delay 		= IsDelayed(ply)
		local isDelay 		= delay[1]
		local TauntTime 	= delay[2]
		local playerTeam	= ply:Team()
        local plPitchOn     = ply:GetInfoNum( "ph_cl_pitch_taunt_enable", 0 )
		local plApplyOnFake = ply:GetInfoNum( "ph_cl_pitch_apply_fake_prop", 0 )
        local plPitchRandomized = ply:GetInfoNum( "ph_cl_pitch_randomized", 0 )
        local randFakePitch = ply:GetInfoNum( "ph_cl_pitch_fake_prop_random", 0 )
		local desiredPitch	= ply:GetInfoNum( "ph_cl_pitch_level", 100 )
		local pitch			= 100
	
		if !isDelay then
			if bool then --if it's Fake Taunt
				-- dont play if taunt is empty
				if (TAUNT_FALLBACK) then MsgN("warning: supressing fake taunt: taunt table is empty"); return; end

				if PHX:GetCVar( "ph_randtaunt_map_prop_enable" ) then
					local Count = ply:GetTauntRandMapPropCount()
                    
                    if ply:Team() ~= TEAM_PROPS then
                        ply:PHXChatInfo( "ERROR", "PHX_CTAUNT_RAND_PROPS_NOT_PROP" )
                        return
                    end
					
					if Count > 0 or PHX:GetCVar( "ph_randtaunt_map_prop_max" ) == -1 then
						
						-- Don't use PHX:PlayTaunt here. This is NOT player entity!!
						if CheckValidity( name, snd, playerTeam ) then							
							if isPitchEnabled and tobool( plApplyOnFake ) then
                                if tobool( randFakePitch ) then
                                    pitch = math.random(PHX:GetCVar( "ph_taunt_pitch_range_min" ), PHX:GetCVar( "ph_taunt_pitch_range_max" ))
                                else
                                    pitch = math.Clamp(desiredPitch, PHX:GetCVar( "ph_taunt_pitch_range_min" ), PHX:GetCVar( "ph_taunt_pitch_range_max" ))
                                end
							end
							
							local props = ents.FindByClass("prop_physics")
                            table.Add( props, ents.FindByClass("ph_fake_prop") ) -- add ph_fake_prop as well.
							local randomprop = table.Random( props ) -- because of table.Add, it become non-sequential.
							
							if IsValid(randomprop) then
								randomprop:EmitSound(snd, 100, pitch)
								ply:SubTauntRandMapPropCount()
								SetLastTauntDelay( ply )
							end
						else
							ply:PHXChatInfo( "WARNING", "TM_DELAYTAUNT_NOT_EXIST" )
						end
						
					else
						ply:PHXChatInfo( "WARNING", "PHX_CTAUNT_RAND_PROPS_LIMIT" )
					end
				end
			else	-- if it's Player Taunt
				-- Play random HL2 cheer sound because taunt is empty.
				if (TAUNT_FALLBACK) then
					PHX:PlayTaunt( ply, "vo/coast/odessa/male01/nlo_cheer0"..math.random(1,4)..".wav", 0, 100, 0, "CLastTauntTime" )
					ply:SetLastTauntTime( "LastTauntTime", CurTime() )
					return
				end

				if CheckValidity( name, snd, playerTeam ) then

					PHX:PlayTaunt( ply, snd, plPitchOn, desiredPitch, plPitchRandomized, "CLastTauntTime" )
					ply:SetLastTauntTime( "LastTauntTime", CurTime() )
					
				else
					ply:PHXChatInfo( "WARNING", "TM_DELAYTAUNT_NOT_EXIST" )
				end
			end
		end
		
	end
end)
