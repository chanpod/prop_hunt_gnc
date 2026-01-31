-- Smoke Screen Effect for Props
-- Experimental feature: smoke trail that follows the player

function EFFECT:Init(data)
	self.Position = data:GetOrigin()
	self.Duration = data:GetMagnitude() or 5
	self.KillTime = CurTime() + self.Duration
	self.SpawnTime = CurTime()
	self.Entity = data:GetEntity()
	self.NextEmit = 0
	self.LastPos = self.Position

	-- Dynamic render bounds that follow player
	self:SetRenderBoundsWS(self.Position + Vector(500, 500, 500), self.Position - Vector(500, 500, 500))

	-- Initial puff of smoke
	self:EmitInitialBurst()

	-- Play smoke deploy sound
	sound.Play("weapons/smokegrenade/sg_explode.wav", self.Position, 75, 100, 1)
end

-- Initial burst when deployed
function EFFECT:EmitInitialBurst()
	local pos = self:GetCurrentPosition()
	local emitter = ParticleEmitter(pos)
	if not emitter then return end

	-- Initial burst cloud
	for i = 1, 40 do
		local vec = VectorRand():GetNormalized()
		local particle = emitter:Add("particle/particle_smokegrenade", pos + vec * math.Rand(5, 20))

		if particle then
			particle:SetVelocity(vec * math.Rand(60, 150))
			particle:SetDieTime(3 + math.Rand(-0.5, 0.5))
			particle:SetStartAlpha(math.Rand(200, 240))
			particle:SetEndAlpha(0)
			particle:SetStartSize(math.Rand(60, 100))
			particle:SetEndSize(math.Rand(150, 220))
			particle:SetColor(200, 200, 200)
			particle:SetGravity(Vector(0, 0, math.Rand(5, 15)))
			particle:SetAirResistance(100)
			particle:SetRoll(math.Rand(0, 360))
			particle:SetRollDelta(math.Rand(-0.5, 0.5))
		end
	end

	emitter:Finish()
end

-- Get current position (follows player if valid)
function EFFECT:GetCurrentPosition()
	if IsValid(self.Entity) then
		return self.Entity:GetPos() + Vector(0, 0, 20)
	end
	return self.Position
end

-- Emit trail particles at player position
function EFFECT:EmitTrail()
	local pos = self:GetCurrentPosition()
	local emitter = ParticleEmitter(pos)
	if not emitter then return end

	-- Calculate movement for directional trail
	local moveDir = (pos - self.LastPos):GetNormalized()
	local isMoving = pos:Distance(self.LastPos) > 5

	-- Main smoke trail particles
	for i = 1, 25 do
		local vec = VectorRand():GetNormalized()
		-- Bias particles slightly behind movement direction
		if isMoving then
			vec = (vec - moveDir * 0.5):GetNormalized()
		end

		local particle = emitter:Add("particle/particle_smokegrenade", pos + vec * math.Rand(5, 25))

		if particle then
			particle:SetVelocity(vec * math.Rand(30, 80))
			particle:SetDieTime(2.5 + math.Rand(-0.3, 0.3))
			particle:SetStartAlpha(math.Rand(220, 255))
			particle:SetEndAlpha(0)
			particle:SetStartSize(math.Rand(70, 110))
			particle:SetEndSize(math.Rand(160, 230))
			particle:SetColor(195, 195, 195)
			particle:SetGravity(Vector(0, 0, math.Rand(8, 20)))
			particle:SetAirResistance(90)
			particle:SetRoll(math.Rand(0, 360))
			particle:SetRollDelta(math.Rand(-0.4, 0.4))
		end
	end

	-- Darker smoke for depth
	for i = 1, 12 do
		local vec = VectorRand():GetNormalized()
		local particle = emitter:Add("particle/particle_smokegrenade", pos + vec * math.Rand(8, 35))

		if particle then
			particle:SetVelocity(vec * math.Rand(20, 50))
			particle:SetDieTime(2 + math.Rand(-0.2, 0.2))
			particle:SetStartAlpha(math.Rand(180, 220))
			particle:SetEndAlpha(0)
			particle:SetStartSize(math.Rand(90, 130))
			particle:SetEndSize(math.Rand(180, 260))
			particle:SetColor(140, 140, 140)
			particle:SetGravity(Vector(0, 0, math.Rand(5, 12)))
			particle:SetAirResistance(70)
			particle:SetRoll(math.Rand(0, 360))
			particle:SetRollDelta(math.Rand(-0.3, 0.3))
		end
	end

	-- Dense core particles around player
	for i = 1, 8 do
		local vec = VectorRand():GetNormalized()
		local particle = emitter:Add("particle/particle_smokegrenade", pos + vec * math.Rand(2, 12))

		if particle then
			particle:SetVelocity(vec * math.Rand(10, 30))
			particle:SetDieTime(1.5 + math.Rand(-0.2, 0.2))
			particle:SetStartAlpha(255)
			particle:SetEndAlpha(0)
			particle:SetStartSize(math.Rand(50, 80))
			particle:SetEndSize(math.Rand(100, 140))
			particle:SetColor(180, 180, 180)
			particle:SetGravity(Vector(0, 0, math.Rand(3, 8)))
			particle:SetAirResistance(120)
			particle:SetRoll(math.Rand(0, 360))
			particle:SetRollDelta(math.Rand(-0.2, 0.2))
		end
	end

	emitter:Finish()
	self.LastPos = pos
end

function EFFECT:Think()
	-- Stop if duration expired
	if CurTime() > self.KillTime then
		return false
	end

	-- Stop if player is no longer valid
	if not IsValid(self.Entity) then
		return false
	end

	-- Update render bounds to follow player
	local pos = self:GetCurrentPosition()
	self:SetRenderBoundsWS(pos + Vector(500, 500, 500), pos - Vector(500, 500, 500))

	-- Emit trail particles every 0.15 seconds for dense coverage
	if CurTime() > self.NextEmit then
		self:EmitTrail()
		self.NextEmit = CurTime() + 0.15
	end

	return true
end

function EFFECT:Render()
	-- No additional rendering needed, particles handle visuals
end
