tap = require("tapresearch")

local buttons = {}
local buttonWidth = 200
local buttonHeight = 50
local spacing = 10
local labels = { "Survey Wall", "Banner", "Interstitial", "Quick Question", "Send Attributes" }
local screenWidth, screenHeight
local font
local labelText = "Select an option"

function showTapResearchContent(placementTag)
	if tap.isReady() then
		tap.onContentShown = function(placement)
			print("[TapResearch-LuaExample] Content shown for: " .. placement)
		end
		tap.onContentDismissed = function(placement) 
			print("[TapResearch-LuaExample] Content dismissed for: " .. placement)
		end
		print("[TapResearch-LuaExample] Showing: " .. placementTag)
		tap.showContent(placementTag)
	else
		print("[TapResearch-Lua] TapResearchSDK not ready for: " .. placementTag)
	end
end

-- Button press handler functions
function button1()
	updateLabel("Survey Wall selected")
	showTapResearchContent("earn-center")
end

function button2()
	updateLabel("Banner selected")
	showTapResearchContent("home-screen")
end

function button3()
	updateLabel("Interstitial selected")
	showTapResearchContent("mike-interstitial")
end

function button4()
	updateLabel("Quick Question selected")
	showTapResearchContent("quick-answer-mcgraw")
end

function button5()
	updateLabel("Send Attributes selected")
	tap.sendUserAttributes({
		user_type = "vip",
		seed_number = 500
	}, true)
end

function updateLabel(newText)
	labelText = newText
end

-- Position buttons centered vertically and horizontally
local function layoutButtons()
	buttons = {}
	local totalHeight = #labels * buttonHeight + (#labels - 1) * spacing
	local startX = (screenWidth - buttonWidth) / 2
	local startY = (screenHeight - totalHeight) / 2

	for i, label in ipairs(labels) do
		local y = startY + (i - 1) * (buttonHeight + spacing)
		local functionName = "button" .. i
		table.insert(buttons, {
			x = startX,
			y = y,
			width = buttonWidth,
			height = buttonHeight,
			label = label,
			pressed = false,
			pressTime = 0,
			onClick = function()
				if _G[functionName] then
					_G[functionName]()
				else
					updateLabel("No handler for " .. label)
				end
			end
		})
	end
end

function tapRewardHandler(rewards)
	print("[TapResearch-LuaExample] Got rewards!")

	for _, reward in ipairs(rewards) do
		print("  Reward transactionIdentifier: " .. reward.transactionIdentifier)
		print("   Reward placementTag: " .. reward.placementTag) -- comment
		print("   Reward placementIdentifier: " .. reward.placementIdentifier)
		print("   Reward payoutEvent: " .. reward.payoutEvent)
		print("   Reward currencyName: " .. reward.currencyName)
		print("   Reward rewardAmount: " .. tostring(reward.rewardAmount))
	end

	updateLabel("Rewards received!")
end

function tapQQResponseHandler(payload)
	print("[TapResearch-LuaExample] Got QQ payload!")

	print("  Survey ID: " .. payload.survey_identifier)
	print("  App Name: " .. payload.app_name)
	print("  SDK Version: " .. payload.sdk_version)
	print("  Platform: " .. payload.platform)
	print("  Placement: " .. payload.placement_tag)
	print("  User Locale: " .. payload.user_locale)
	print("  Seen At: " .. payload.seen_at)
	
	if payload.questions then
		print("  Questions:")
		for i, q in ipairs(payload.questions) do
			print(string.format("    [%d] %s (%s)", i, q.question_text, q.question_type))
			print("      ID: " .. q.question_identifier)
			print("      Rating Scale Size: " .. tostring(q.rating_scale_size))
			if q.user_answer then
				print("      Answer: " .. q.user_answer.value)
				if q.user_answer.identifiers then
					for _, id in ipairs(q.user_answer.identifiers) do
						print("        Identifier: " .. id)
					end
				end
			end
		end
	end
	
	if payload.target_audience then
		print("  Target Audience Filters:")
		for i, f in ipairs(payload.target_audience) do
			print(string.format("    %s %s %s (user: %s)", f.filter_attribute_name, f.filter_operator, f.filter_value, f.user_value))
		end
	end
	
	if payload.complete then
		print("  Survey marked complete:")
		print("    ID: " .. payload.complete.complete_identifier)
		print("    At: " .. payload.complete.completed_at)
	end

	updateLabel("Got QQ payload!")
end

function onTapSdkReady() 
	print("[TapResearch-LuaExample] TapResearch Sdk Ready!")
end

function onTapSdkError(error, code)
	print("[TapResearch-LuaExample] TapResearch Sdk Error: " .. code .. ": " .. error)
end

function love.load()
	screenWidth, screenHeight = love.graphics.getDimensions()
	font = love.graphics.newFont(24)
	love.graphics.setFont(font)

	print("[TapResearch-LuaExample] Setting REQUIRED sdk ready and sdk erorr callbacks")
	tap.onSdkReady = onTapSdkReady
	tap.onTapSdkError = onTapSdkError
	
	print("[TapResearch-LuaExample] Initializing TapResearchSDK")
	tap.initialize("100e9133abc21471c8cd373587e07515", "tr-sdk-test-user-my-new-public-demo-user")
	
	print("[TapResearch-LuaExample] Setting reward and Quick Question handlers")
	tap.setOnRewardReceived(tapRewardHandler)
	tap.setOnQuickQuestionResponse(tapQQResponseHandler)

	layoutButtons()
end

function love.resize(w, h)
	screenWidth, screenHeight = w, h
	layoutButtons()
end

function love.update(dt)
	for _, btn in ipairs(buttons) do
		if btn.pressed then
			btn.pressTime = btn.pressTime - dt
			if btn.pressTime <= 0 then
				btn.pressed = false
			end
		end
	end
end

function love.draw()
	for _, btn in ipairs(buttons) do
		if btn.pressed then
			love.graphics.setColor(0.1, 0.4, 0.8)
		else
			love.graphics.setColor(0.2, 0.6, 1)
		end
		love.graphics.rectangle("fill", btn.x, btn.y, btn.width, btn.height, 8, 8)

		love.graphics.setColor(1, 1, 1)
		love.graphics.printf(btn.label, btn.x, btn.y + btn.height / 2 - font:getHeight() / 2, btn.width, "center")
	end

	-- Draw the label text below buttons
	love.graphics.setColor(1, 1, 1)
	love.graphics.printf(
		labelText,
		0,
		screenHeight - 100,
		screenWidth,
		"center"
	)
end

local function handlePress(x, y)
	for _, btn in ipairs(buttons) do
		if x >= btn.x and x <= btn.x + btn.width and
		   y >= btn.y and y <= btn.y + btn.height then
			btn.pressed = true
			btn.pressTime = 0.15
			btn.onClick()
		end
	end
end

function love.mousepressed(x, y, button)
	if button == 1 then
		handlePress(x, y)
	end
end

function love.touchpressed(id, x, y, dx, dy, pressure)
	local px = x * screenWidth
	local py = y * screenHeight
	handlePress(px, py)
end
