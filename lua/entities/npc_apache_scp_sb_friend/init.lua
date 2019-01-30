AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include('shared.lua')

ENT.Alerted     		= false
ENT.AlertedCurTime		= 0
ENT.AlertedCurTimeEnd	= -1
ENT.Patrol				= true
ENT.PatrolPoint			= nil
ENT.FailStep 			= -1
ENT.FailStepUsed		= {}
ENT.FailCurTime			= 0
ENT.StartHealth 		= 650
ENT.PequodDown			= false
ENT.State 				= 0 
ENT.Enemy 				= NULL
ENT.PequodBack 			= false
ENT.EnemyIsVehicle		= false
ENT.dead 				= false
ENT.DestAlt 			= 0
ENT.PlayerHelp			= false
ENT.PlayerHelpID		= NULL
ENT.PlayerHelpSoundPlay = false
ENT.rocket_toggle 		= false
ENT.cooldownCheck 		= false
ENT.cooldown 			= false
ENT.HelpPosition		= false
ENT.cooldownTime     	= 3
ENT.shootTime			= 10
ENT.EnabledFire			= true
ENT.RemoveTimeProps		= 30   
ENT.Smoke				= false
ENT.maxDistance			= 1000
ENT.minDistance 		= 300
ENT.FindEnemyRadius		= 7000

function ENT:Initialize()
	self:SetModel( "models/usmcapachelicopter.mdl" )		
	self.Entity:PhysicsInit( SOLID_VPHYSICS )   
	self.Entity:SetMoveType( MOVETYPE_VPHYSICS )   	
	self.Entity:SetSolid( SOLID_VPHYSICS )  
	self:CapabilitiesAdd( CAP_MOVE_FLY )
	self:SetPos(self:GetPos() + Vector(0, 0, 150))

	self:SetHealth(self.StartHealth)
	self.Enemy = NULL
	self.LoopSound = CreateSound(self, Sound("npc/attack_helicopter/aheli_rotor_loop1.wav"))
	self.LoopSound:PlayEx(1, 100)

	self.warningSound = CreateSound(self, Sound("apache/lowhealth.mp3"))
	self.pequod_pequod_down_1 = CreateSound(self, Sound("pequod_pequod_down_1"))
	self.pequod_pequod_down_2 = CreateSound(self, Sound("pequod_pequod_down_2"))
	self.pequod_target_shoot = CreateSound(self, Sound("pequod_target_shoot"))
	self.pequod_this_is_pequod_1 = CreateSound(self, Sound("pequod_this_is_pequod_1"))
	self.pequod_this_is_pequod_2 = CreateSound(self, Sound("pequod_this_is_pequod_2"))
	self.pequod_back = CreateSound(self, Sound("pequod_back"))
	self.pequod_down_sound = CreateSound(self, Sound("pequod_down_sound"))
	self.pequod_marker = CreateSound(self, Sound("pequod_marker"))

	self.DestAlt = self:GetPos().z + 500
	local phys = self.Entity:GetPhysicsObject()  	
	if (phys:IsValid()) then 		
		phys:Wake()  
		phys:EnableGravity(false) 
	end 
end
   
function ENT:OnTakeDamage(dmg)
	if self.dead then return end
	if dmg:IsBulletDamage() then 
		self:SetHealth( self:Health() - dmg:GetDamage() / math.random( 3, 6 ) );
	-- 	local class = dmg:GetAttacker():GetClass()
	-- 	if (class != "npc_apache_scp_sb" && class != "npc_apache_scp_sb_new_enemy" && class != "npc_apache_scp_sb_friend" && class != "npc_combinegunship" && class != "npc_helicopter" && class != "npc_strider") then
	-- 		return
	-- 	else
	-- 		self:SetHealth(self:Health() - dmg:GetDamage()/4)
	-- 	end

	-- 	self:SetHealth( self:Health() - dmg:GetDamage() / math.random( 3, 6 ) );
	-- else
	-- 	self:SetHealth(self:Health() - dmg:GetDamage())
	end

	if (self.PequodDown) then
		self:BreakableCopter()
		return
	end

	if dmg:GetAttacker():GetClass() != self:GetClass() && math.random(0, 100) <= 90 && (dmg:IsExplosionDamage() || dmg:GetDamageType() == DMG_BURN) then
		self.Alerted = true
		if (!dmg:GetAttacker():IsPlayer()) then
			self.Enemy = dmg:GetAttacker()
		end
	end

	if (self:Health() <= self.StartHealth/2) then
		if !self.Smoke then
			self.Smoke = self:CreateSmoke()
		end
		if !self.warningSound:IsPlaying() then
			self.warningSound:PlayEx(1,100)
		end
	end
	
	if self:Health() <= 0 && !self.dead then 
		self:KilledDan()
	elseif (self:Health() <= 150 && !self.PequodBack && self.PlayerHelp) then
		self.PlayerHelp = false
		self.PlayerHelpID = NULL
		self.Enemy = NULL
		self.pequod_back:Play()
		self.pequod_back:PlayEx(1, 100)
		timer.Simple(5, function() if (!IsValid(self)) then return end self.pequod_back:Stop() end)
		self.PequodBack = true
		self.PatrolPoint = self.Entity:GetAngles():Forward() * -5000
		timer.Simple(15, function()
			if (!IsValid(self)) then return end 
			self.PequodBack = true
			self.PatrolPoint = nil
		end)
		return
	end
