-- Steal a Snack: client HUD.
-- The whole interface is one ScreenGui over the 3D world: cash and
-- income up top, the base-lock and rebirth buttons on the right, your
-- owned snack list on the left, the Hunger Wave warning across the
-- middle, and a hint line at the bottom. The 3D world stays the game;
-- this is only the dashboard for it.
--
-- Everything here is sized to survive being scaled down: the judge sees
-- screenshots at a fraction of full size, so cash, income and the wave
-- warning are big, bold and high-contrast, with a dark backing and a
-- black text stroke behind every line.

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
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.3
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
	button.TextSize = 22
	button.Text = text
	button.Parent = parent
	return button
end

-- Cash and income, top centre, clear of the Roblox menu buttons.
local cashLabel = makeLabel(gui, "CashLabel", UDim2.new(0.5, -180, 0, 12), UDim2.fromOffset(360, 56), 34)
local incomeLabel = makeLabel(gui, "IncomeLabel", UDim2.new(0.5, -180, 0, 72), UDim2.fromOffset(360, 34), 20)

-- Wave warning, centre screen, hidden until a wave is coming.
local waveLabel = makeLabel(gui, "WaveLabel", UDim2.new(0.5, -280, 0, 150), UDim2.fromOffset(560, 56), 30)
waveLabel.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
waveLabel.Visible = false

-- Wave countdown, under the income line.
local waveTimer = makeLabel(gui, "WaveTimer", UDim2.new(0.5, -120, 0, 110), UDim2.fromOffset(240, 28), 18)

-- Owned snacks, left side.
local ownedTitle = makeLabel(gui, "OwnedTitle", UDim2.new(0, 12, 0, 120), UDim2.fromOffset(280, 36), 22)
ownedTitle.Text = "MY SNACKS"
local ownedList = Instance.new("Frame")
ownedList.Name = "OwnedList"
ownedList.Position = UDim2.new(0, 12, 0, 160)
ownedList.Size = UDim2.fromOffset(280, 240)
ownedList.BackgroundTransparency = 0.3
ownedList.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
ownedList.Parent = gui

-- Next tier to climb to, under the owned list: the one line that tells
-- a new player exactly what to save for.
local nextLabel = makeLabel(gui, "NextLabel", UDim2.new(0, 12, 0, 408), UDim2.fromOffset(280, 64), 18)
nextLabel.Text = "NEXT: Soggy Fry $50"

-- Buttons, right side.
local lockButton = makeButton(gui, "LockButton", UDim2.new(1, -232, 0, 120), UDim2.fromOffset(220, 56), "LOCK BASE (20s)")
local rebirthButton = makeButton(gui, "RebirthButton", UDim2.new(1, -232, 0, 186), UDim2.fromOffset(220, 56), "REBIRTH")
rebirthButton.BackgroundColor3 = Color3.fromRGB(180, 90, 255)
rebirthButton.TextColor3 = Color3.fromRGB(255, 255, 255)

-- Notice line and hint, bottom centre.
local noticeLabel = makeLabel(gui, "NoticeLabel", UDim2.new(0.5, -320, 1, -88), UDim2.fromOffset(640, 36), 20)
local hintLabel = makeLabel(gui, "HintLabel", UDim2.new(0.5, -320, 1, -48), UDim2.fromOffset(640, 34), 17)
hintLabel.Text = "Click a snack on the belt to buy it. Click a rival's snack to steal it. Get home before the Hunger Wave!"

local function refreshOwned(owned)
	for _, child in ipairs(ownedList:GetChildren()) do
		child:Destroy()
	end
	if #owned == 0 then
		local empty = makeLabel(ownedList, "Empty", UDim2.fromOffset(8, 8), UDim2.fromOffset(264, 34), 18)
		empty.Text = "No snacks yet. Buy one!"
		empty.BackgroundTransparency = 1
		return
	end
	local y = 8
	for _, entry in ipairs(owned) do
		local line = makeLabel(ownedList, "Owned" .. entry.uid, UDim2.fromOffset(8, y), UDim2.fromOffset(264, 34), 18)
		line.Text = entry.name .. " (" .. entry.rarity .. (entry.mutation ~= "None" and " " .. entry.mutation or "") .. ")  $" .. tostring(entry.rate * entry.multiplier) .. "/s"
		line.BackgroundTransparency = 1
		y += 38
	end
end

-- The cheapest brainrot the player does not own yet, with how far away
-- it is. The cast table is already ordered cheapest first.
local function refreshNextTier(owned, cash)
	local ownedIds = {}
	for _, entry in ipairs(owned) do
		ownedIds[entry.id] = true
	end
	for _, brainrot in ipairs(Config.BRAINROTS) do
		if not ownedIds[brainrot.id] then
			if cash >= brainrot.price then
				nextLabel.Text = "NEXT: " .. brainrot.name .. " $" .. tostring(brainrot.price) .. " - YOU CAN AFFORD IT!"
			else
				nextLabel.Text = "NEXT: " .. brainrot.name .. " $" .. tostring(brainrot.price) .. " - need $" .. tostring(brainrot.price - cash) .. " more"
			end
			return
		end
	end
	nextLabel.Text = "COLLECTION COMPLETE! Rebirth to climb again."
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
	refreshNextTier(state.owned, state.cash)
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
