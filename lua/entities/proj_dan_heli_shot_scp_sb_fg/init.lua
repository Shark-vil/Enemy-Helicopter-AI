
AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include('shared.lua')

function ENT:Initialize()   
	self.firesound = CreateSound(self,"weapons/rpg/rocket1.wav")

	self.exploded = false
	self.health = 200;
	self:SetModel( "models/weapons/w_missile_launch.mdl" ) 	
	self:PhysicsInit( SOLID_VPHYSICS )      
	self:SetMoveType( MOVETYPE_VPHYSICS )   
	self:SetSolid( SOLID_VPHYSICS )  
	util.SpriteTrail(self, 0, Color(255,255,255,179), false, 12, 1, 4, 1/(10+1)*0.5, "trails/smoke.vmt");    
	
	self.dietime = CurTime() + 4
	
	self.firesound:Play()
	local phys = self:GetPhysicsObject()  	
	if (phys:IsValid()) then 		
		phys:Wake()  
		phys:EnableGravity(false) 
	end 
end   

function ENT:OnTakeDamage( dmginfo )
	if !IsValid(self) || self.exploded then return end

	self.health = self.health - dmginfo:GetDamage()

	if ( self.health <= 0 ) then
		self:StartExplosion()
	end
end

function ENT:PhysicsCollide()
	if !IsValid(self) || self.exploded then return end
	self:StartExplosion()
end

function ENT:StartExplosion()
	if !IsValid(self) || self.exploded then return end
	self.exploded = true

	util.BlastDamage(self, self, self:GetPos(), 350, 250)
	
	local effectdata = EffectData()
	effectdata:SetOrigin(self:GetPos())
	util.Effect( "Explosion", effectdata )
	
	self:EmitSound("weapons/explode3.wav")
	self.firesound:Stop()

	self:Remove()
end

function ENT:Think()
	if !IsValid(self) then return end

	if ( !self.exploded ) then
		if ( self.dietime < CurTime() ) then
			self:StartExplosion()
		end
	end
end