end

function ENT:FailMove()
	local phy = self:GetPhysicsObject()
	if phy:IsValid() then
		local forward1 = self.Entity:GetAngles():Forward() * 150
		local forward2 = self.Entity:GetAngles():Forward() * 550
		local startpos = self.Entity:GetPos() + forward1 - Vector(0, 0, 100)
		local endpos = self.Entity:GetPos() + forward2 - Vector(0, 0, -30)
		local checkIsWorld = util.TraceLine( {
			start = startpos,
			endpos = endpos,
			filter = function( ent ) 
				if ( ent != self ) then 
					return true
				end 
			end
		} )

		local ceiling = util.TraceLine( {
			start = self.Entity:GetPos() + Vector(0, 0, 200),
			endpos = self.Entity:GetPos() + Vector(0, 0, 500),
			filter = function( ent ) 
				if ( ent != self ) then 
					return true
				end 
			end
		} )

		if (ceiling.Entity != NULL) then
			phy:AddVelocity(self.Entity:GetAngles():Up() * -40)
		end

		if (checkIsWorld.Entity != NULL && checkIsWorld.Entity:GetClass() == "worldspawn") then
			-- phy:AddVelocity(self.Entity:GetAngles():Forward() * -math.abs( (phy:GetVelocity().x)*(phy:GetVelocity().y)/250 ))
			phy:AddVelocity(self.Entity:GetAngles():Forward() * -50)
			local right_right_1 = self.Entity:GetAngles():Right() * 150
			local right_right_2 = self.Entity:GetAngles():Right() * 1000
			local right_check = util.TraceLine( {
				start = self.Entity:GetPos() + right_right_1 - Vector(0, 0, 100),
				endpos = self.Entity:GetPos() + right_right_2 - Vector(0, 0, 100),
				filter = function( ent ) 
					if ( ent != self ) then 
						return true
					end 
				end
			} )
		
			local right_left_1 = self.Entity:GetAngles():Right() * -150
			local right_left_2 = self.Entity:GetAngles():Right() * -1000
			local left_check = util.TraceLine( {
				start = self.Entity:GetPos() + right_left_1 - Vector(0, 0, 100),
				endpos = self.Entity:GetPos() + right_left_2 - Vector(0, 0, 100),
				filter = function( ent ) 
					if ( ent != self ) then 
						return true
					end 
				end
			} )

			if (right_check.Entity == NULL && self.FailCurTime < CurTime() && !table.HasValue(self.FailStepUsed, 1)) then
				self.FailStep = 1
				self.FailCurTime = CurTime() + 4
				table.insert(self.FailStepUsed, 1)
			elseif (left_check.Entity == NULL && self.FailCurTime < CurTime() && !table.HasValue(self.FailStepUsed, 2)) then
				self.FailStep = 2
				self.FailCurTime = CurTime() + 4
				table.insert(self.FailStepUsed, 2)
			elseif (self.FailCurTime < CurTime() && !table.HasValue(self.FailStepUsed, 3)) then
				self.FailStep = 3
				self.FailCurTime = CurTime() + 4
				table.insert(self.FailStepUsed, 3)
			end
		elseif (checkIsWorld.Entity == NULL && self.FailCurTime < CurTime() && self.FailStep != -1) then
			self.FailStep = -1
			table.Empty(self.FailStepUsed)
		else
			local right_right_1 = self.Entity:GetAngles():Right() * 150
			local right_right_2 = self.Entity:GetAngles():Right() * 350
			local right_check = util.TraceLine( {
				start = self.Entity:GetPos() + right_right_1 - Vector(0, 0, 100),
				endpos = self.Entity:GetPos() + right_right_2 - Vector(0, 0, 100),
				filter = function( ent ) 
					if ( ent != self ) then 
						return true
					end 
				end
			} )
		
			local right_left_1 = self.Entity:GetAngles():Right() * -150
			local right_left_2 = self.Entity:GetAngles():Right() * -350
			local left_check = util.TraceLine( {
				start = self.Entity:GetPos() + right_left_1 - Vector(0, 0, 100),
				endpos = self.Entity:GetPos() + right_left_2 - Vector(0, 0, 100),
				filter = function( ent ) 
					if ( ent != self ) then 
						return true
					end 
				end
			} )

			if (right_check.Entity != NULL) then
				phy:AddVelocity(self.Entity:GetAngles():Right() * -50)
			elseif (left_check.Entity != NULL) then
				phy:AddVelocity(self.Entity:GetAngles():Right() * 50)
			end
		end
	end

	if (self.FailStep == 1) then
		phy:AddVelocity(self.Entity:GetAngles():Right() * 40)
	elseif (self.FailStep == 2) then
		phy:AddVelocity(self.Entity:GetAngles():Right() * -40)
	elseif (self.FailStep == 3) then
		phy:AddVelocity(self.Entity:GetAngles():Up() * 100)
	end
