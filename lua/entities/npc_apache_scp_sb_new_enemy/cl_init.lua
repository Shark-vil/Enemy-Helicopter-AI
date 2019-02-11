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
	-- render.DrawSphere( self:GetAngles():Forward() * -365, 5, 15, 15, Color( 255, 0, 0, 100 ) );


	-- -- Радиус
	-- local pos = self:GetPos() + Vector(0, 0, -110);
	-- local r = 600
	-- local x = r*math.cos( point )
	-- local y = r*math.sin( point )
	-- point = point + 0.1
	-- if ( point > 12.5 ) then
	-- 	point = 0
	-- end
	-- render.DrawLine( pos, pos + Vector( x, y, 0 ), Color( 255, 0, 0 ), true )
	-- render.DrawLine( pos + Vector( 0, 0, 260 ), pos + Vector( x, y, 260 ), Color(255, 0, 0), true )

	-- -- Верх
	-- local startpos = self:GetPos();
	-- local endpos = self:GetPos() + Vector( 0, 0, 400 );
	-- render.DrawLine( startpos, endpos, Color( 255, 100, 0 ), true )

	-- -- Низ
 	-- startpos = self:GetPos();
	-- endpos = self:GetPos() + Vector( 0, 0, -700 );
	-- render.DrawLine( startpos, endpos, Color( 255, 100, 0 ), true )
end