
AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include('shared.lua')

function ENT:Initialize()   
	self.firesound = CreateSound(self,"weapons/rpg/rocket1.wav")

	self.exploded = false
	self.Entity:SetModel( "models/weapons/w_missile_launch.mdl" ) 	
	self.Entity:PhysicsInit( SOLID_VPHYSICS )      
	self.Entity:SetMoveType( MOVETYPE_VPHYSICS )   
	self.Entity:SetSolid( SOLID_VPHYSICS )  
	util.SpriteTrail(self, 0, Color(255,255,255,179), false, 12, 1, 4, 1/(10+1)*0.5, "trails/smoke.vmt");    
	
	self.dietime = CurTime() + 4
	
	self.firesound:Play()
	local phys = self.Entity:GetPhysicsObject()  	
	if (phys:IsValid()) then 		
		phys:Wake()  
		phys:EnableGravity(false) 
	end 
end   

function ENT:OnTakeDamage( dmginfo )
	self.Entity:TakePhysicsDamage( dmginfo )	
end

function ENT:PhysicsCollide()
	if ( self.exploded == false) then
		util.BlastDamage(self.Entity, self.Entity, self.Entity:GetPos(), 350, 250)
		
		local effectdata = EffectData()
		effectdata:SetOrigin(self.Entity:GetPos())
		util.Effect( "Explosion", effectdata )
		
		self.exploded = true
		self:EmitSound("weapons/explode3.wav")
		self.firesound:Stop()
	end
end

function ENT:Think()
	if ( self.dietime < CurTime() ) then
		util.BlastDamage(self.Entity, self.Entity, self.Entity:GetPos(), 350, 250)
		
		local effectdata = EffectData()
		effectdata:SetOrigin(self.Entity:GetPos())
		util.Effect( "Explosion", effectdata )
		
		self.exploded = true
		self:EmitSound("weapons/explode3.wav")
		self.firesound:Stop()
	end

	if self.exploded == true then 
		self:Remove() 
	end

	self:NextThink( CurTime() )

	return true
end