end

function ENT:Think()
	if self.dead then return end
	if self:Health() > 0 && GetConVarNumber("ai_disabled") == 0 then
		if self.Enemy:IsValid() == false then
			self.Enemy = NULL
			self.Alerted = false
		elseif self.Enemy:Health(health) <= 0 then
			self.Enemy = NULL
			self.Alerted = false
		elseif self.Enemy == self then
			self.Enemy = NULL
			self.Alerted = false
		end

		if (self:WaterLevel() == 1) then
			local phy = self:GetPhysicsObject()
			if phy:IsValid() then
				phy:AddVelocity(self.Entity:GetAngles():Up() * 200)
			end
			if (self.Patrol && self.PatrolPoint != nil) then
				self.PatrolPoint = nil
			end
		elseif (self:WaterLevel() >= 2) then
			self:BreakableCopter()
		end

		if self.cooldownCheck == false then
			self.cooldownCheck = true
			if IsValid(self) then
				timer.Simple(self.shootTime, function()
					self.cooldown = true
					if IsValid(self) then
						timer.Simple(self.cooldownTime, function()
							self.cooldownCheck = false
							self.cooldown = false
						end)
					end
				end)
			end
		end
	
		local phy = self:GetPhysicsObject()
		if phy:IsValid() then
			local velocity = phy:GetVelocity()
			phy:SetAngles( Angle(20,self:GetAngles().y,0) )
			phy:SetVelocity(velocity)
		end
		
		if (self.Alerted && self.AlertedCurTime < CurTime()) then
			local tr = util.TraceLine( {
				start = self:GetPos() + Vector(0, 0, -100),
				endpos = self.Enemy:GetPos() + Vector(0, 0, self.Enemy:OBBCenter().z),
				filter = function( ent ) 
					if (IsValid(ent) && ent:GetClass() != "npc_apache_scp_sb_friend") then
						if (ent:IsVehicle()) then
							if (IsValid(ent:GetDriver())) then
								self.Enemy = ent:GetDriver()
								return true
							end
						elseif (ent:IsNPC()) then 
							return true
						end
					end
				end
			} )

			if (tr.Entity == NULL) then
				self.Alerted = false
			elseif (tr.Entity == self.Enemy) then
				self.AlertedCurTime = CurTime() + 5
			elseif (self.AlertedCurTimeEnd == -1) then
				self.AlertedCurTimeEnd = CurTime() + 10
			elseif (self.AlertedCurTimeEnd < CurTime()) then
				self.AlertedCurTimeEnd = -1
				self.Alerted = false
			end
		elseif(!self.Alerted) then
			if (!self.PequodBack) then
				self:ResetEnemy()
				self:FindEnemyDan()
			end
		end

		-- print(self.PlayerHelpSoundPlay)
		-- print(self.PlayerHelpID)
		-- if (self.PlayerHelpID != NULL) then
		-- 	print(self:GetPos():Distance(self.PlayerHelpID:GetPos()))
		-- end
		-- print("________________________")

		if (self.PlayerHelpSoundPlay && self.PlayerHelpID != NULL && self:GetPos():Distance(self.PlayerHelpID:GetPos()) <= 2000) then
			self.pequod_marker:Play()
			self.pequod_marker:PlayEx(1, 100)
			timer.Simple(20, function() if (!IsValid(self)) then return end self.pequod_marker:Stop() end)
			self.PlayerHelpSoundPlay = false
			self.HelpPosition = true
		elseif (self.PlayerHelpSoundPlay && self.PlayerHelpID != NULL && self:GetPos():Distance(self.PlayerHelpID:GetPos()) <= 5000) then
			if (math.random(0, 1) == 1) then
				self.pequod_this_is_pequod_1:Play()
				self.pequod_this_is_pequod_1:PlayEx(1, 100)
				timer.Simple(20, function() if (!IsValid(self)) then return end self.pequod_this_is_pequod_1:Stop() end)
			else
				self.pequod_this_is_pequod_2:Play()
				self.pequod_this_is_pequod_2:PlayEx(1, 100)
				timer.Simple(20, function() if (!IsValid(self)) then return end self.pequod_this_is_pequod_2:Stop() end)
			end
		end

		if (self.Enemy != NULL) then	
			local wantedvector = (self.Enemy:GetPos() - self:GetPos() + Vector(0,0,-80))
			local wantedangle = (self.Enemy:GetPos() - self:GetPos() + Vector(0,0,80)):Angle()
			local currentangle = Angle(20,self:GetAngles().y,0)
			local anglediff = self:GetAngleDiff(wantedangle.y,currentangle.y)
			local rocketNormalAngleShoot = (self.Enemy:GetPos() - self:GetPos()):Angle().x

			local badRocket = util.TraceLine( {
				start = self:GetPos() + Vector(0, 0, -100),
				endpos = self:GetPos() + Vector(0, 0, -700),
			} )
			
			if ( self.State == 0 && self.cooldown == false ) then
				local phy = self:GetPhysicsObject()
				if phy:IsValid() then
					if ( badRocket.Entity == NULL ) then
						if (math.abs(anglediff) < 60) then
							phy:ApplyForceCenter((wantedvector * 40))
						end
					else
						if (math.abs(anglediff) < 60) then
							phy:ApplyForceCenter((wantedvector * 40))
						end
						phy:AddVelocity(Vector(0, 0, math.random(25, 40)))
						self.PatrolPoint = nil
					end
					self:FailMove()
				end
			elseif (self.State >= 1) then
				phy:ApplyForceCenter(wantedvector * -40)
			end

			if math.abs(anglediff) < 50 && self:GetPos():Distance(self.Enemy:GetPos()) < self.maxDistance && self.cooldown == false && rocketNormalAngleShoot <= 100 then
				if (!self.pequod_target_shoot:IsPlaying()) then
					self.pequod_target_shoot:Play()
					self.pequod_target_shoot:PlayEx(1, 100)
					timer.Simple(math.random(10, 20), function() if (!IsValid(self)) then return end self.pequod_target_shoot:Stop() end)
				end
				
				local shoot_vector = wantedvector
				shoot_vector:Normalize()

				local bullet = {}
				bullet.Num 			= 4
				bullet.Src 			= self:GetPos() + self:GetForward()*150
				bullet.Damage 		= math.random(5, 15)
				bullet.Force		= 200
				bullet.Tracer		= 1
				bullet.Spread		= Vector( 12 / 90, 12 / 90, 0 )
				bullet.Dir 			= shoot_vector
				self:FireBullets( bullet )
				self:EmitSound("apache/fire.wav",500,100)
				
				if (rocketNormalAngleShoot <= 100) then
					if math.random(0,200) <= 2 && self.cooldown == false then
						local shoot_vector = wantedvector
						shoot_vector:Normalize()
						local rocket = ents.Create("proj_dan_heli_shot_scp_sb_fg")
						if self.rocket_toggle == true then
							rocket:SetPos(self:LocalToWorld(Vector(150,40,-20)))
							self.rocket_toggle = false
						else
							rocket:SetPos(self:LocalToWorld(Vector(150,-40,-20)))
							self.rocket_toggle = true
						end
						rocket:SetAngles(shoot_vector:Angle())
						rocket:Activate()
						rocket:Spawn()
						local phy = rocket:GetPhysicsObject()
						if phy:IsValid() then
							phy:ApplyForceCenter((shoot_vector * 7500))
						end
					end
				else
					local phy = self:GetPhysicsObject()
					if phy:IsValid() then
						if (math.random(0, 100) > 10) then
							phy:AddVelocity(self.Entity:GetAngles():Up() * math.random(5, 30))
						else
							phy:AddVelocity(self.Entity:GetAngles():Up() * -(math.random(5, 30)))
						end
					end
				end
			elseif math.abs(anglediff) < 30 && math.random(0,200) <= 25 && self.cooldown == false && badRocket.Entity == NULL && rocketNormalAngleShoot <= 100 then
				local shoot_vector = wantedvector
				shoot_vector:Normalize()
				local rocket = ents.Create("proj_dan_heli_shot_scp_sb_fg")
				if self.rocket_toggle == true then
					rocket:SetPos(self:LocalToWorld(Vector(150,40,-20)))
					self.rocket_toggle = false
				else
					rocket:SetPos(self:LocalToWorld(Vector(150,-40,-20)))
					self.rocket_toggle = true
				end
				rocket:SetAngles(shoot_vector:Angle())
				rocket:Activate()
				rocket:Spawn()
				local phy = rocket:GetPhysicsObject()
				if phy:IsValid() then
					phy:ApplyForceCenter((shoot_vector * 7500))
				end
			elseif (rocketNormalAngleShoot > 100) then
				local phy = self:GetPhysicsObject()
				if phy:IsValid() then
					if (math.random(0, 100) > 10) then
						phy:AddVelocity(self.Entity:GetAngles():Up() * math.random(5, 30))
					else
						phy:AddVelocity(self.Entity:GetAngles():Up() * -(math.random(5, 30)))
					end
				end
			end
		
			if anglediff >= -0.5 && anglediff <= 0.5 then
				local phy = self:GetPhysicsObject()
				if phy:IsValid() then
					phy:AddAngleVelocity( Vector(0, 0, 0) )
				end
			elseif anglediff > 5 then
				local phy = self:GetPhysicsObject()
				if phy:IsValid() then
					phy:AddAngleVelocity( Vector(0, 0, 5) )
				end
			elseif anglediff < -5 then
				local phy = self:GetPhysicsObject()
				if phy:IsValid() then
					phy:AddAngleVelocity( Vector(0, 0, -5) )
				end
			end
		elseif (self.Enemy == NULL && self.Patrol) then
			if (self.PatrolPoint == nil) then
				self.PatrolPoint = Vector(self:GetPos().x + math.random(-3000, 3000), self:GetPos().y + math.random(-3000, 3000), self:GetPos().z + math.random(-3000, 3000))
				if (!util.IsInWorld(self.PatrolPoint)) then
					self.PatrolPoint = nil
					return
				end
			end
			if (self.PlayerHelp && self.HelpPosition) then
				self.PlayerHelpID = NULL
				self.PlayerHelp = false
			end

			local objects = ents.FindInSphere(self.PatrolPoint, 1000)
			if (table.HasValue(objects, self)) then
				self.PatrolPoint = nil
				return
			end
			local wantedvector = (self.PatrolPoint - self:GetPos() + Vector(0,0,-80))
			local wantedangle = (self.PatrolPoint - self:GetPos() + Vector(0,0,80)):Angle()
			local currentangle = Angle(20,self:GetAngles().y,0)
			local anglediff = self:GetAngleDiff(wantedangle.y,currentangle.y)
			local badRocket = util.TraceLine( {
				start = self:GetPos() + Vector(0, 0, -100),
				endpos = self:GetPos() + Vector(0, 0, -700),
			} )
			
			local phy = self:GetPhysicsObject()
			if phy:IsValid() then
				if ( badRocket.Entity == NULL ) then
					if (math.abs(anglediff) < 60) then
						phy:ApplyForceCenter((wantedvector * 40))
					end
				else
					if (math.abs(anglediff) < 60) then
						phy:ApplyForceCenter((wantedvector * 40))
					end
					phy:AddVelocity(Vector(0, 0, math.random(25, 40)))
				end
				self:FailMove()
			end

			if anglediff >= -0.5 && anglediff <= 0.5 then
				local phy = self:GetPhysicsObject()
				if phy:IsValid() then
					phy:AddAngleVelocity( Vector(0, 0, 0) )
				end
			elseif anglediff > 5 then
				local phy = self:GetPhysicsObject()
				if phy:IsValid() then
					phy:AddAngleVelocity( Vector(0, 0, 5) )
				end
			elseif anglediff < -5 then
				local phy = self:GetPhysicsObject()
				if phy:IsValid() then
					phy:AddAngleVelocity( Vector(0, 0, -5) )
				end
			end
		end

		if self.DestAlt + 100 > self:GetPos().z then
			local phy = self:GetPhysicsObject()
			if phy:IsValid() then
				phy:ApplyForceCenter((Vector(0.15,0,2) * 5000))
			end
		elseif self.DestAlt + 100 < self:GetPos().z then
			local phy = self:GetPhysicsObject()
			if phy:IsValid() then
				phy:ApplyForceCenter((Vector(0.15,0,-2) * 5000))
			end
		end	
	end
	
