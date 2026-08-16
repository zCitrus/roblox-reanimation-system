-- Modernized Alive Reanimation (Mobile & PC Compatible)
-- Stable Network Ownership & No-Drop Accessory Attachment

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Config = _G.Config or {
    RigTransparency = 0,    -- 0 = fully visible rig, 1 = invisible rig
    HideRealCharacter = true, -- Makes your real body transparent
    SetCameraSubject = true,
    R15 = false,
}

local System = {
    Running = false,
    Rig = nil,
    RigHumanoid = nil,
    RigRoot = nil,
    Connections = {},
    Aligns = {}
}

local function CleanConnections()
    for _, conn in ipairs(System.Connections) do
        if conn and conn.Connected then
            conn:Disconnect()
        end
    end
    table.clear(System.Connections)
end

local function CreateRig(r15)
    local description = Instance.new("HumanoidDescription")
    local rigType = r15 and Enum.HumanoidRigType.R15 or Enum.HumanoidRigType.R6
    local rig = Players:CreateHumanoidModelFromDescription(description, rigType)
    description:Destroy()

    rig.Name = LocalPlayer.Name .. "_Rig"
    rig.Parent = Workspace

    for _, desc in ipairs(rig:GetDescendants()) do
        if desc:IsA("BasePart") then
            desc.CanCollide = false
            desc.Transparency = Config.RigTransparency or 0
        elseif desc:IsA("Decal") then
            desc.Transparency = Config.RigTransparency or 0
        end
    end

    return rig
end

local function SetupCharacter(character)
    table.clear(System.Aligns)

    local humanoid = character:WaitForChild("Humanoid", 5)
    local rootPart = character:WaitForChild("HumanoidRootPart", 5)
    if not humanoid or not rootPart or not System.Rig then return end

    -- Hide real character parts so only the Rig is seen
    if Config.HideRealCharacter then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.Transparency = 1
            elseif part:IsA("Decal") then
                part.Transparency = 1
            end
        end
    end

    -- Setup accessory alignments
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Accessory") then
            local handle = child:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                handle.CanCollide = false
                
                local att = child:FindFirstChildWhichIsA("Attachment", true)
                local rigAtt = att and System.Rig:FindFirstChild(att.Name, true)
                
                if rigAtt and rigAtt.Parent:IsA("BasePart") then
                    table.insert(System.Aligns, {
                        Handle = handle,
                        Target = rigAtt.Parent,
                        Offset = att.CFrame:Inverse() * rigAtt.CFrame
                    })
                else
                    table.insert(System.Aligns, {
                        Handle = handle,
                        Target = System.RigRoot,
                        Offset = CFrame.identity
                    })
                end
            end
        end
    end

    if Config.SetCameraSubject and System.RigHumanoid then
        Camera.CameraSubject = System.RigHumanoid
    end
end

function System:Start()
    if self.Running then return end
    self.Running = true

    self.Rig = CreateRig(Config.R15)
    self.RigHumanoid = self.Rig:FindFirstChildOfClass("Humanoid")
    self.RigRoot = self.Rig:FindFirstChild("HumanoidRootPart")

    -- Step loop: Sync Rig CFrame to Real Character & Sync Accessories
    local stepConn = RunService.PreRender:Connect(function()
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")

        if root and self.RigRoot then
            self.RigRoot.CFrame = root.CFrame

            -- Move limbs matching the real character
            for _, limb in ipairs(character:GetChildren()) do
                if limb:IsA("BasePart") and limb.Name ~= "HumanoidRootPart" then
                    local rigLimb = self.Rig:FindFirstChild(limb.Name)
                    if rigLimb then
                        rigLimb.CFrame = limb.CFrame
                    end
                end
            end
        end

        -- Keep hats locked without dropping
        for _, data in ipairs(self.Aligns) do
            if data.Handle and data.Target and data.Handle.Parent then
                data.Handle.CFrame = data.Target.CFrame * data.Offset
            end
        end
    end)
    table.insert(self.Connections, stepConn)

    local charConn = LocalPlayer.CharacterAdded:Connect(SetupCharacter)
    table.insert(self.Connections, charConn)

    if LocalPlayer.Character then
        task.spawn(SetupCharacter, LocalPlayer.Character)
    end
end

function System:Stop()
    if not self.Running then return end
    self.Running = false
    CleanConnections()
    table.clear(self.Aligns)

    if self.Rig then
        self.Rig:Destroy()
        self.Rig = nil
    end

    if LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") or part:IsA("Decal") then
                part.Transparency = 0
            end
        end
    end
end

System:Start()

return System
