AddCSLuaFile()

DEFINE_BASECLASS("base_anim")

ENT.PrintName   = "Test Radio (Dev)"
ENT.Author      = "X2Z"
ENT.Information = "Auto-taunts periodically for testing audio features"
ENT.Category    = "Prop Hunt"
ENT.Spawnable   = true
ENT.AdminOnly   = true
ENT.RenderGroup = RENDERGROUP_OPAQUE

function ENT:Initialize()
	if SERVER then
		self:SetModel("models/props_lab/citizenradio.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:Wake()
		end

		-- Start the auto-taunt loop
		self:StartTauntLoop()
	end
end

if SERVER then
	function ENT:StartTauntLoop()
		local timerName = "TestRadio_" .. self:EntIndex()
		local interval = PHX:GetCVar("ph_dev_radio_interval") or 10

		timer.Create(timerName, interval, 0, function()
			if not IsValid(self) then
				timer.Remove(timerName)
				return
			end

			self:PlayTestSound()
		end)

		-- Play one immediately
		timer.Simple(0.5, function()
			if IsValid(self) then
				self:PlayTestSound()
			end
		end)
	end

	function ENT:StopTauntLoop()
		local timerName = "TestRadio_" .. self:EntIndex()
		if timer.Exists(timerName) then
			timer.Remove(timerName)
		end
	end

	function ENT:PlayTestSound()
		-- Use configured test sound (consistent for audio testing)
		local sound = PHX:GetCVar("ph_dev_radio_sound") or "taunts/props/leroy_jenkins.wav"

		-- Get sound level from config
		local soundLevelIndex = PHX:GetCVar("ph_taunt_soundlevel") or 4
		local soundLevels = {75, 80, 85, 90, 95, 100}
		local soundLevel = soundLevels[math.Clamp(soundLevelIndex, 1, 6)]

		-- Use vertical audio system if enabled, otherwise direct emit
		if PHX:GetCVar("ph_exp_vertical_audio_enabled") then
			-- Always use pitch 100 for consistent testing
			local pitch = 100

			net.Start("PHX.VerticalTaunt")
			net.WriteEntity(self)
			net.WriteString(sound)
			net.WriteUInt(soundLevel, 8)
			net.WriteUInt(pitch, 8)
			net.WriteVector(self:GetPos())
			net.Broadcast()
		else
			self:EmitSound(sound, soundLevel)
		end

		-- Broadcast to admins what's playing
		for _, ply in ipairs(player.GetAll()) do
			if ply:IsAdmin() then
				ply:ChatPrint("[Test Radio] Playing: " .. sound)
			end
		end
	end

	function ENT:Use(activator, caller)
		if IsValid(activator) and activator:IsPlayer() and activator:IsAdmin() then
			self:PlayTestSound()
			activator:ChatPrint("[Test Radio] Manual taunt triggered!")
		end
	end

	function ENT:OnRemove()
		self:StopTauntLoop()
	end
end

if CLIENT then
	function ENT:Draw()
		self:DrawModel()

		-- Draw a label above the radio
		local pos = self:GetPos() + Vector(0, 0, 20)
		local ang = LocalPlayer():EyeAngles()
		ang:RotateAroundAxis(ang:Forward(), 90)
		ang:RotateAroundAxis(ang:Right(), 90)

		cam.Start3D2D(pos, ang, 0.1)
			draw.SimpleText("TEST RADIO", "DermaLarge", 0, 0, Color(255, 200, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			local interval = PHX:GetCVar("ph_dev_radio_interval") or 10
			draw.SimpleText("Taunts every " .. interval .. "s", "DermaDefault", 0, 30, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end
end

-- Console commands for spawning/removing test radios
if SERVER then
	concommand.Add("ph_dev_spawn_radio", function(ply, cmd, args)
		if not IsValid(ply) or not ply:IsAdmin() then
			if IsValid(ply) then ply:ChatPrint("[Test Radio] Admin only!") end
			return
		end

		-- Spawn at player's aim position
		local tr = ply:GetEyeTrace()
		local spawnPos = tr.HitPos + Vector(0, 0, 10)

		local radio = ents.Create("ph_test_radio")
		if IsValid(radio) then
			radio:SetPos(spawnPos)
			radio:Spawn()
			radio:Activate()
			ply:ChatPrint("[Test Radio] Spawned! Use E to trigger manual taunt, or wait for auto-taunt.")
		end
	end, nil, "Spawn a test radio at your aim position (admin only)")

	concommand.Add("ph_dev_remove_radios", function(ply, cmd, args)
		if not IsValid(ply) or not ply:IsAdmin() then
			if IsValid(ply) then ply:ChatPrint("[Test Radio] Admin only!") end
			return
		end

		local count = 0
		for _, ent in ipairs(ents.FindByClass("ph_test_radio")) do
			if IsValid(ent) then
				ent:Remove()
				count = count + 1
			end
		end
		ply:ChatPrint("[Test Radio] Removed " .. count .. " radio(s).")
	end, nil, "Remove all test radios (admin only)")
end
