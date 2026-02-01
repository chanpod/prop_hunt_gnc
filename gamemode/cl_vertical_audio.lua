-- GNC: Vertical Audio - Client-side processing for position-based taunt audio
-- Sounds from above are higher pitched/softer, sounds from below are lower pitched/softer

net.Receive("PHX.VerticalTaunt", function()
	local sourceEnt = net.ReadEntity()
	local soundPath = net.ReadString()
	local baseLevel = net.ReadUInt(8)
	local basePitch = net.ReadUInt(8)
	local sourcePos = net.ReadVector()

	local listener = LocalPlayer()
	if not IsValid(listener) then return end

	local listenerPos = listener:EyePos()
	local verticalDiff = sourcePos.z - listenerPos.z  -- positive = above, negative = below

	-- Get configuration values
	local pitchScale = PHX:GetCVar("ph_exp_vertical_audio_pitch_scale") or 0.1
	local maxOffset = PHX:GetCVar("ph_exp_vertical_audio_max_offset") or 30
	local volumeScale = PHX:GetCVar("ph_exp_vertical_audio_volume_scale") or 0.3

	-- Calculate pitch offset (above = higher pitch, below = lower pitch)
	-- pitchScale of 0.1 means ±10 pitch per 100 vertical units
	local pitchOffset = math.Clamp((verticalDiff / 100) * (pitchScale * 100), -maxOffset, maxOffset)
	local finalPitch = math.Clamp(basePitch + pitchOffset, 50, 200)

	-- Calculate volume reduction (farther vertically = softer)
	-- volumeScale of 0.3 means 30% reduction at 500 units vertical distance
	local verticalAbs = math.abs(verticalDiff)
	local volumeMult = math.max(0.3, 1 - (verticalAbs / 500) * volumeScale)

	-- Play sound from source entity with modified parameters
	-- EmitSound signature: soundName, soundLevel, pitchPercent, volume, channel
	if IsValid(sourceEnt) then
		sourceEnt:EmitSound(soundPath, baseLevel, finalPitch, volumeMult)
	end
end)
