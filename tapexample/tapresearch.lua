-- tapresearch.lua
local tapresearch = {}

-- Load the native bindings
local native = require("tapresearch_native")

function tapresearch.initialize(apiToken, userId)
    assert(type(apiToken) == "string", "apiToken must be a string")
    assert(type(userId) == "string", "userId must be a string")
    native.initialize(apiToken, userId)
end

function initializeWithUserAttributes(apiToken, userId, attributes, clear)
    assert(type(apiToken) == "string", "apiToken must be a string")
    assert(type(userId) == "string", "userId must be a string")
	assert(type(attributes) == "table", "attributes must be a table")
	assert(type(clear) == "boolean", "clear must be a boolean")
    native.initializeWithUserAttributes(apiToken, userId, attributes, clear)
end

function tapresearch.isReady()
    return native.isReady()
end

function tapresearch.setUserIdentifier(userId)
    assert(type(userId) == "string", "placement must be a string")
    return native.setUserIdentifier(userId)
end

function tapresearch.sendUserAttributes(attributes, clear)
	assert(type(attributes) == "table", "attributes must be a table")
	assert(type(clear) == "boolean", "clear must be a boolean")
	return native.sendUserAttributes(attributes, clear)
end

function tapresearch.canShow(placement)
    assert(type(placement) == "string", "placement must be a string")
    return native.canShow(placement)
end

function tapresearch.showContent(placement)
    assert(type(placement) == "string", "placement must be a string")
    native.showContent(placement)
end

function showContentWithCustomParameters(placement, parameters)
    assert(type(placement) == "string", "placement must be a string")
 	assert(type(parameters) == "table", "attributes must be a table")
    native.showContentWithCustomParameters(placement)
end

-- The SDK needs to know when a reward or Quick Question callback is set, to make sure this happens
-- we use a setter to set the relevant callback.
function tapresearch.setOnRewardReceived(func)
    tapresearch.onRewardReceived = func
    if func == nil then
        native.setRewardCallback(false)
    else 
        native.setRewardCallback(true)
    end
end

function tapresearch.setOnQuickQuestionResponse(func)
    tapresearch.onQuickQuestionResponse = func
	if func == nil then
		native.setRewardCallback(false)
	else
		native.setRewardCallback(true)
	end
end

-- The delegate callback functions below should be overridden in your own code.
-- For example when you need to have a local onContentShown callback you can use something similar to this:
--
-- tap.onContentShown = function(placement)
--     -- Handle content shown, un-pause game for example... 
-- end
--
-- Note: The native bridge still gets called by the SDK for relevant callbacks so make sure that you have 
--       your own callback handlers set!!!

-- Called from native when rewards are received
function tapresearch.onRewardReceived(rewards)
    print("[LuaToNativeBridge] Got rewards! You MUST override this function with your own!")
end

-- Called from native when rewards are received
function tapresearch.onQuickQuestionResponse(payload)
	print("[LuaToNativeBridge] Got QQ response! You MUST override this function with your own!")
end

-- Called from native when content is shown
--function tapresearch.onContentShown(placement)
--    print("[LuaToNativeBridge] Content shown for: " .. placement)
--end

-- Called from native when content is dismissed
--function tapresearch.onContentDismissed(placement)
--    print("[LuaToNativeBridge] Content dismissed for: " .. placement)
--end

-- Called from native when the SDK is ready
---function tapresearch.onSdkReady() 
--    print("[LuaToNativeBridge] Sdk Ready!")
---end

-- Called from native when there is an error
---function tapresearch.onSdkError(error, code)
---    print("[LuaToNativeBridge] Sdk Eror: " .. code .. ": " .. error)
---end

return tapresearch
