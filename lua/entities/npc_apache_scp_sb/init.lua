AddCSLuaFile( "cl_init.lua" );
AddCSLuaFile( "shared.lua" );
include('shared.lua');

ENT.NoTargetClass = "npc_apache_scp_sb";
ENT.Alert = true;
ENT.Patrol = false;
ENT.Target = NULL;
ENT.MaxHealth = 2000;
ENT.FriendNPCList = {};
ENT.AttackTurretDistance = 2000;
ENT.StartMoveToPlayerDistance = 1500;
ENT.VisibleTargetDistance = 3500;
ENT.RocketToggle = true;
ENT.RocketCoolDown = 0;
ENT.TurretFireTime = 5;
ENT.TurretCoolDownTime = 4;
ENT.TurretCoolDown = false;
ENT.TurretCoolDownCheck = false;
ENT.ShootingIsAllowed = false;
ENT.MovementAllowed = false;
ENT.RocketFire = false;
ENT.TurretFire = false;
ENT.PatrolPos = nil;
ENT.PatrolFind = true;
ENT.PatrolPosReset = 0;
ENT.FailPatrolCoolDown = 0;
ENT.FailPatrolValue = 0;

-- Object initialization
function ENT:Initialize()
	self:SetModel( "models/usmcapachelicopter.mdl" );	
	self.Entity:PhysicsInit( SOLID_VPHYSICS );
	self.Entity:SetMoveType( MOVETYPE_VPHYSICS );   	
	self.Entity:SetSolid( SOLID_VPHYSICS );
	self:CapabilitiesAdd( CAP_MOVE_FLY );
	self:SetPos(self:GetPos() + Vector(0, 0, 250));
	self.PatrolPos = self:GetPos();

	self:SetHealth(self.MaxHealth);
	self:EmitSound("apache_loop_rotor");

	local phy = self.Entity:GetPhysicsObject();  	
	if (phy:IsValid()) then
		phy:Wake();
		phy:EnableGravity(false); 
	end;
end;

function ENT:FindControlPos()
	while (true) do
		local helPos = self:GetPos();
		local vec = Vector( helPos.x + math.random(-500, 500), helPos.y + math.random(-500, 500), helPos.z + math.random(-500, 500) );
		if ( util.IsInWorld(vec) ) then
			self.PatrolPos = vec;
			self.PatrolFind = false;
			self.PatrolPosReset = CurTime() + 5;
			break;
		end;
	end;
end;

-- Called constantly
function ENT:Think()
	if ( GetConVarNumber("ai_disabled") == 1 ) then
		return;
	end;

	local phy = self:GetPhysicsObject();
	self.Target = self:Find();

	if ( not IsValid(self.Target) ) then
		self.Patrol = true;
	elseif ( self.Target:Health() <= 0 ) then
		self.Patrol = true;
		self.Target = NULL;
	elseif ( IsValid(self.Target) ) then
		self.Patrol = false;
	end;
	

	if ( self.Patrol and not IsValid(self.Target) ) then
		if ( self.Patrol and self.PatrolFind ) then
			self:FindControlPos();
		elseif ( not self.PatrolFind and self.PatrolPosReset < CurTime() ) then
			self.PatrolFind = true;
		end;

		self:CheckControlPoint();
	else
		self:CopterFire(self.Target);
	end;

	self:ActionTransform(self.Target, phy);
	self:MoveToTarget(self.Target, phy);
	self:NormalFirePosition(self.Target, phy);
	self:CustomNavigationMove(self.Target, phy);
end;

function ENT:OnTakeDamage(dmg)
	if ( self:Health() <= 0 ) then 
		self:BreakableCopter();
		return; 
	end;

	if ( dmg:IsBulletDamage() ) then
		self:SetHealth( self:Health() - dmg:GetDamage() / math.random(3, 6) );
	elseif ( dmg:IsExplosionDamage() or dmg:GetDamageType() == DMG_BURN ) then
		self:SetHealth( self:Health() - dmg:GetDamage() );
	end;

	if ( self:Health() <= 0 ) then
		self:CopterDown()
	end;
end;

function ENT:BreakableCopter()

end;

function ENT:CopterDown()

end;

function ENT:IsNormalTarget(target)
	if ( not IsValid(target) ) then return; end;
	
	local wantedangle = ( target:GetPos() - self:GetPos() + Vector(0,0,80) ):Angle();
	local anglediff = self:GetAngleDiff( wantedangle.y, self:GetAngles().y );

	if ( anglediff > 130 or anglediff < -130 ) then
		return false;
	elseif ( self:GetPos():Distance( target:GetPos() ) <= self.VisibleTargetDistance ) then
		return true;
	else
		return false;
	end;
end;

function ENT:SetFailPatrol()
	if ( self.Patrol and self.FailPatrolCoolDown < CurTime() ) then
		self.FailPatrolValue = self.FailPatrolValue + 1;

		if ( self.FailPatrolValue > 3 ) then
			self.PatrolFind = true;
			self.FailPatrolValue = 0;
		end;

		self.FailPatrolCoolDown = CurTime() + 3;
	 end;
end;

