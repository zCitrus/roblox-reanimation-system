-- Modernized Reanimation + Hitbox Desync (Sword Godmode)
-- Compatible with PC & Mobile | Server-Safe Character Management

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Config = _G.Config or {
    Godmode = true,
    GodmodeOffset = Vector3.new(0, 100, 0),
    RigTransparency = 0,
    HideRealCharacter = true,
    R15 = false,
    SetCameraSubject = true,
}

local System = {
    Running = false,
    Rig = nil,
    RigHumanoid = nil,
    RigRoot = nil,
    Connections = {},
    Aligns = {},
    GroundPosition = Vector3.zero
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

    -- Disable collision on real character parts
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            if Config.HideRealCharacter and part.Name ~= "HumanoidRootPart" then
                part.Transparency = 1
            end
        elseif part:IsA("Decal") and Config.HideRealCharacter then
            part.Transparency = 1
        end
    end

    -- Map real character accessories to the visual rig
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

    -- Main physics & desync step loop
    local stepConn = RunService.PreRender:Connect(function()
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")

        if root and self.RigRoot and humanoid then
            if Config.Godmode then
                -- Teleport real character into the air (immune to swords)
                root.AssemblyLinearVelocity = Vector3.zero
                root.CFrame = CFrame.new(System.GroundPosition + Config.GodmodeOffset)

                -- Keep the visual Rig on the ground
                self.RigRoot.CFrame = CFrame.new(System.GroundPosition)

                -- Sync ground position from movement inputs
                local moveDir = humanoid.MoveDirection
                System.GroundPosition = System.GroundPosition + (moveDir * (humanoid.WalkSpeed * (1/60)))
            else
                self.RigRoot.CFrame = root.CFrame
            end

            -- Mirror movement to visual rig
            self.RigHumanoid:Move(humanoid.MoveDirection)
            self.RigHumanoid.Jump = humanoid.Jump

            -- Mirror limbs
            for _, limb in ipairs(character:GetChildren()) do
                if limb:IsA("BasePart") and limb.Name ~= "HumanoidRootPart" then
                    local rigLimb = self.Rig:FindFirstChild(limb.Name)
                    if rigLimb then
                        rigLimb.CFrame = limb.CFrame
                    end
                end
            end
        end

        -- Keep hats locked onto the visual rig
        local antiSleep = Vector3.new(0, math.sin(os.clock() * 15) * 0.001, 0)
        for _, data in ipairs(self.Aligns) do
            if data.Handle and data.Target and data.Handle.Parent then
                data.Handle.AssemblyLinearVelocity = Vector3.new(0, 27, 0)
                data.Handle.CFrame = (data.Target.CFrame * data.Offset) + antiSleep
            end
        end
    end)
    table.insert(self.Connections, stepConn)

    local charConn = LocalPlayer.CharacterAdded:Connect(SetupCharacter)
    table.insert(self.Connections, charConn)

    if LocalPlayer.Character then
        local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            System.GroundPosition = root.Position
        end
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
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            Camera.CameraSubject = hum
        end
    end
end

System:Start()

return System
