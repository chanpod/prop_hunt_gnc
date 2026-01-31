-- Smoke Screen Effect for Props
-- Experimental feature: allows props to deploy a smoke screen once per life

function EFFECT:Init(data)
	self.Position = data:GetOrigin()
	self.Duration = data:GetMagnitude() or 5
	self.KillTime = CurTime() + self.Duration
	self.SpawnTime = CurTime()
	self.Entity = data:GetEntity()

	self:SetRenderBoundsWS(self.Position + Vector(300, 300, 300), self.Position - Vector(300, 300, 300))

	-- Initial burst of smoke
	self:EmitSmokeBurst()

	-- Play smoke deploy sound
	sound.Play("weapons/smokegrenade/sg_explode.wav", self.Position, 75, 100, 1)
end

function EFFECT:EmitSmokeBurst()
	local emitter = ParticleEmitter(self.Position)
	if not emitter then return end

	-- Create thick smoke cloud
	for i = 1, 40 do
		local vec = VectorRand():GetNormalized()
		local particle = emitter:Add("particle/particle_smokegrenade", self.Position + vec * math.Rand(5, 30))

		if particle then
			particle:SetVelocity(vec * math.Rand(50, 150))
			particle:SetDieTime(self.Duration + math.Rand(-0.5, 0.5))
			particle:SetStartAlpha(math.Rand(180, 220))
			particle:SetEndAlpha(0)
			particle:SetStartSize(math.Rand(60, 100))
			particle:SetEndSize(math.Rand(150, 200))
			particle:SetColor(200, 200, 200)
			particle:SetGravity(Vector(0, 0, math.Rand(10, 30)))
			particle:SetAirResistance(100)
			particle:SetRoll(math.Rand(0, 360))
			particle:SetRollDelta(math.Rand(-0.5, 0.5))
		end
	end

	-- Add some darker smoke for depth
	for i = 1, 20 do
		local vec = VectorRand():GetNormalized()
		local particle = emitter:Add("particle/particle_smokegrenade", self.Position + vec * math.Rand(10, 50))

		if particle then
			particle:SetVelocity(vec * math.Rand(30, 80))
			particle:SetDieTime(self.Duration * 0.8 + math.Rand(-0.3, 0.3))
			particle:SetStartAlpha(math.Rand(150, 200))
			particle:SetEndAlpha(0)
			particle:SetStartSize(math.Rand(80, 120))
			particle:SetEndSize(math.Rand(180, 250))
			particle:SetColor(150, 150, 150)
			particle:SetGravity(Vector(0, 0, math.Rand(5, 20)))
			particle:SetAirResistance(80)
			particle:SetRoll(math.Rand(0, 360))
			particle:SetRollDelta(math.Rand(-0.3, 0.3))
		end
	end

	emitter:Finish()
end

function EFFECT:Think()
	-- Keep effect alive for duration
	if CurTime() > self.KillTime then
		return false
	end

	return true
end

function EFFECT:Render()
	-- No additional rendering needed, particles handle visuals
end
