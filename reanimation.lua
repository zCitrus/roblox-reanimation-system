-- Modernized Reanimation Core
-- Compatible with updated Luau engine / Server-authoritative character loading

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Config = _G.Config or {
    RigTransparency = 1,
    R15 = false,
    BreakJointsDelay = 0.1,
    SetCameraSubject = true,
    DisableCharacterCollisions = true,
    SimulationRadius = 2147483647
}

local System = {
    Running = false,
    Rig = nil,
    RigHumanoid = nil,
    RigRoot = nil,
    Aligns = {},
    Connections = {}
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
        if desc:IsA("BasePart") or desc:IsA("Decal") then
            desc.Transparency = Config.RigTransparency or 1
            if desc:IsA("BasePart") then
                desc.CanCollide = false
            end
        end
    end

    return rig
end

local function AlignPart(part0, part1, offset)
    if not part0 or not part1 then return end
    table.insert(System.Aligns, {
        Part0 = part0,
        Part1 = part1,
        Offset = offset or CFrame.identity
    })
end

local function OnCharacterAdded(character)
    table.clear(System.Aligns)

    local humanoid = character:WaitForChild("Humanoid", 5)
    local rootPart = character:WaitForChild("HumanoidRootPart", 5)

    if not humanoid or not rootPart or not System.Rig then return end

    -- Position rig to the new character spawn
    System.RigRoot.CFrame = rootPart.CFrame

    if Config.SetCameraSubject and System.RigHumanoid then
        Camera.CameraSubject = System.RigHumanoid
    end

    -- Process accessories alignment
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Accessory") then
            local handle = child:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                local targetAttachment = child:FindFirstChildWhichIsA("Attachment", true)
                local rigAttachment = targetAttachment and System.Rig:FindFirstChild(targetAttachment.Name, true)
                
                if rigAttachment and rigAttachment.Parent:IsA("BasePart") then
                    AlignPart(handle, rigAttachment.Parent, targetAttachment.CFrame:Inverse() * rigAttachment.CFrame)
                else
                    AlignPart(handle, System.RigRoot, CFrame.identity)
                end
            end
        end
    end

    -- Break client joints after delay to allow network physics ownership
    task.delay(Config.BreakJointsDelay or 0.1, function()
        if character and character:IsDescendantOf(Workspace) then
            humanoid:ChangeState(Enum.HumanoidStateType.Dead)
            character:BreakJoints()
        end
    end)
end

function System:Start()
    if self.Running then return end
    self.Running = true

    -- Create target control rig
    self.Rig = CreateRig(Config.R15)
    self.RigHumanoid = self.Rig:FindFirstChildOfClass("Humanoid")
    self.RigRoot = self.Rig:FindFirstChild("HumanoidRootPart")

    -- Physics step loop for alignment & velocity preservation
    local stepConn = RunService.PostSimulation:Connect(function()
        local antiSleep = Vector3.new(0, math.sin(os.clock() * 15) * 0.001, 0)

        for _, align in ipairs(self.Aligns) do
            local p0, p1 = align.Part0, align.Part1
            if p0 and p1 and p0:IsDescendantOf(Workspace) and p1:IsDescendantOf(Workspace) then
                p0.AssemblyAngularVelocity = Vector3.zero
                p0.AssemblyLinearVelocity = Vector3.new(0, 27, 0)
                p0.CFrame = (p1.CFrame * align.Offset) + antiSleep
            end
        end

        -- Mirror movement to dummy rig
        local currentCharacter = LocalPlayer.Character
        local currentHumanoid = currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")
        if currentHumanoid and self.RigHumanoid then
            self.RigHumanoid:Move(currentHumanoid.MoveDirection)
            self.RigHumanoid.Jump = currentHumanoid.Jump
        end
    end)
    table.insert(self.Connections, stepConn)

    -- Auto-hook on respawn
    local charConn = LocalPlayer.CharacterAdded:Connect(OnCharacterAdded)
    table.insert(self.Connections, charConn)

    if LocalPlayer.Character then
        task.spawn(OnCharacterAdded, LocalPlayer.Character)
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
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            Camera.CameraSubject = hum
        end
    end
end

-- Initialize
System:Start()

return System
