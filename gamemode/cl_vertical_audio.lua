-- GNC: Vertical Audio - Client-side processing for position-based taunt audio
-- Sounds from above are higher pitched, sounds from below are lower pitched

net.Receive("PHX.VerticalTaunt", function()
	local sourceEnt = net.ReadEntity()
	local soundPath = net.ReadString()
	local baseLevel = net.ReadUInt(8)
	local basePitch = net.ReadUInt(8)
	local sourcePos = net.ReadVector()

	local listener = LocalPlayer()
	if not IsValid(listener) then return end

	local listenerPos = listener:GetPos()  -- Use feet position for consistent floor-to-floor comparison
	local verticalDiff = sourcePos.z - listenerPos.z  -- positive = above, negative = below

	-- Get configuration values (use GetConVar directly for reliable sync)
	local pitchScaleCV = GetConVar("ph_exp_vertical_audio_pitch_scale")
	local maxOffsetCV = GetConVar("ph_exp_vertical_audio_max_offset")
	local distanceThresholdCV = GetConVar("ph_exp_vertical_audio_distance")

	local pitchScale = pitchScaleCV and pitchScaleCV:GetFloat() or 0.10
	local maxOffset = maxOffsetCV and maxOffsetCV:GetInt() or 25
	local distanceThreshold = distanceThresholdCV and distanceThresholdCV:GetInt() or 100

	-- Only apply pitch change if vertical distance exceeds threshold
	local verticalAbs = math.abs(verticalDiff)
	local finalPitch = basePitch

	if verticalAbs >= distanceThreshold then
		-- Calculate pitch offset (above = higher pitch, below = lower pitch)
		-- pitchScale of 0.1 means ±10 pitch per 100 vertical units
		local pitchOffset = math.Clamp((verticalDiff / 100) * (pitchScale * 100), -maxOffset, maxOffset)
		finalPitch = math.Clamp(basePitch + pitchOffset, 50, 200)
	end

	-- Play sound from source entity with modified pitch
	if IsValid(sourceEnt) then
		sourceEnt:EmitSound(soundPath, baseLevel, finalPitch)
	end
end)
