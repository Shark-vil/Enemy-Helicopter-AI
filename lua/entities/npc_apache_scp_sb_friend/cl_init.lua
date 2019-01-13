include('shared.lua')

--[[
local debugMode = true

if (debugMode) then
	surface.CreateFont( "FGHelicopterEnemy_Debug", {
		font = "Arial",
		extended = false,
		size = 500,
		weight = 500,
		blursize = 0,
		scanlines = 0,
		antialias = true,
		underline = false,
		italic = false,
		strikeout = false,
		symbol = false,
		rotary = false,
		shadow = false,
		additive = false,
		outline = false,
	} )
end
]]

function ENT:Initialize()	
end

function ENT:Draw()
	self.Entity:DrawModel()

	-- local vec = Vector(1469.983887, -2788.099121, 243.759674)
	-- render.SetColorMaterial()
	-- render.DrawSphere(vec, 100, 10, 10, Color(255, 255, 255, 100))
	-- local Ang = LocalPlayer():GetAngles()
	-- Ang:RotateAroundAxis(Ang:Up(), -90)
	-- Ang:RotateAroundAxis(Ang:Right(), 0)
	-- Ang:RotateAroundAxis(Ang:Forward(), 90)
	-- cam.Start3D2D(vec, Ang, 0.15)
	-- 	draw.SimpleTextOutlined( "Control or Target point", "FGHelicopterEnemy_Debug", 0, 0, Color(255, 255, 255, 255), 1, 0, 2, Color( 0, 0, 0 ) )
	-- cam.End3D2D()

	--[[
	if (debugMode) then
		local forward1 = self.Entity:GetAngles():Forward() * 150
		local forward2 = self.Entity:GetAngles():Forward() * 550
		local startpos = self.Entity:GetPos() + forward1 - Vector(0, 0, 100)
		local endpos = self.Entity:GetPos() + forward2 - Vector(0, 0, -30)

		render.DrawLine( startpos, endpos, Color(100, 255, 0), true )

		render.SetColorMaterial()
		render.DrawSphere(endpos, 100, 10, 10, Color(255, 255, 255))

		local right_right_1 = self.Entity:GetAngles():Right() * 150
		local right_right_2 = self.Entity:GetAngles():Right() * 1000
		startpos = self.Entity:GetPos() + right_right_1 - Vector(0, 0, 100)
		endpos = self.Entity:GetPos() + right_right_2 - Vector(0, 0, 100)
		render.DrawLine( startpos, endpos, Color(255, 255, 0), true )

		local right_left_1 = self.Entity:GetAngles():Right() * -150
		local right_left_2 = self.Entity:GetAngles():Right() * -1000
		startpos = self.Entity:GetPos() + right_left_1 - Vector(0, 0, 100)
		endpos = self.Entity:GetPos() + right_left_2 - Vector(0, 0, 100)
		render.DrawLine( startpos, endpos, Color(100, 255, 255), true )

		local right_right_1 = self.Entity:GetAngles():Right() * 150
		local right_right_2 = self.Entity:GetAngles():Right() * 350
		startpos = self.Entity:GetPos() + right_right_1 - Vector(0, 0, 130)
		endpos = self.Entity:GetPos() + right_right_2 - Vector(0, 0, 130)
		render.DrawLine( startpos, endpos, Color(255, 255, 255), true )

		local right_left_1 = self.Entity:GetAngles():Right() * -150
		local right_left_2 = self.Entity:GetAngles():Right() * -350
		startpos = self.Entity:GetPos() + right_left_1 - Vector(0, 0, 130)
		endpos = self.Entity:GetPos() + right_left_2 - Vector(0, 0, 130)
		render.DrawLine( startpos, endpos, Color(255, 255, 255), true )

	
		local tr = util.TraceLine( {
			start = self.Entity:GetPos() + Vector(0, 0, 100),
			endpos = LocalPlayer():GetPos() + Vector(0, 0, 10),
			filter = function( ent ) 
				if ( IsValid(ent) && ent:IsPlayer() && ent:Alive() ) then 
					return true
				end
			end
		} )

		render.DrawLine( self.Entity:GetPos() + Vector(0, 0, 200), self.Entity:GetPos() + Vector(0, 0, 500), Color(255, 50, 255), true )

		if tr.Entity == NULL || tr.Entity:IsWorld() then
			render.DrawLine( self.Entity:GetPos() + Vector(0, 0, -100), LocalPlayer():GetPos() + Vector(0, 0, -5), Color(255, 0, 0), true )
		else
			render.DrawLine( self.Entity:GetPos() + Vector(0, 0, -100), LocalPlayer():GetPos() + Vector(0, 0, -5), Color(100, 0, 30), true )
		end

		render.DrawLine( self.Entity:GetPos() + Vector(0, 10, -100), self.Entity:GetPos() + Vector(0, 10, -300), Color(255, 0, 255), true )

		if (IsValid(self.Entity)) then
			local Ang = LocalPlayer():GetAngles()

			Ang:RotateAroundAxis(Ang:Up(), -90)
			Ang:RotateAroundAxis(Ang:Right(), 0)
			Ang:RotateAroundAxis(Ang:Forward(), 90)
			
			cam.Start3D2D(self.Entity:GetPos() + Vector(0, 0, -150), Ang, 0.15)
				local text = tostring(tr.Entity)
				draw.SimpleTextOutlined( text, "FGHelicopterEnemy_Debug", 0, 0, Color(255,255,255,255 ), 1, 0, 2, Color( 0, 0, 0 ) )
			cam.End3D2D()
		end
	end	
	]]
end