-- Search for an enemy
function ENT:Find()
	if ( GetConVarNumber("ai_ignoreplayers") == 1 ) then
		return NULL;
	elseif ( not self.Alert ) then
		return NULL;
	elseif ( self.Alert and IsValid(self.Target) ) then
		return self.Target;
	end;

	local objects = ents.GetAll();
	local j = #objects;

	if ( j ~= 0 ) then
		for i = 1, j do
			local target = objects[i];
			if ( target:GetClass() ~= self.NoTargetClass and target:GetClass() ~= "npc_apache_scp_sb_new_enemy" ) then
				if ( target:IsPlayer() ) then
					if ( self:IsNormalTarget(target) ) then
						return target;
					else
						return NULL;
					end;
				elseif ( target:IsNPC() ) then
					if ( target:Disposition(self) == D_HT ) then
						if ( self:IsNormalTarget(target) ) then
							return target;
						else
							return NULL;
						end;
					elseif ( table.HasValue(self.FriendNPCList, target:GetClass()) ) then
						return NULL;
					else
						target:AddEntityRelationship( self, D_HT, 100 )
						if ( self:IsNormalTarget(target) ) then
							return target;
						else
							return NULL;
						end;
					end;
				end;
			end;
		end;
	end;
end;

-- Constant cycle
function ENT:ActionTransform(target, phy)
	-- Hold the desired position for the helicopter.
	if ( IsValid( phy ) ) then
		local angle = self:GetAngles();

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

-- Normal angle for attack
function ENT:NormalFirePosition(target, phy)
	if ( IsValid(target) ) then
		local wantedangle = ( self.Target:GetPos() - self:GetPos() + Vector(0,0,80) ):Angle();
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

-- Calculating the angle of attack
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

-- Verification that the player is above the helicopter.
function ENT:EnemyIsHigher(target)
	if ( self:GetPos().z > target:GetPos().z ) then
		return false;
	else
		return true;
	end;
end;

-- Move to the enemy
function ENT:MoveToTarget(target, phy)
	if ( ( self.Patrol or ( IsValid(phy) ) ) and self.ShootingIsAllowed ) then
		local copterPos = self:GetPos();
		local targetPos = Vector(0, 0, 0);

		if ( self.Patrol ) then
			targetPos = self.PatrolPos;
		elseif ( IsValid(target) ) then
			targetPos = target:GetPos();
		end;

		if ( self.Patrol or copterPos:Distance( targetPos ) >= self.StartMoveToPlayerDistance ) then
			local division = 6;
			local centerPos = Vector(0, 0, 0);
			
			if ( self.Patrol ) then
				phy:ApplyForceCenter( self.PatrolPos * math.random(10, 30) );
			else
				centerPos = Vector( ( targetPos.x - copterPos.x )/division, ( targetPos.y - copterPos.y )/division, ( targetPos.z - copterPos.z )/division );
				phy:ApplyForceCenter( centerPos * math.random(50, 100) );
			end;
		end;
	end;
end;

-- Navigation and avoidance of obstacles
function ENT:CustomNavigationMove(target, phy)
	local tr = util.TraceLine( {
		start = self:GetPos(),
		endpos = self:GetPos() + Vector(0, 0, -650),
		filter = function( ent ) 
			if ( ent:GetClass() == "prop_physics" or ent:GetClass() == "worldspawn" ) then 
				return true;
			end;
		end;
	} );
	
	-- Fly up if the helicopter is too low position
	if ( tr.Hit or ( IsValid(target) and self:EnemyIsHigher(target) ) ) then
		phy:AddVelocity( self:GetAngles():Up() * 2 );
	-- else
	-- 	phy:AddVelocity( self:GetAngles():Up() * -2 );
	end;

	tr = util.TraceLine( {
		start = self:GetPos() + self:GetAngles():Forward() * 150 - Vector(0, 0, 100),
		endpos = self:GetPos() + self:GetAngles():Forward() * 900 - Vector(0, 0, -30),
		filter = function( ent ) 
			if ( ent:GetClass() == "prop_physics" or ent:GetClass() == "worldspawn" ) then 
				return true;
			end;
		end;
	} );

	-- Fly back if there is an obstacle in front
	if ( tr.Hit ) then
		phy:AddVelocity( self:GetAngles():Forward() * -8 );
		self:SetFailPatrol();
	end;
end;

-- Player visibility check
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

-- Check that the control point is reached
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

-- Removing unnecessary parameters
function ENT:OnRemove()
	self:StopSound("apache_loop_rotor");
end;

-- Types of Attack
function ENT:CopterFire(target)
	if ( not self:TargetIsVisible(target) ) then 
		return; 
	end;

	local distanceToTarget = self:GetPos():Distance( target:GetPos() );
	local wantedvector = ( target:GetPos() - self:GetPos() + Vector(0, 0, math.random(0, 25)) );

	-- Rocket or bullet attack
	if ( distanceToTarget > self.AttackTurretDistance and self.RocketFire and not self:EnemyIsHigher(target) and self.RocketCoolDown < CurTime() ) then
		local rocket = ents.Create( "proj_dan_heli_shot_scp_sb_fg" );
		if self.RocketToggle == true then
			rocket:SetPos( self:LocalToWorld( Vector(150, 55, -20) ) );
			self.RocketToggle = false;
		else
			rocket:SetPos( self:LocalToWorld( Vector(150,-55, -20) ) );
			self.RocketToggle = true;
		end
		rocket:SetAngles( self:GetAngles() );
		rocket:Activate();
		rocket:Spawn();
		local rocket_phy = rocket:GetPhysicsObject();
		if rocket_phy:IsValid() then
			rocket_phy:ApplyForceCenter( wantedvector:GetNormalized() * 7500 );
		end;

		self.RocketCoolDown = CurTime() + 1;
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

		if self.TurretCoolDownCheck == false then
			self.TurretCoolDownCheck = true;
			if IsValid(self) then
				timer.Simple(self.TurretFireTime, function()
					self.TurretCoolDown = true;
					if IsValid(self) then
						timer.Simple(self.TurretCoolDownTime, function()
							self.TurretCoolDownCheck = false;
							self.TurretCoolDown = false;
						end);
					end;
				end);
			end;
		end;
	end;
end;