end

function ENT:Touch( ent )
	if ent:GetClass() == "npc_grenade_rocket" then
		self:TakeDamage(200,ent)
		return
	end
	if self.State == 0 then
		ent:TakeDamage(100,self)
	end
end

function ENT:GetAngleDiff(angle1, angle2)
	local result = angle1 - angle2
	if result < -180 then
		result = result + 360
	end

	if result > 180 then
		result = result - 360
	end
	
	return result
end
   
function ENT:SelectSchedule()
if self.Enemy:IsValid() == false then
	self.Enemy = NULL
elseif self.Enemy:Health(health) <= 0 then
	self.Enemy = NULL
end

if self:Health() > 0 && self.cooldown == false then
	local haslos = self:HasLOS()
	local distance = 0
	local enemy_pos = 0

	if self.Enemy:IsValid() == false then
		self.Enemy = NULL
	elseif self.Enemy:Health(health) <= 0 then
		self.Enemy = NULL
	elseif self.Enemy == self then
		self.Enemy = NULL
	end

	if IsValid(self.Enemy) then
		enemy_pos = self.Enemy:GetPos()
		distance = self:GetPos():Distance(enemy_pos)
		if distance > self.maxDistance then
			self.State = 0 
		elseif distance < self.maxDistance && distance > self.minDistance then 
			self.State = 1 
		else
			self.State = 1 
		end
	end
