include('shared.lua')

function ENT:Initialize()	
end

local point= 0
function ENT:Draw()
	self:DrawModel()

	-- render.SetColorMaterial();
	
	-- local mat = Material("models/weapons/v_slam/new light1");
	-- mat:SetFloat( "$alpha", 0.7 );
	-- render.SetMaterial( mat );
	-- render.DrawSphere( self:GetPos() + ( self:GetAngles():Forward() * -365 ), 5, 15, 15, Color( 255, 0, 0, 100 ) );
	-- render.DrawSphere( self:GetPos() + ( self:GetAngles():Forward() * -365 ), 5, 15, 15, Color( 255, 0, 0, 100 ) );

	-- local pos = self:GetPos() + Vector(0, 0, -50) + ( self:GetAngles():Forward() * -100 );
	-- local r = 600
	-- local x = r*math.cos(point)
	-- local y = r*math.sin(point)
	-- point = point + 0.1
	-- if ( point > 12.5 ) then
	-- 	point = 0
	-- end
	-- render.DrawLine( pos, pos + Vector(x, y, 0), Color(255, 0, 0), true )
end