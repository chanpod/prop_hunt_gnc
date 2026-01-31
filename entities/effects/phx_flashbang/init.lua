-- Flashbang Effect for Props
-- Experimental feature: stuns hunters within radius and triggers forced taunt

function EFFECT:Init(data)
	self.Position = data:GetOrigin()
	self.Radius = data:GetRadius() or 300
	self.Duration = data:GetMagnitude() or 3
	self.Entity = data:GetEntity()
	self.SpawnTime = CurTime()
	self.KillTime = CurTime() + 0.5

	self:SetRenderBoundsWS(self.Position + Vector(self.Radius, self.Radius, self.Radius), self.Position - Vector(self.Radius, self.Radius, self.Radius))

	-- Create flash burst
	self:EmitFlashBurst()

	-- Play flashbang sound
	sound.Play("weapons/flashbang/flashbang_explode1.wav", self.Position, 85, 100, 1)
end

function EFFECT:EmitFlashBurst()
	local emitter = ParticleEmitter(self.Position)
	if not emitter then return end

	-- Bright flash particles
	for i = 1, 20 do
		local vec = VectorRand():GetNormalized()
		local particle = emitter:Add("effects/yellowflare", self.Position + vec * math.Rand(5, 20))

		if particle then
			particle:SetVelocity(vec * math.Rand(100, 300))
			particle:SetDieTime(0.3 + math.Rand(-0.1, 0.1))
			particle:SetStartAlpha(255)
			particle:SetEndAlpha(0)
			particle:SetStartSize(math.Rand(30, 60))
			particle:SetEndSize(math.Rand(80, 120))
			particle:SetColor(255, 255, 220)
			particle:SetGravity(Vector(0, 0, 0))
			particle:SetAirResistance(50)
		end
	end

	-- Core flash
	for i = 1, 10 do
		local particle = emitter:Add("effects/yellowflare", self.Position)

		if particle then
			particle:SetVelocity(Vector(0, 0, 0))
			particle:SetDieTime(0.15)
			particle:SetStartAlpha(255)
			particle:SetEndAlpha(0)
			particle:SetStartSize(150)
			particle:SetEndSize(300)
			particle:SetColor(255, 255, 255)
		end
	end

	-- Smoke after flash
	for i = 1, 15 do
		local vec = VectorRand():GetNormalized()
		local particle = emitter:Add("particle/particle_smokegrenade", self.Position + vec * math.Rand(10, 30))

		if particle then
			particle:SetVelocity(vec * math.Rand(30, 80))
			particle:SetDieTime(1.5 + math.Rand(-0.3, 0.3))
			particle:SetStartAlpha(math.Rand(100, 150))
			particle:SetEndAlpha(0)
			particle:SetStartSize(math.Rand(20, 40))
			particle:SetEndSize(math.Rand(60, 100))
			particle:SetColor(200, 200, 200)
			particle:SetGravity(Vector(0, 0, math.Rand(20, 50)))
			particle:SetAirResistance(80)
			particle:SetRoll(math.Rand(0, 360))
			particle:SetRollDelta(math.Rand(-0.5, 0.5))
		end
	end

	emitter:Finish()
end

function EFFECT:Think()
	if CurTime() > self.KillTime then
		return false
	end
	return true
end

function EFFECT:Render()
	-- Dynamic light for the flash
	local elapsed = CurTime() - self.SpawnTime
	if elapsed < 0.3 then
		local intensity = 1 - (elapsed / 0.3)
		local dlight = DynamicLight(self:EntIndex())
		if dlight then
			dlight.pos = self.Position
			dlight.r = 255
			dlight.g = 255
			dlight.b = 220
			dlight.brightness = 5 * intensity
			dlight.decay = 1000
			dlight.size = 512 * intensity
			dlight.dietime = CurTime() + 0.1
		end
	end
end