end
end

function ENT:FindEnemyDan()
	local objects = ents.FindInSphere(self:GetPos(), self.FindEnemyRadius)
	local Target = NULL
	local odlDist = nil
	local isTarget = false

	for k, v in pairs(objects) do
		if (v:GetClass() != self:GetClass()) && v != self then
			if (IsValid(v) && ( v:GetClass() == "npc_apache_scp_sb" || v:GetClass() == "npc_apache_scp_sb_new_enemy" )) then
				self.Enemy = v
				self.Alerted = true
				return true
			end
			if (IsValid(v) && v:IsNPC() && v:Disposition(self) == D_HT) then
				local tr = util.TraceLine( {
					start = self:GetPos() + Vector(0, 0, -100),
					endpos = v:GetPos() + Vector(0, 0, v:OBBCenter().z),
					filter = function( ent ) 
						if ( IsValid(ent) && ent:GetClass() != "npc_apache_scp_sb_friend" && ent:IsNPC()) then 
							self.Alerted = true
							return true
						end
					end
				} )

				if (IsValid(tr.Entity)) then
					if (odlDist == nil) then
						Target = v
						odlDist = self:GetPos():Distance(v:GetPos()) 
					elseif (self:GetPos():Distance(v:GetPos()) < odlDist) then
						Target = v
						odlDist = self:GetPos():Distance(v:GetPos()) 
					end
					isTarget = true
				end
			end
		end
	end

	if (!isTarget) then
		self.Enemy = NULL
	elseif (Target != NULL) then
		self.Enemy = Target
	else
		self.Enemy = NULL
	end
