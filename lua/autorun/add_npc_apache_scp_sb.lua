sound.Add( {
	name = "apache_loop_rotor",
	channel = CHAN_VOICE,
	volume = 1.0,
	level = 100,
	pitch = { 80, 100 },
	sound = "npc/attack_helicopter/aheli_rotor_loop1.wav"
} )

sound.Add( {
	name = "pequod_pequod_down_1",
	channel = CHAN_STATIC,
	volume = 1.0,
	level = 130,
	pitch = 100,
	sound = "apache/pequod_down_1.wav"
} )

sound.Add( {
	name = "pequod_pequod_down_2",
	channel = CHAN_STATIC,
	volume = 1.0,
	level = 130,
	pitch = 100,
	sound = "apache/pequod_down_2.mp3"
} )

sound.Add( {
	name = "pequod_target_shoot",
	channel = CHAN_STATIC,
	volume = 1.0,
	level = 130,
	pitch = 100,
	sound = "apache/target_shoot.mp3"
} )

sound.Add( {
	name = "pequod_this_is_pequod_1",
	channel = CHAN_STATIC,
	volume = 1.0,
	level = 130,
	pitch = 100,
	sound = "apache/this_is_pequod_1.mp3"
} )

sound.Add( {
	name = "pequod_this_is_pequod_2",
	channel = CHAN_STATIC,
	volume = 1.0,
	level = 130,
	pitch = 100,
	sound = "apache/this_is_pequod_2.mp3"
} )

sound.Add( {
	name = "pequod_back",
	channel = CHAN_STATIC,
	volume = 1.0,
	level = 130,
	pitch = 100,
	sound = "apache/back.mp3"
} )

sound.Add( {
	name = "pequod_down_sound",
	channel = CHAN_STATIC,
	volume = 0.5,
	level = 130,
	pitch = 100,
	sound = "apache/down_sound.wav"
} )

sound.Add( {
	name = "pequod_marker",
	channel = CHAN_STATIC,
	volume = 1.0,
	level = 130,
	pitch = 100,
	sound = "apache/marker.mp3"
} )

sound.Add( {
	name = "support_helicopter_requested",
	channel = CHAN_STATIC,
	volume = 1.0,
	level = 130,
	pitch = 100,
	sound = "apache/support_helicopter_requested.mp3"
} )

local Category = "Helicopter"
local NPC = { 	
	Name = "Black Helicopter (Enemy)", 
	Class = "npc_apache_scp_sb",
	Category = Category,
}
list.Set( "NPC", NPC.Class, NPC )

local Category = "Helicopter"
local NPC = { 	
	Name = "Black Helicopter (Enemy)", 
	Class = "npc_apache_scp_sb_new_enemy",
	Category = Category,
}
list.Set( "NPC", NPC.Class, NPC )

local Category = "Helicopter"
local NPC = { 	
	Name = "Black Helicopter (Friend)", 
	Class = "npc_apache_scp_sb_friend",
	Category = Category,
}
list.Set( "NPC", NPC.Class, NPC )

hook.Add( "PlayerSay", "HOOK.FG.Black.Helicopter.PequodFriendSupport", function( ply, text, team )
	local SupportAdd = function()
		local ok = false
		for k, v in pairs(ents.GetAll()) do
			if (v:GetClass() == "npc_apache_scp_sb_friend" && v.Enemy == NULL && !v.PlayerHelp) then
				v.PlayerHelp = true
				v.PlayerHelpID = ply
				v.PatrolPoint = ply:GetPos()
				v.HelpPosition = false
				v.PlayerHelpSoundPlay = true
				ok = true
				ply:EmitSound("apache/support_helicopter_requested.mp3")
				ply:SendLua([[chat.AddText(Color(0, 255, 0), "The helicopter is on the way!")]])
				break
			end
		end

		if (!ok) then
			ply:SendLua([[chat.AddText(Color(255, 0, 0),"At the moment, there are no free helicopters in the air!")]])
		end
	end

	local SimpleCommands = {
		"!helicopter support",
		"!support helicopter",
		"!pequod support",
		"/helicopter support",
		"/support helicopter",
		"/pequod support",
	}

	local find1 = {
		"нужна",
		"требуется",
		"запрашиваю",
		"need",
		"air",
		"request",
	}

	local find2 = {
		"огневая",
		"поддержка",
		"подержка",
		"fire",
		"support",
		"helicopter",
	}

	local find3 = {
		"воздуха",
		"поддержка",
		"ввертолет",
		"вертолета",
		"ввертолёт",
		"вертолёта",
		"support",
		"air",
		"request",
		"helicopter",
	}

	local restext = text:lower()

	if (table.HasValue(SimpleCommands, text:lower())) then
		SupportAdd()
		return text
	else
		for k, f1 in pairs(find1) do
			for k, f2 in pairs(find2) do
				for k, f3 in pairs(find3) do
					local strf1 = string.find(text:lower(), f1:lower())
					local strf2 = string.find(text:lower(), f2:lower())
					local strf3 = string.find(text:lower(), f3:lower())

					if (strf1 && strf2 && strf3) then
						SupportAdd()
						return text
					end
				end
			end
		end
	end
end )

hook.Add("EntityTakeDamage", "npc_apache_scp_sb_EntityTakeDamage", function( ply, dmg )
	local attacker = dmg:GetAttacker();
	local class = attacker:GetClass();
	if ( class == "npc_apache_scp_sb_new_enemy" or class == "proj_dan_heli_shot_scp_sb_fg" ) then
		if ( class == "proj_dan_heli_shot_scp_sb_fg" ) then
			attacker = attacker.Owner;
		end;
		if ( IsValid( attacker ) ) then
			attacker.TurretNotHit = 0;
			attacker.FailHit = 0;
			attacker.LastDamageTimer = CurTime() + 10;
			attacker.LastDamageTimerCheck = attacker.LastDamageTimerCheck + 1;
		end;
	end;
end );


-- concommand.Add("all_copter_dead", function()
-- 	for k, v in ipairs( ents.GetAll() ) do
-- 		if ( v:GetClass() == "npc_apache_scp_sb_new_enemy" ) then
-- 			v:BreakableCopter();
-- 		end;
-- 	end;
-- end);