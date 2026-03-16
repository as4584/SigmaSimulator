-- ClickHandler.client.lua  (OBSOLETE — V1/V2/V3 only)
-- All click input and combo logic is now handled in UIManager.client.lua.
-- This file intentionally does nothing to avoid conflicting with V4.
do return end

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

local ClickEvent       = Remotes:WaitForChild("ClickSigma")
local ComboActiveEvent = Remotes:WaitForChild("ComboActive")
local ComboEndedEvent  = Remotes:WaitForChild("ComboEnded")
local DuelClickEvent   = Remotes:WaitForChild("DuelClick")

local gui        = playerGui:WaitForChild("SigmaGui")
local clickButton = gui:WaitForChild("ClickButton")
local comboBar   = gui:WaitForChild("ComboBar")
local comboFill  = comboBar:WaitForChild("ComboFill")
local comboLbl   = comboBar:WaitForChild("ComboLabel")

local COOLDOWN       = 0.08
local COMBO_WINDOW   = 1.0    -- seconds to count clicks within
local COMBO_REQUIRED = 5      -- clicks needed to activate combo
local COMBO_TIMEOUT  = 1.5    -- seconds without clicking to end combo

local canClick    = true
local clickTimes  = {}
local comboOn     = false
local lastClickAt = 0

local NORMAL = UDim2.new(0, 200, 0, 200)
local PRESS  = UDim2.new(0, 182, 0, 182)

local function animateButton()
    clickButton.Size = PRESS
    TweenService:Create(clickButton,
        TweenInfo.new(0.12, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
        { Size = NORMAL }
    ):Play()
end

local function updateComboUI(count)
    local pct = math.min(count / COMBO_REQUIRED, 1)
    TweenService:Create(comboFill, TweenInfo.new(0.1), {
        Size = UDim2.new(pct, 0, 1, 0)
    }):Play()
    if comboOn then
        comboLbl.Text = "🔥  COMBO ACTIVE  x1.5"
        comboFill.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
    else
        comboLbl.Text = count .. " / " .. COMBO_REQUIRED .. " for COMBO"
        comboFill.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    end
end

local function doClick()
    if not canClick then return end
    canClick = false

    local now = tick()
    lastClickAt = now
    table.insert(clickTimes, now)

    -- Remove clicks outside the combo window
    local cutoff = now - COMBO_WINDOW
    local i = 1
    while i <= #clickTimes do
        if clickTimes[i] < cutoff then table.remove(clickTimes, i)
        else i += 1 end
    end

    local count = #clickTimes
    if count >= COMBO_REQUIRED and not comboOn then
        comboOn = true
        ComboActiveEvent:FireServer()
    end

    updateComboUI(count)
    ClickEvent:FireServer()
    DuelClickEvent:FireServer()
    animateButton()

    task.wait(COOLDOWN)
    canClick = true
end

-- End combo after inactivity
task.spawn(function()
    while true do
        task.wait(0.25)
        if comboOn and (tick() - lastClickAt) >= COMBO_TIMEOUT then
            comboOn    = false
            clickTimes = {}
            ComboEndedEvent:FireServer()
            updateComboUI(0)
        end
    end
end)

clickButton.MouseButton1Click:Connect(doClick)

UserInputService.InputBegan:Connect(function(inp, gp)
    if gp then return end
    if inp.KeyCode == Enum.KeyCode.Space then doClick() end
end)