end

function ENT:CreateSmoke()
	local smoke = ents.Create("env_smokestack")
	smoke:SetPos(self:GetPos())
	smoke:SetAngles(self:GetAngles()+Angle(-90,0,0))
	smoke:SetKeyValue("InitialState", "1")
	smoke:SetKeyValue("WindAngle", "0 0 0")
	smoke:SetKeyValue("WindSpeed", "0")
	smoke:SetKeyValue("rendercolor", "170 170 170")
	smoke:SetKeyValue("renderamt", "170")
	smoke:SetKeyValue("SmokeMaterial", "particle/smokesprites_0001.vmt")
	smoke:SetKeyValue("BaseSpread", "2")
	smoke:SetKeyValue("SpreadSpeed", "2")
	smoke:SetKeyValue("Speed", "50")
	smoke:SetKeyValue("StartSize", "10")
	smoke:SetKeyValue("EndSize", "150")
	smoke:SetKeyValue("roll", "10")
	smoke:SetKeyValue("Rate", "15")
	smoke:SetKeyValue("JetLength", "70")
	smoke:SetKeyValue("twist", "5")
	smoke:Spawn()
	smoke:SetParent(self.Entity)
	smoke:Activate()
	return smoke
end

function ENT:KilledDan()
	local isBreak = false
	local velocityZAdd = -30
	local velocityAngleZAdd = 80
	self.cooldown = true
	self.cooldownCheck = true
	self.PequodDown = true

	if !self.Smoke then
		self.Smoke = self:CreateSmoke()
	end

	if (math.random(0, 100) > 80) then
		self:BreakableCopter()
		return
	end

	if (math.random(0 ,1) == 1) then
		self.pequod_pequod_down_1:Play()
		self.pequod_pequod_down_1:PlayEx(1, 100)
	else
		self.pequod_pequod_down_2:Play()
		self.pequod_pequod_down_2:PlayEx(1, 100)
	end

	local timerName = tostring(self:EntIndex()).."_copter_break_"..tostring(CurTime())
	timer.Create(timerName, 0.1, 0, function()
		if self:IsValid() then
			local phy = self:GetPhysicsObject()
			phy:AddAngleVelocity( Vector(0, 0, velocityAngleZAdd) )
			velocityAngleZAdd = velocityAngleZAdd + 1
			phy:SetVelocity( Vector(0, 0, velocityZAdd) )
			velocityZAdd = velocityZAdd - math.random(3, 10)

			local tr = util.TraceLine( {
				start = self:GetPos() + Vector(0, 0, -100),
				endpos = self:GetPos() + Vector(0, 0, -160),
			} )

			if (tr.Entity != NULL) then
				isBreak = true
			end

			if (isBreak) then
				timer.Remove(timerName)
				self:BreakableCopter()
			end
		elseif self.dead then 
			timer.Remove(timerName)
			return 
		end
	end)

	self.pequod_down_sound:Play()
	self.pequod_down_sound:PlayEx(0.5, 100)


	-- timer.Simple(6, function()
	-- 	if self.dead then return end
	-- 	if (IsValid(self)) then
	-- 		self.pequod_down_sound:Play()
	-- 		-- timer.Remove(timerName)
	-- 		-- self:BreakableCopter()
	-- 	end
	-- end)
