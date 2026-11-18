-- Steal a Snack: client HUD.
-- The whole interface is one ScreenGui over the 3D world: cash and
-- income up top, the base-lock and rebirth buttons on the right, your
-- owned snack list on the left, the Hunger Wave warning across the
-- middle, and a hint line at the bottom. The 3D world stays the game;
-- this is only the dashboard for it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameSync = Remotes:WaitForChild("GameSync")
local LockBase = Remotes:WaitForChild("LockBase")
local RequestRebirth = Remotes:WaitForChild("RequestRebirth")
local WaveAlert = Remotes:WaitForChild("WaveAlert")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "SnackHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local function makeLabel(parent, name, position, size, textSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 0.3
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.FredokaOne
	label.TextSize = textSize
	label.Text = ""
	label.Parent = parent
	return label
end

local function makeButton(parent, name, position, size, text)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = Color3.fromRGB(255, 170, 40)
	button.TextColor3 = Color3.fromRGB(30, 30, 30)
	button.Font = Enum.Font.FredokaOne
	button.TextSize = 20
	button.Text = text
	button.Parent = parent
	return button
end

-- Cash and income, top centre, clear of the Roblox menu buttons.
local cashLabel = makeLabel(gui, "CashLabel", UDim2.new(0.5, -160, 0, 12), UDim2.fromOffset(320, 44), 26)
local incomeLabel = makeLabel(gui, "IncomeLabel", UDim2.new(0.5, -160, 0, 60), UDim2.fromOffset(320, 30), 18)

-- Wave warning, centre screen, hidden until a wave is coming.
local waveLabel = makeLabel(gui, "WaveLabel", UDim2.new(0.5, -250, 0, 110), UDim2.fromOffset(500, 44), 24)
waveLabel.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
waveLabel.Visible = false

-- Wave countdown, under the income line.
local waveTimer = makeLabel(gui, "WaveTimer", UDim2.new(0.5, -100, 0, 94), UDim2.fromOffset(200, 24), 16)

-- Owned snacks, left side.
local ownedTitle = makeLabel(gui, "OwnedTitle", UDim2.new(0, 12, 0, 120), UDim2.fromOffset(240, 30), 18)
ownedTitle.Text = "MY SNACKS"
local ownedList = Instance.new("Frame")
ownedList.Name = "OwnedList"
ownedList.Position = UDim2.new(0, 12, 0, 154)
ownedList.Size = UDim2.fromOffset(240, 220)
ownedList.BackgroundTransparency = 0.3
ownedList.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
ownedList.Parent = gui

-- Buttons, right side.
local lockButton = makeButton(gui, "LockButton", UDim2.new(1, -220, 0, 120), UDim2.fromOffset(200, 48), "LOCK BASE (20s)")
local rebirthButton = makeButton(gui, "RebirthButton", UDim2.new(1, -220, 0, 178), UDim2.fromOffset(200, 48), "REBIRTH")
rebirthButton.BackgroundColor3 = Color3.fromRGB(180, 90, 255)
rebirthButton.TextColor3 = Color3.fromRGB(255, 255, 255)

-- Notice line and hint, bottom centre.
local noticeLabel = makeLabel(gui, "NoticeLabel", UDim2.new(0.5, -300, 1, -84), UDim2.fromOffset(600, 30), 18)
local hintLabel = makeLabel(gui, "HintLabel", UDim2.new(0.5, -300, 1, -48), UDim2.fromOffset(600, 30), 16)
hintLabel.Text = "Click a snack on the belt to buy it. Click a rival's snack to steal it. Get home before the Hunger Wave!"

local function refreshOwned(owned)
	for _, child in ipairs(ownedList:GetChildren()) do
		child:Destroy()
	end
	if #owned == 0 then
		local empty = makeLabel(ownedList, "Empty", UDim2.fromOffset(8, 8), UDim2.fromOffset(224, 30), 16)
		empty.Text = "No snacks yet. Buy one!"
		empty.BackgroundTransparency = 1
		return
	end
	local y = 8
	for _, entry in ipairs(owned) do
		local line = makeLabel(ownedList, "Owned" .. entry.uid, UDim2.fromOffset(8, y), UDim2.fromOffset(224, 28), 15)
		line.Text = entry.name .. " (" .. entry.rarity .. (entry.mutation ~= "None" and " " .. entry.mutation or "") .. ")  $" .. tostring(entry.rate * entry.multiplier) .. "/s"
		line.BackgroundTransparency = 1
		y += 32
	end
end

local waveHideAt = 0

GameSync.OnClientEvent:Connect(function(state)
	cashLabel.Text = "CASH: $" .. tostring(state.cash)
	incomeLabel.Text = "$" .. tostring(state.income) .. "/s  |  Rebirths: " .. tostring(state.rebirths) .. "  |  Income x" .. tostring(state.multiplier)
	if state.lockRemaining > 0 then
		lockButton.Text = "LOCKED: " .. tostring(math.ceil(state.lockRemaining)) .. "s"
	elseif state.lockCooldown > 0 then
		lockButton.Text = "LOCK: " .. tostring(math.ceil(state.lockCooldown)) .. "s cooldown"
	else
		lockButton.Text = "LOCK BASE (20s)"
	end
	rebirthButton.Text = "REBIRTH ($" .. tostring(state.rebirthCost) .. ")"
	if state.waveActive then
		waveLabel.Text = "HUNGER WAVE! STAY ON YOUR BASE!"
		waveLabel.Visible = true
		waveHideAt = os.clock() + 3
	elseif state.nextWaveIn and state.nextWaveIn <= Config.WAVE_WARN_SECONDS then
		waveLabel.Text = "HUNGER WAVE IN " .. tostring(state.nextWaveIn) .. "s! GET HOME!"
		waveLabel.Visible = true
		waveHideAt = os.clock() + 2
	else
		waveTimer.Text = "Next wave: " .. tostring(state.nextWaveIn or 0) .. "s"
	end
	if state.notice and state.notice ~= "" then
		noticeLabel.Text = state.notice
	end
	refreshOwned(state.owned)
end)

WaveAlert.OnClientEvent:Connect(function(message)
	waveLabel.Text = message
	waveLabel.Visible = true
	waveHideAt = os.clock() + 12
end)

lockButton.MouseButton1Click:Connect(function()
	LockBase:FireServer()
end)

rebirthButton.MouseButton1Click:Connect(function()
	RequestRebirth:FireServer()
end)

-- Hide the wave banner a few seconds after the danger passes.
task.spawn(function()
	while true do
		task.wait(0.5)
		if waveLabel.Visible and os.clock() > waveHideAt then
			waveLabel.Visible = false
		end
	end
end)
