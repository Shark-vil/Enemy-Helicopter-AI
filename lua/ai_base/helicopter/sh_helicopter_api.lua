print("Helicopter api loaded");

HelicopterBase = {};

function HelicopterBase:New(entity)
    local private = {};

    local obj = {};
    obj.entity = entity;

    function obj:GetEntity()
        return self.entity; 
    end

    setmetatable(obj, self);
    self.__index = self;
    return obj;
end;