AddCSLuaFile( "cl_init.lua" );
AddCSLuaFile( "shared.lua" );
include('shared.lua');

--[[
	Variables
--]]
ENT.NoTargetClass 				= "npc_apache_scp_sb_new_enemy";
ENT.Patrol 						= false;
ENT.Target 						= NULL;
ENT.MaxHealth 					= 650;
ENT.AttackTurretDistance 		= 2000;
ENT.StartMoveToPlayerDistance 	= 1500;
ENT.VisibleTargetDistance 		= 3500;
ENT.RocketToggle 				= true;
ENT.RocketCoolDown 				= 0;
ENT.TurretFireTime 				= 5;
ENT.TurretCoolDownTime 			= 4;
ENT.TurretCoolDown 				= false;
ENT.TurretCoolDownCheck 		= false;
ENT.ShootingIsAllowed 			= false;
ENT.MovementAllowed 			= false;
ENT.RocketFire 					= false;
ENT.TurretFire 					= false;
ENT.PatrolPos 					= nil;
ENT.PatrolFind 					= true;
ENT.PatrolPosReset 				= 0;
ENT.FailPatrolCoolDown 			= 0;
ENT.FailPatrolValue 			= 0;
ENT.ThinkCoolDown 				= 0;
ENT.TurretNotHit 				= 0;
ENT.FailStep 					= 0;
ENT.FailHit 					= 0;
ENT.LastDamageTimer 			= 0;
ENT.LastDamageTimerCheck 		= CurTime() + 15;
ENT.FailCurTime 				= 0;
ENT.ResetFailCurTime 			= 0;
ENT.CheckMoveRadiusPoint 		= 0;
ENT.HelicopterDown 				= false;
ENT.RemoveTimeProps		 		= 15;
ENT.EnabledFire 				= true;
ENT.IsDead 						= false;
ENT.Smoke 						= nil;
ENT.Speed 						= 0;
ENT.MaxSpeed 					= 20;
ENT.Tilt 						= false;

--[[
	Object initialization
--]]
function ENT:Initialize()
	self:SetModel( "models/usmcapachelicopter.mdl" );	

	self:PhysicsInit( SOLID_VPHYSICS );
	self:SetMoveType( MOVETYPE_VPHYSICS );   	
	self:SetSolid( SOLID_VPHYSICS );
	self:CapabilitiesAdd( CAP_MOVE_FLY );
	self:SetPos( self:GetPos() + Vector( 0, 0, 400 ) );
	self.PatrolPos = self:GetPos();

	self:SetHealth( self.MaxHealth );
	self:EmitSound( "apache_loop_rotor" );

	self.warningSound = CreateSound( self, Sound( "apache/lowhealth.mp3" ) );
	self.pequod_down_sound = CreateSound( self, Sound( "pequod_down_sound" ) );

	local phy = self:GetPhysicsObject();  	
	if ( phy:IsValid() ) then
		phy:Wake();
		phy:EnableGravity( false ); 
	end;

	self:PrioritizationNPC( player.GetCount() );
end;

