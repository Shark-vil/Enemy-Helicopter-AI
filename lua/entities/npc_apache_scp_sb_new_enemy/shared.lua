 ENT.Base = "base_ai"
 ENT.Type = "ai"
   
 ENT.PrintName = "Black Helicopter"
 ENT.Author = "Shark_vil by. Xystus234"
 ENT.Contact = "https://steamcommunity.com/groups/fgserv"
 ENT.Purpose = "Helicopter for battles."
 ENT.Instructions = "You can spawn it through the Sandbox menu, in the NPC tab, in the SCP:CB category."
 ENT.Information	= "Security helicopter of the fund."  
 ENT.Category		= "SCP:CB"
  
 ENT.AutomaticFrameAdvance = true
   
 ENT.Spawnable = false
 ENT.AdminSpawnable = false

function ENT:SetAutomaticFrameAdvance( bUsingAnim )
  self.AutomaticFrameAdvance = bUsingAnim
end  