end

function ENT:BreakableCopter()
		self.dead = true

		if self.Smoke then
			self.Smoke:Remove()
			self.Smoke=nil
		end

		self:StopSounds()
		if self.warningSound:IsPlaying() then
			self.warningSound:Stop()
		end

		local ragdoll = ents.Create( "prop_physics" )
		ragdoll:SetModel( "models/apgb/helicopter_brokenpiece_06_body.mdl" )
		ragdoll:SetPos( self:GetPos() )
		ragdoll:SetAngles( self:GetAngles() )
		local fire = ents.Create("env_fire_trail")
		fire:SetPos(ragdoll:GetPos() + Vector(0, 0, 50))
		fire:SetParent(ragdoll)
		ragdoll:Spawn()
		fire:Spawn()

		ragdoll:SetSkin( self:GetSkin() )
		ragdoll:SetColor( self:GetColor() )
		ragdoll:SetMaterial( self:GetMaterial() )
		if self.EnabledFire then 
			ragdoll:Ignite( math.Rand( 8, 10 ), 0 ) 
		end
		timer.Simple(self.RemoveTimeProps, function()
			if (IsValid(ragdoll)) then
				ragdoll:Remove()
			end
		end)

		local effectdata = EffectData()
		effectdata:SetStart(ragdoll:GetPos())
		effectdata:SetOrigin(ragdoll:GetPos())
		effectdata:SetScale(50)
		util.Effect("Explosion", effectdata)
		util.Effect("grenade_explosion_01", effectdata)
		util.Effect("HelicopterMegaBomb", effectdata)
		util.Effect("cball_explode", effectdata)
		timer.Simple(0.5, function()
			if (IsValid(ragdoll)) then
				effectdata:SetStart(ragdoll:GetPos())
				effectdata:SetOrigin(ragdoll:GetPos())
				util.Effect("Explosion", effectdata)
				util.Effect("grenade_explosion_01", effectdata)
				util.Effect("HelicopterMegaBomb", effectdata)
				util.Effect("cball_explode", effectdata)
				util.BlastDamage(ragdoll, ragdoll, ragdoll:GetPos(), 300, 300)
			end
		end)
		timer.Simple(0.7, function()
			if (IsValid(ragdoll)) then
				effectdata:SetStart(ragdoll:GetPos())
				effectdata:SetOrigin(ragdoll:GetPos())
				util.Effect("Explosion", effectdata)
				util.Effect("grenade_explosion_01", effectdata)
				util.Effect("HelicopterMegaBomb", effectdata)
				util.Effect("cball_explode", effectdata)
				util.BlastDamage(ragdoll, ragdoll, ragdoll:GetPos(), 300, 300)
			end
		end)
		util.BlastDamage(ragdoll, ragdoll, ragdoll:GetPos(), 300, 300)

		local ragdoll = ents.Create( "prop_physics" )
		ragdoll:SetModel( "models/apgb/helicopter_brokenpiece_04_cockpit.mdl" )
		ragdoll:SetPos( self:LocalToWorld(Vector(100,0,0)))
		ragdoll:SetAngles( self:GetAngles() )
		ragdoll:Spawn()
		ragdoll:SetSkin( self:GetSkin() )
		ragdoll:SetColor( self:GetColor() )
		ragdoll:SetMaterial( self:GetMaterial() )
		if self.EnabledFire then 
			ragdoll:Ignite( math.Rand( 8, 10 ), 0 ) 
		end
		timer.Simple(self.RemoveTimeProps, function()
			if (IsValid(ragdoll)) then
				ragdoll:Remove()
			end
		end)
		timer.Simple(1, function()
			if (IsValid(ragdoll)) then
				effectdata:SetStart(ragdoll:GetPos())
				effectdata:SetOrigin(ragdoll:GetPos())
				util.Effect("Explosion", effectdata)
				util.Effect("grenade_explosion_01", effectdata)
				util.Effect("HelicopterMegaBomb", effectdata)
				util.Effect("cball_explode", effectdata)
				util.BlastDamage(ragdoll, ragdoll, ragdoll:GetPos(), 300, 300)
			end
		end)

		local ragdollPilot = ents.Create( "prop_ragdoll" )
		ragdollPilot:SetModel( "models/player/ct_sas.mdl" )
		ragdollPilot:SetPos( ragdoll:GetPos() + Vector(-50, 0, 0) )
		ragdollPilot:SetCollisionGroup( COLLISION_GROUP_WORLD )
		ragdollPilot:SetColor( Color(150, 150, 150, 255) )
		ragdollPilot:Spawn()	
		if self.EnabledFire then 
			ragdollPilot:Ignite( self.RemoveTimeProps, 0 ) 
		end
		timer.Simple(self.RemoveTimeProps, function()
			if (IsValid(ragdollPilot)) then
				ragdollPilot:Remove()
			end
		end)

		local ragdollPilot = ents.Create( "prop_ragdoll" )
		ragdollPilot:SetModel( "models/player/ct_sas.mdl" )
		ragdollPilot:SetPos( ragdoll:GetPos() + Vector(50, 0, 0) )
		ragdollPilot:SetCollisionGroup( COLLISION_GROUP_WORLD )
		ragdollPilot:SetColor( Color(150, 150, 150, 255) )
		ragdollPilot:Spawn()	
		if self.EnabledFire then 
			ragdollPilot:Ignite( self.RemoveTimeProps, 0 ) 
		end
		timer.Simple(self.RemoveTimeProps, function()
			if (IsValid(ragdollPilot)) then
				ragdollPilot:Remove()
			end
		end)

		local ragdoll = ents.Create( "prop_physics" )
		ragdoll:SetModel( "models/apgb/helicopter_brokenpiece_05_tailfan.mdl" )
		ragdoll:SetPos( self:LocalToWorld(Vector(-100,0,0)))
		ragdoll:SetAngles( self:GetAngles() )
		ragdoll:Spawn()
		ragdoll:SetSkin( self:GetSkin() )
		ragdoll:SetColor( self:GetColor() )
		ragdoll:SetMaterial( self:GetMaterial() )
		timer.Simple(self.RemoveTimeProps, function()
			if (IsValid(ragdoll)) then
				ragdoll:Remove()
			end
		end)

		if self.EnabledFire then 
			ragdoll:Ignite( math.Rand( 8, 10 ), 0 ) 
		end

		local bar = ents.Create("env_shake")
		bar:SetPos(self:GetPos())
		bar:SetKeyValue("amplitude","8")
		bar:SetKeyValue("radius","4000")
		bar:SetKeyValue("duration","0.75")
		bar:SetKeyValue("frequency","128")
		bar:Fire( "StartShake", 0, 0 )
		timer.Simple(self.RemoveTimeProps, function()
			if (IsValid(ragdoll)) then
				bar:Remove()
			end
		end)
		
		local blargity = EffectData()
		blargity:SetStart(self:GetPos())
		blargity:SetOrigin(self:GetPos())
		blargity:SetScale(500)
		self.LoopSound:Stop()
		
		util.Effect("HelicopterMegaBomb",blargity)
		util.Effect("ThumperDust",blargity)
		self:StopSound("npc/attack_helicopter/aheli_rotor_loop1.wav")
		self:Remove()
