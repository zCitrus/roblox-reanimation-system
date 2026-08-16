local Config = {
    -- Godmode / Hitbox Desync
    Godmode = true,                          -- Offsets real hitbox to make swords/touch hitboxes miss
    GodmodeOffset = Vector3.new(0, 100, 0),  -- Teleports real body 100 studs into the air

    -- Visuals & Rig Setup
    RigTransparency = 0,                     -- 0 = fully visible rig, 1 = invisible
    HideRealCharacter = true,                -- Makes the real character invisible
    R15 = false,                             -- Set to true if you use R15 avatar

    -- Controls & Camera
    SetCameraSubject = true,                 -- Locks camera to the visual rig
    MirrorAnimations = true,                 -- Mirrors real character walking/jumping
}

return Config