--[[
	Checkpoint search
--]]
function ENT:FindControlPos()
	local players = player.GetAll();
	local vec;
	local helPos = self:GetPos();
	while ( true ) do
		if ( #players ~= 0 and math.random( 0, 1 ) == 1 and GetConVarNumber( "ai_ignoreplayers" ) == 0 ) then
			local ply = table.Random( players );
			if ( IsValid( ply ) ) then
				helPos = ply:GetPos();
				vec = Vector( helPos.x + math.random( -2000, 2000 ), helPos.y + math.random( -2000, 2000 ), helPos.z + math.random( -100, 100 ) );
			end;
		else
			vec = Vector( helPos.x + math.random( -3000, 3000 ), helPos.y + math.random( -3000, 3000 ), helPos.z + math.random( -1000, 1000 ) );
		end;
		if ( util.IsInWorld( vec ) ) then
			self.PatrolPos = vec;
			self.PatrolFind = false;
			self.PatrolPosReset = CurTime() + 20;
			break;
		end;
	end;
end;

--[[
	Definition of friendly and enemy AI
--]]
function ENT:PrioritizationNPC(pCount)
	if ( pCount == 0 ) then return; end;
	local npcs = ents.FindByClass( "npc*" );
	local npcsCount = table.Count( npcs );
	if ( npcsCount == 0 ) then return; end;
	local players = player.GetAll();
	local ply = NULL;
	for i = 1, pCount do
		if ( IsValid( players[i] ) ) then
			ply = players[i];
			break;
		end;
	end;
	if ( ply == NULL ) then
		MsgN( "No players found for interaction! The helicopter is deleted." );
		self:Remove();
	end;
	for i = 1, npcsCount do
		npc = npcs[i];
		if ( npc:Disposition( ply ) ~= D_HT ) then
			local wep = npc:GetActiveWeapon();
			if ( wep ~= NULL ) then
				if ( npc:Disposition( self ) ~= D_HT ) then
					npc:AddEntityRelationship( self, D_HT, 99 );
				end;
			else
				if ( npc:Disposition( self ) ~= D_FR ) then
					npc:AddEntityRelationship( self, D_FR, 99 );
					npc:SetSchedule( SCHED_BACK_AWAY_FROM_ENEMY );
				end;
			end;
		elseif ( npc:Disposition( self ) ~= D_LI ) then
			npc:AddEntityRelationship( self, D_LI, 99 );
		end;
	end;
end;

--[[
	Interference avoidance
--]]
function ENT:InterferenceAvoidance(phy)
	local objects = ents.FindInSphere( self:GetPos(), 1000 );
	local ang = nil;
	for i = 1, #objects do
		if ( objects[i] ~= self ) then
			ang = ( self:GetPos() - objects[i]:GetPos() );
		end;
	end;

	if ( ang ~= nil ) then
		phy:AddVelocity( ang:Angle():Forward() * math.random( 0, 50 ) );
	end;
end;

--[[
	Called constantly
--]]
function ENT:Think()
	local pCount = player.GetCount();
	if ( pCount == 0 ) then 
		MsgN( "No players found for interaction! The helicopter is deleted." );
		self:Remove();
	end;
	if ( GetConVarNumber( "ai_disabled" ) == 1 or self.HelicopterDown ) then
		return;
	end;

	local phy = self:GetPhysicsObject();
	self.Target = self:Find();

	if ( self.Target ~= NULL and self.LastDamageTimerCheck < CurTime() ) then
		if ( self.LastDamageTimer < ( CurTime() - 10 ) ) then
			self.Target = NULL;
			self.Target = self:Find();
		end;
	end;
	
	if ( not IsValid( self.Target ) ) then
		self.Patrol = true;
	elseif ( self.Target:Health() <= 0 ) then
		self.Patrol = true;
		self.Target = NULL;
	elseif ( IsValid( self.Target ) ) then
		self.Patrol = false;
	end;

	if ( self:WaterLevel() == 1 ) then
		local phy = self:GetPhysicsObject()
		if phy:IsValid() then
			phy:AddVelocity(self.Entity:GetAngles():Up() * 100)
		end
		if ( self.Patrol ) then
			self:FindControlPos();
		end
	elseif ( self:WaterLevel() >= 2 ) then
		self:BreakableCopter()
	end

	if ( self.Patrol and not IsValid( self.Target ) ) then
		if ( self.PatrolFind ) then
			self:FindControlPos();
		elseif ( not self.PatrolFind and self.PatrolPosReset < CurTime() ) then
			self.PatrolFind = true;
		end;

		if ( self.ThinkCoolDown < CurTime() ) then
			self:CheckControlPoint();
		end;
		self.ThinkCoolDown = CurTime() + 1;
	else
		self:CopterFire( self.Target );
	end;

	self:CustomNavigationMove	( self.Target, phy );
	self:ActionTransform		( self.Target, phy );
	self:MoveToTarget			( self.Target, phy );
	self:NormalFirePosition		( self.Target, phy );
	self:InterferenceAvoidance	( phy );
	self:PrioritizationNPC		( pCount );
end;

--[[
	Take helicopter damage
--]]
function ENT:OnTakeDamage( dmg )
	if ( self:Health() <= 0 and self.HelicopterDown ) then 
		self:BreakableCopter();
		return; 
	end;

	if ( dmg:IsBulletDamage() ) then
		self:SetHealth( self:Health() - dmg:GetDamage() / math.random( 3, 6 ) );
	elseif ( dmg:IsExplosionDamage() or dmg:GetDamageType() == DMG_BURN ) then
		self:SetHealth( self:Health() - dmg:GetDamage() );
		local attacker = dmg:GetAttacker();
		if ( IsValid( attacker ) ) then
			self.Target = attacker;
		end;
	elseif ( dmg:IsDamageType( DMG_CRUSH ) ) then
		self:SetHealth( self:Health() - dmg:GetDamage() );
	end;

	if ( self:Health() <= self.MaxHealth/2 ) then
		if ( not self.Smoke ) then
			self.Smoke = self:CreateSmoke();
		end;
		if ( not self.warningSound:IsPlaying() ) then
			self.warningSound:PlayEx( 1, 100 );
		end;
	end;

	if ( self:Health() <= 0 ) then
		self:CopterDown()
	end;
end;

--[[
	Determination of the visibility area of the target
--]]
function ENT:IsNormalTarget(target)
	if ( not IsValid(target) ) then return; end;
	
	local wantedangle = ( target:GetPos() - self:GetPos() + Vector(0,0,80) ):Angle();
	local anglediff = self:GetAngleDiff( wantedangle.y, self:GetAngles().y );

	if ( anglediff > 130 or anglediff < -130 ) then
		return false;
	elseif ( self:GetPos():Distance( target:GetPos() ) <= self.VisibleTargetDistance and self:VisibleVec( target:GetPos() ) ) then
		return true;
	else
		return false;
	end;
end;

--[[
	Reset patrol point
--]]
function ENT:SetFailPatrol()
	if ( self.Patrol and self.FailPatrolCoolDown < CurTime() ) then
		self.FailPatrolValue = self.FailPatrolValue + 1;

		if ( self.FailPatrolValue > 3 ) then
			self.PatrolFind = true;
			self.FailPatrolValue = 0;
		end;

		self.FailStep = 0;
		self.FailPatrolCoolDown = CurTime() + 3;
	 end;
end;

--[[
	Search for an enemy
--]]
function ENT:Find()
	if ( self.FailHit > 10 ) then
		self.FailHit = 0;
		return NULL;
	elseif ( IsValid( self.Target ) ) then
		return self.Target;
	end;

	local objects = ents.GetAll();
	local j = #objects;
	local saveDist = 0;
	local enemy = NULL;

	if ( j ~= 0 ) then
		for i = 1, j do
			local target = objects[i];
			if ( target ~= self ) then
				if ( target:GetClass() ~= self.NoTargetClass and target:GetClass() ~= "npc_apache_scp_sb" ) then
					if ( target:GetClass() == "npc_apache_scp_sb_friend" and self:IsNormalTarget( target ) ) then
						return target;
					elseif ( target:IsPlayer() and GetConVarNumber("ai_ignoreplayers") == 0 and target:Alive() ) then
						if ( self:IsNormalTarget( target ) ) then
							if ( enemy == NULL or self:GetPos():Distance( enemy:GetPos() ) < saveDist ) then
								enemy = target;
								saveDist = self:GetPos():Distance( enemy:GetPos() );
							end;
						end;
					elseif ( target:IsNPC() ) then
						if ( target:Disposition( self ) ~= D_LI and self:IsNormalTarget( target ) ) then
							if ( enemy == NULL or self:GetPos():Distance( enemy:GetPos() ) < saveDist ) then
								enemy = target;
								saveDist = self:GetPos():Distance( enemy:GetPos() );
							end;
						end;
					end;
				end;
			end;
		end;
	end;

	if ( enemy ~= NULL ) then
		self.LastDamageTimerCheck = CurTime() + 15;
	end;

	return enemy;
end;

--[[
	Constant cycle
--]]
function ENT:ActionTransform(target, phy)
	-- Hold the desired position for the helicopter.
	if ( IsValid( phy ) ) then
		local angle = self:GetAngles();
		local warn = false;

		if ( angle.z < -80 or angle.z > 80 ) then
			phy:AddVelocity( self:GetAngles():Up() * math.random( 30, 50 ) );
			warn = true;
			if ( not self.Tilt ) then
				self.Tilt = true;
			end;
		end;

		if ( angle.x < -75 or angle.x > 60 ) then
			phy:AddVelocity( self:GetAngles():Up() * math.random( 30, 50 ) );
			warn = true;
			if ( not self.Tilt ) then
				self.Tilt = true;
			end;
		end;

		if ( not warn and self.Tilt ) then
			self.Tilt = false;
		end;

		if ( angle.x < 0 ) then
			phy:AddAngleVelocity( Vector( 0, math.random( 6, 16 ), 0 ) );
		elseif ( angle.x > 40 ) then
			phy:AddAngleVelocity( Vector( 0, math.random( -6, -16 ), 0 ) );
		elseif ( angle.x < 18 ) then
			phy:AddAngleVelocity( Vector( 0, math.random( 1, 3 ), 0 ) );
		elseif ( angle.x > 23 ) then
			phy:AddAngleVelocity( Vector( 0, math.random( -1, -3 ), 0 ) );
		end;

		if ( angle.z < -30 ) then
			phy:AddAngleVelocity( Vector( math.random( 10, 30 ), 0, 0 ) );
		elseif ( angle.z > 30 ) then
			phy:AddAngleVelocity( Vector( math.random( -10, -30 ), 0, 0 ) );
		elseif ( angle.z < -2 ) then
			phy:AddAngleVelocity( Vector( math.random( 0.5, 1.5 ), 0, 0 ) );
		elseif ( angle.z > 2 ) then
			phy:AddAngleVelocity( Vector( math.random( -0.5, -1.5 ), 0, 0 ) );
		end;
	end;
	
	-- Turning the shooting on or off, depending on the angle
	-- Normalization of the angle of attack of the helicopter
	if ( IsValid(target) or self.Patrol ) then
		local wantedangle = Vector(0, 0, 0);
		
		if ( self.Patrol ) then
			wantedangle = ( self.PatrolPos - self:GetPos() + Vector(0, 0, 80) ):Angle();
		elseif ( IsValid(target) ) then
			wantedangle = ( target:GetPos() - self:GetPos() + Vector(0, 0, 80) ):Angle();
		end;

		local anglediff = self:GetAngleDiff( wantedangle.y, self:GetAngles().y );
		
		if ( anglediff > -35 and anglediff < 35 ) then
			self.ShootingIsAllowed = true;
		else

			if ( self.Speed > 0 ) then
				self.Speed = self.Speed - math.random( 10, 20 );
			elseif ( self.Speed < 0 ) then
				self.Speed = 0;
			end;

			self.ShootingIsAllowed = false;
		end;

		if anglediff < 2 and anglediff > -20 then
			phy:AddAngleVelocity( Vector( 0, 0, math.random(-1, -2) ) );
		elseif anglediff > -2 and anglediff < 20 then
			phy:AddAngleVelocity( Vector( 0, 0, math.random(1, 2) ) );
		elseif anglediff < 20 then
			phy:AddAngleVelocity( Vector( 0, 0, math.random(-5, -15) ) );
		elseif anglediff > -20 then
			phy:AddAngleVelocity( Vector( 0, 0, math.random(5, 15) ) );
		end;
	end;
end;

--[[
	Normal angle for attack
--]]
function ENT:NormalFirePosition(target, phy)
	if ( IsValid(target) ) then
		local wantedangle = ( self.Target:GetPos() - self:GetPos() + Vector( 0, 0, 80 ) ):Angle();
		local anglediff = self:GetAngleDiff( wantedangle.y, self:GetAngles().y );

		if ( anglediff <= 5 and anglediff >= -5 ) then
			self.RocketFire = true;
			self.TurretFire = true;
		elseif ( anglediff <= 40 and anglediff >= -40 ) then
			self.RocketFire = false;
			self.TurretFire = true;
		else
			self.RocketFire = false;
			self.TurretFire = false;
		end;
	else
		self.RocketFire = false;
		self.TurretFire = false;
	end;
end;

--[[
	Calculating the angle of attack
--]]
function ENT:GetAngleDiff(angle1, angle2)
	local result = angle1 - angle2;
	if result < -180 then
		result = result + 360;
	end;

	if result > 180 then
		result = result - 360;
	end;
	
	return result;
end;

--[[
	Verification that the player is above the helicopter.
--]]
function ENT:EnemyIsHigher(target)
	if ( self:GetPos().z > target:GetPos().z ) then
		return false;
	else
		return true;
	end;
end;

--[[
	Move to the enemy
--]]
function ENT:MoveToTarget(target, phy)
	if ( ( self.Patrol or ( IsValid( phy ) ) ) and self.ShootingIsAllowed ) then
		local copterPos = self:GetPos();
		local targetPos = Vector( 0, 0, 0 );

		if ( self.Patrol ) then
			targetPos = self.PatrolPos;
		elseif ( IsValid(target) ) then
			targetPos = target:GetPos();
		end;

		if ( self.Patrol or copterPos:Distance( targetPos ) >= self.StartMoveToPlayerDistance ) then
			local division = 6;
			local centerPos = Vector(0, 0, 0);

			if ( self.Speed ~= self.MaxSpeed ) then
				self.Speed = self.Speed + 1;
			elseif ( self.Speed > self.MaxSpeed ) then
				self.Speed = self.MaxSpeed;
			end;
			
			if ( self.Patrol ) then
				centerPos = Vector( ( targetPos.x - copterPos.x ), ( targetPos.y - copterPos.y ), ( targetPos.z - copterPos.z ) );
				phy:ApplyForceCenter( centerPos * self.Speed );
			else
				centerPos = Vector( ( targetPos.x - copterPos.x )/division, ( targetPos.y - copterPos.y )/division, ( targetPos.z - copterPos.z )/division );
				phy:ApplyForceCenter( centerPos * self.Speed );
			end;
		end;
	end;
end;

--[[
	Navigation and avoidance of obstacles
--]]
function ENT:CustomNavigationMove(target, phy)
	if ( IsValid( target ) ) then
		if ( self:GetPos():Distance( target:GetPos() ) < 700  ) then
			phy:AddVelocity( self:GetAngles():Forward() * -math.random( 0, 60 ) );
		end;
	end;
	local tr = util.TraceLine( {
		start = self:GetPos(),
		endpos = self:GetPos() + Vector(0, 0, -400),
		filter = function( ent ) 
			if ( ent ~= self ) then 
				return true;
			end;
		end;
	} );

	-- Fly up if the helicopter is too low position
	if ( tr.Hit or ( IsValid( target ) and self:EnemyIsHigher( target ) ) ) then
		phy:AddVelocity( self:GetAngles():Up() * math.random( 50, 70 ) );
		if ( tr.HitPos:Distance( self:GetPos() ) < 350 and self.Tilt ) then
			local d = DamageInfo();
			d:SetDamage( 1000 );
			d:SetAttacker( self );
			d:SetDamageType( DMG_CRUSH );
			self:TakeDamageInfo( d );
		end;
	end;

	tr = util.TraceLine( {
		start = self:GetPos(),
		endpos = self:GetPos() + Vector(0, 0, 800),
		filter = function( ent ) 
			if ( ent ~= self ) then 
				return true;
			end;
		end;
	} );

	-- Fly down if the helicopter is too hight position
	if ( tr.Hit or ( IsValid( target ) and self:EnemyIsHigher( target ) ) ) then
		phy:AddVelocity( self:GetAngles():Up() * -50 );
	end;

	local isHit = false;
	local pos, r, x, y, new_pos;
	for i = 1, 125 do
		pos = self:GetPos() + Vector( 0, 0, -50 ) + ( self:GetAngles():Forward() * -100 );
		r = 500;
		x = r * math.cos( self.CheckMoveRadiusPoint );
		y = r * math.sin( self.CheckMoveRadiusPoint );
		new_pos = pos + Vector( x, y, 0 );
		self.CheckMoveRadiusPoint = self.CheckMoveRadiusPoint + 0.1;
		if ( self.CheckMoveRadiusPoint > 12.5 ) then
			self.CheckMoveRadiusPoint = 0;
		end

		tr = util.TraceLine( {
			start = pos,
			endpos = new_pos,
			filter = function( ent ) 
				if ( ent ~= self ) then 
					return true;
				end;
			end;
		} );

		if ( tr.Hit ) then
			isHit = true;
			if ( tr.HitPos:Distance( self:GetPos() ) < 150 and self.Tilt ) then
				local d = DamageInfo();
				d:SetDamage( 1000 );
				d:SetAttacker( self );
				d:SetDamageType( DMG_CRUSH );
				self:TakeDamageInfo( d );
			end;
			break;
		end;
	end;

	-- Fly back if there is an obstacle in front
	if ( self.FailStep ~= 0 and self.ResetFailCurTime < CurTime() ) then
		if ( self.FailStep < 3 ) then
			self.FailStep = self.FailStep - 1;
			if ( self.FailStep < 0 ) then
				self.FailStep = 0;
			end;
			self.ResetFailCurTime = CurTime() + 3;
		end;
	end;
	if ( isHit ) then
		local ang = ( pos - new_pos ):Angle();
		phy:AddVelocity( ang:Forward() * 80 );
		if ( self.FailStep ~= 3 and self.FailCurTime < CurTime() ) then
			self.FailStep = self.FailStep + 1;
			if ( self.FailStep == 3 ) then
				self.FailCurTime = -1;
			else
				self.FailCurTime = CurTime() + 1;
				self.ResetFailCurTime = CurTime() + 3;
			end;
		end;
	end;

	if ( self.FailStep >= 3 ) then
		phy:AddVelocity( self:GetAngles():Up() * 40 );
		if ( self.FailCurTime == -1 ) then
			self.FailCurTime = CurTime() + 5;
		end;
		if ( self.FailCurTime < CurTime() ) then
			self.FailStep = 0;
			self.FailCurTime = 0;
			self.ResetFailCurTime = 0;
			self:SetFailPatrol();
		end;
	end;
end;

--[[
	Player visibility check
--]]
function ENT:TargetIsVisible(target)
	if ( IsValid(target) ) then
		if ( self:VisibleVec( target:GetPos() ) or ( target:VisibleVec( self:GetPos() ) and math.random(-50, 50) == 0 ) ) then
			return true;
		else
			return false;
		end;
	else
		return false;
	end;
end;

--[[
	Check that the control point is reached
--]]
function ENT:CheckControlPoint()
	if ( self.Patrol ) then
		local objects = ents.FindInSphere( self.PatrolPos, 500 );
		local j = #objects;

		for i = 1, j do
			if ( objects[i] == self ) then
				self.PatrolFind = true;
				self.FailPatrolValue = 0;
				break;
			end;
		end;
	end;
end;

--[[
	Removing unnecessary parameters
--]]
function ENT:OnRemove()
	self:StopSound( "apache_loop_rotor" );
	
	if ( self.Smoke ) then
		self.Smoke:Remove()
	end;

	if ( self.warningSound:IsPlaying() ) then
		self.warningSound:Stop();
	end;
	
	if ( self.pequod_down_sound:IsPlaying() ) then
		self.pequod_down_sound:Stop();
	end;
end;

--[[
	Types of Attack
--]]
function ENT:CopterFire(target)
	if ( not self:TargetIsVisible(target) ) then 
		return; 
	end;

	local distanceToTarget = self:GetPos():Distance( target:GetPos() );
	local wantedvector = ( target:GetPos() - self:GetPos() + Vector( 0, 0, math.random(0, 25) ) );

	-- Rocket or bullet attack
	if ( ( distanceToTarget > self.AttackTurretDistance or self.TurretNotHit > 6 ) and self.RocketFire and not self:EnemyIsHigher( target ) and self.RocketCoolDown < CurTime() ) then
		local rocket = ents.Create( "proj_dan_heli_shot_scp_sb_fg" );
		local npcs = ents.FindInSphere( target:GetPos(), 300 );
		if ( self.RocketToggle == true ) then
			rocket:SetPos( self:LocalToWorld( Vector(150, 55, -20) ) );
			self.RocketToggle = false;
		else
			rocket:SetPos( self:LocalToWorld( Vector(150,-55, -20) ) );
			self.RocketToggle = true;
		end
		rocket.Owner = self;
		rocket:SetAngles( self:GetAngles() );
		rocket:Activate();
		local npcs = ents.FindInSphere( target:GetPos(), 1000 );
		if ( #npcs ~= 0 ) then
			for i = 1, #npcs do
				local npc = npcs[i];
				if ( IsValid( npc ) and npc:IsNPC() ) then
					npc:SetSchedule( SCHED_RUN_RANDOM );
				end;
			end;
		end;
		rocket:Spawn();
		local rocket_phy = rocket:GetPhysicsObject();
		if ( rocket_phy:IsValid() ) then
			rocket_phy:ApplyForceCenter( wantedvector:GetNormalized() * 7500 );
		end;
		self.TurretNotHit = 0;
		self.RocketCoolDown = CurTime() + 1;
		self.FailHit = self.FailHit + 1;
	elseif ( distanceToTarget <= self.AttackTurretDistance and self.TurretFire and not self:EnemyIsHigher(target) and not self.TurretCoolDown ) then
		local bullet 		= {};
		bullet.Num 			= 4;
		bullet.Src 			= self:GetPos() + self:GetForward() * 150;
		bullet.Damage 		= math.random(5, 15);
		bullet.Force		= 200;
		bullet.Tracer		= 1;
		bullet.Spread		= Vector( 12 / 90, 12 / 90, 0 );
		bullet.Dir 			= wantedvector:GetNormalized();
		self:FireBullets( bullet );
		self:EmitSound("apache/fire.wav",500,100);

		if ( self.TurretCoolDownCheck == false ) then
			self.TurretCoolDownCheck = true;
			if ( IsValid( self ) ) then
				timer.Simple( self.TurretFireTime, function()
					if IsValid( self ) then
						self.TurretCoolDown = true;
						self.TurretNotHit = self.TurretNotHit + 1;
						self.FailHit = self.FailHit + 1;
						timer.Simple( self.TurretCoolDownTime, function()
							self.TurretCoolDownCheck = false;
							self.TurretCoolDown = false;
						end );
					end;
				end );
			end;
		end;
	end;
end;

--[[
	Animation of a helicopter crash
--]]
function ENT:CopterDown()
	local velocityZAdd = -30;
	local velocityAngleZAdd = 80;
	self.HelicopterDown = true;

	if ( math.random( 0, 100 ) > 80 ) then
		self:BreakableCopter();
		return;
	end;

	local timerName = tostring( self:EntIndex() ).."_copter_break_"..tostring( CurTime() );
	timer.Create( timerName, 0.1, 0, function()
		if self:IsValid() then
			local phy = self:GetPhysicsObject();
			phy:AddAngleVelocity( Vector( 0, 0, velocityAngleZAdd ) );
			velocityAngleZAdd = velocityAngleZAdd + 1;
			phy:SetVelocity( Vector( 0, 0, velocityZAdd ) );
			velocityZAdd = velocityZAdd - math.random(3, 10);

			local tr = util.TraceLine( {
				start = self:GetPos() + Vector( 0, 0, -100 ),
				endpos = self:GetPos() + Vector( 0, 0, -180 ),
			} );

			if ( tr.Entity ~= NULL ) then
				timer.Remove( timerName );
				self:BreakableCopter();
			end;
		elseif ( self.IsDead ) then 
			timer.Remove( timerName );
			return;
		end;
	end );

	self.pequod_down_sound:Play();
	self.pequod_down_sound:PlayEx( 0.5, 100 );
end;


--[[
	Create breakable props and remove self
--]]
function ENT:BreakableCopter()
	self.IsDead = true;

	local ragdoll = ents.Create( "prop_physics" );
	ragdoll:SetModel( "models/apgb/helicopter_brokenpiece_06_body.mdl" );
	ragdoll:SetPos( self:GetPos() );
	ragdoll:SetAngles( self:GetAngles() );
	ragdoll:SetSkin( self:GetSkin() );
	ragdoll:SetColor( self:GetColor() );
	ragdoll:SetMaterial( self:GetMaterial() );
	if ( self.EnabledFire ) then 
		ragdoll:Ignite( math.Rand( 8, 10 ), 0 ) ;
	end;
	ragdoll:Spawn();
	timer.Simple( self.RemoveTimeProps, function()
		if ( IsValid( ragdoll ) ) then
			ragdoll:Remove();
		end;
	end );
	local fire = ents.Create("env_fire_trail");
	fire:SetPos( ragdoll:GetPos() + Vector(0, 0, 50) );
	fire:SetParent( ragdoll );
	fire:Spawn();

	local effectdata = EffectData();
	effectdata:SetStart( ragdoll:GetPos() );
	effectdata:SetOrigin( ragdoll:GetPos() );
	effectdata:SetScale( 50 );
	util.Effect( "Explosion", effectdata );
	util.Effect( "grenade_explosion_01", effectdata );
	util.Effect( "HelicopterMegaBomb", effectdata );
	timer.Simple( 0.7, function()
		if ( IsValid( ragdoll) ) then
			effectdata:SetStart( ragdoll:GetPos() );
			effectdata:SetOrigin( ragdoll:GetPos() );
			util.Effect( "Explosion", effectdata );
			util.Effect( "striderbuster_break_explode", effectdata );
			util.Effect( "HelicopterMegaBomb", effectdata );
			util.BlastDamage( ragdoll, ragdoll, ragdoll:GetPos(), 300, 300 );
		end;
	end );

	local ragdoll = ents.Create( "prop_physics" );
	ragdoll:SetModel( "models/apgb/helicopter_brokenpiece_04_cockpit.mdl" );
	ragdoll:SetPos( self:GetPos() );
	ragdoll:SetAngles( self:GetAngles() );
	ragdoll:Spawn();
	ragdoll:SetSkin( self:GetSkin() );
	ragdoll:SetColor( self:GetColor() );
	ragdoll:SetMaterial( self:GetMaterial() );
	if ( self.EnabledFire ) then 
		ragdoll:Ignite( math.Rand( 8, 10 ), 0 ) ;
	end;
	timer.Simple( self.RemoveTimeProps, function()
		if ( IsValid( ragdoll ) ) then
			ragdoll:Remove();
		end;
	end );
	timer.Simple( 1, function()
		if ( IsValid( ragdoll ) ) then
			effectdata:SetStart( ragdoll:GetPos() );
			effectdata:SetOrigin( ragdoll:GetPos() );
			util.Effect( "Explosion", effectdata );
			util.Effect( "HelicopterMegaBomb", effectdata );
			util.Effect( "building_explosion", effectdata );
			util.BlastDamage( ragdoll, ragdoll, ragdoll:GetPos(), 300, 300 );
		end;
	end );

	local ragdollPilot = ents.Create( "prop_ragdoll" );
	ragdollPilot:SetModel( "models/player/ct_sas.mdl" );
	ragdollPilot:SetPos( ragdoll:GetPos() + Vector( -50, 0, 0 ) );
	ragdollPilot:SetCollisionGroup( COLLISION_GROUP_WORLD );
	ragdollPilot:SetColor( Color( 150, 150, 150, 255 ) );
	ragdollPilot:Spawn();
	if ( self.EnabledFire ) then 
		ragdollPilot:Ignite( self.RemoveTimeProps, 0 );
	end;
	timer.Simple( self.RemoveTimeProps, function()
		if ( IsValid( ragdollPilot ) ) then
			ragdollPilot:Remove();
		end;
	end );

	local ragdollPilot = ents.Create( "prop_ragdoll" );
	ragdollPilot:SetModel( "models/player/ct_sas.mdl" );
	ragdollPilot:SetPos( ragdoll:GetPos() + Vector( 50, 0, 0 ) );
	ragdollPilot:SetCollisionGroup( COLLISION_GROUP_WORLD );
	ragdollPilot:SetColor( Color( 150, 150, 150, 255 ) );
	ragdollPilot:Spawn();
	if ( self.EnabledFire ) then 
		ragdollPilot:Ignite( self.RemoveTimeProps, 0 ) ;
	end;
	timer.Simple( self.RemoveTimeProps, function()
		if ( IsValid( ragdollPilot ) ) then
			ragdollPilot:Remove();
		end;
	end );

	local ragdoll = ents.Create( "prop_physics" );
	ragdoll:SetModel( "models/apgb/helicopter_brokenpiece_05_tailfan.mdl" );
	ragdoll:SetPos( self:LocalToWorld( Vector(-100,0,0) ) );
	ragdoll:SetAngles( self:GetAngles() );
	ragdoll:Spawn();
	ragdoll:SetSkin( self:GetSkin() );
	ragdoll:SetColor( self:GetColor() );
	ragdoll:SetMaterial( self:GetMaterial() );
	timer.Simple( self.RemoveTimeProps, function()
		if ( IsValid( ragdoll ) ) then
			ragdoll:Remove();
		end;
	end );
	if ( self.EnabledFire ) then 
		ragdoll:Ignite( math.Rand( 8, 10 ), 0 ) ;
	end;
	timer.Simple( 0.3, function()
		if ( IsValid( ragdoll ) ) then
			effectdata:SetStart( ragdoll:GetPos() );
			effectdata:SetOrigin( ragdoll:GetPos() );
			util.Effect( "Explosion", effectdata );
			util.Effect( "Explosion_2", effectdata );
			util.BlastDamage( ragdoll, ragdoll, ragdoll:GetPos(), 300, 300 );
		end;
	end );
	timer.Simple( 1.4, function()
		if ( IsValid( ragdoll ) ) then
			effectdata:SetStart( ragdoll:GetPos() );
			effectdata:SetOrigin( ragdoll:GetPos() );
			util.Effect( "Explosion", effectdata );
			util.Effect( "HelicopterMegaBomb", effectdata );
			util.Effect( "building_explosion", effectdata );
			util.BlastDamage( ragdoll, ragdoll, ragdoll:GetPos(), 300, 300 );
		end;
	end );

	local bar = ents.Create( "env_shake" );
	bar:SetPos( self:GetPos() );
	bar:SetKeyValue( "amplitude","8" );
	bar:SetKeyValue( "radius","4000" );
	bar:SetKeyValue( "duration","0.75" );
	bar:SetKeyValue( "frequency","128" );
	bar:Fire( "StartShake", 0, 0 );
	timer.Simple( self.RemoveTimeProps, function()
		if ( IsValid( ragdoll ) ) then
			bar:Remove();
		end;
	end );
	
	local blargity = EffectData();
	blargity:SetStart( self:GetPos() );
	blargity:SetOrigin( self:GetPos() );
	blargity:SetScale( 500 );
	
	util.Effect( "HelicopterMegaBomb", blargity );
	util.Effect( "ThumperDust", blargity );

	self:Remove();
end;

--[[
	Create damage effect
--]]
function ENT:CreateSmoke()
	local smoke = ents.Create( "env_smokestack" );
	smoke:SetPos( self:GetPos() );
	smoke:SetAngles( self:GetAngles()+Angle( -90, 0, 0 ) );
	smoke:SetKeyValue( "InitialState", "1" );
	smoke:SetKeyValue( "WindAngle", "0 0 0" );
	smoke:SetKeyValue( "WindSpeed", "0" );
	smoke:SetKeyValue( "rendercolor", "170 170 170" );
	smoke:SetKeyValue( "renderamt", "170" );
	smoke:SetKeyValue( "SmokeMaterial", "particle/smokesprites_0001.vmt" );
	smoke:SetKeyValue( "BaseSpread", "2" );
	smoke:SetKeyValue( "SpreadSpeed", "2" );
	smoke:SetKeyValue( "Speed", "50" );
	smoke:SetKeyValue( "StartSize", "10" );
	smoke:SetKeyValue( "EndSize", "150" );
	smoke:SetKeyValue( "roll", "10" );
	smoke:SetKeyValue( "Rate", "15" );
	smoke:SetKeyValue( "JetLength", "70" );
	smoke:SetKeyValue( "twist", "5" );
	smoke:Spawn();
	smoke:SetParent( self.Entity );
	smoke:Activate();
	return smoke;
end;