end

function ENT:ResetEnemy()
	local enttable = ents.FindByClass("npc_*")
	local player = player.GetAll()

	if (#player != 0) then
		for _, x in pairs(enttable) do
			if (x:GetClass() != self:GetClass() && x:IsNPC() && x:Disposition(player[1]) == D_HT) then
				x:AddEntityRelationship( self, D_HT, 100 )
			elseif (x:GetClass() != self:GetClass() && x:IsNPC() && x:Disposition(player[1]) == D_LI) then
				x:AddEntityRelationship( self, D_LI, 100 )
			end
		end
	end
end

function ENT:StopSounds()
	self.pequod_pequod_down_1:Stop()
	self.pequod_pequod_down_2:Stop()
	self.pequod_target_shoot:Stop()
	self.pequod_this_is_pequod_1:Stop()
	self.pequod_this_is_pequod_2:Stop()
	self.pequod_back:Stop()
	self.pequod_down_sound:Stop()
	self.pequod_marker:Stop()
	self.LoopSound:Stop()
	self.warningSound:Stop()
end

function ENT:OnRemove()
	self:StopSound("npc/attack_helicopter/aheli_rotor_loop1.wav")
	if self.Smoke then
		self.Smoke:Remove()
	end
	self:StopSounds()
end

function ENT:HasLOS()
	if self.Enemy != NULL then
	local tracedata = {}

	tracedata.start = self:GetPos()
	tracedata.endpos = self.Enemy:GetPos()
	tracedata.filter = self

	local trace = util.TraceLine(tracedata)
		if trace.HitWorld == false then
			return true
		else 
			return false
		end
	end
	return false
end