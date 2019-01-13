include('shared.lua')

function ENT:Initialize()	
end

local point= 0
function ENT:Draw()
	self.Entity:DrawModel()
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