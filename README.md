# Roblox Reanimation System

A modernized, respawn-tolerant reanimation system for Luau and Roblox environments.

## Features
- Patched for modern server-authoritative character loading.
- Removed deprecated C++ backend signal hooks.
- Automatic respawn listener (`CharacterAdded` re-binding).
- Dynamic accessory attachment and physics velocity preservation.

## Quick Execution

```lua
_G.Config = {
    RigTransparency = 1,
    R15 = false,
    BreakJointsDelay = 0.1,
    SetCameraSubject = true,
}

loadstring(game:HttpGet("https://raw.githubusercontent.com/zCitrus/roblox-reanimation-system/main/reanimation.lua"))()
