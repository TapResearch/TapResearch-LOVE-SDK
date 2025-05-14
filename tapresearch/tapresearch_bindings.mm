//
//  tapresearch_bindings.mm
//  
//
//  Created by Jeroen Verbeek on 5/5/25.
//

extern "C" {
#include "lua.h"
#include "lauxlib.h"
}

#import "TapResearchLoveBridge.h"
static NSDictionary *lua_to_dict(lua_State* L, int index);

//MARK: - TapResearch Initialization functions

static int l_tap_initialize(lua_State* L) {
	const char* token = luaL_checkstring(L, 1);
	const char* userId = luaL_checkstring(L, 2);
	[[TapResearchLoveBridge sharedInstance] initializeWithAPIToken:[NSString stringWithUTF8String:token]
														userId:[NSString stringWithUTF8String:userId]];
	return 0;
}

static int l_tap_initialize_with_user_attributes(lua_State* L) {
	const char* token = luaL_checkstring(L, 1);
	const char* userId = luaL_checkstring(L, 2);

	NSDictionary *dict = nil;
	if (!lua_istable(L, 3)) {
		luaL_error(L, "Expected a table");
	}
	else {
		dict = lua_to_dict(L, 3);
	}
	BOOL clear = BOOL(lua_toboolean(L, 4));

	[[TapResearchLoveBridge sharedInstance] initializeWithAPIToken:[NSString stringWithUTF8String:token]
														userId:[NSString stringWithUTF8String:userId]
												userAttributes:dict
											   clearAttributes:clear];
	return 0;
}

static int l_tap_is_ready(lua_State* L) {
	BOOL ready = [[TapResearchLoveBridge sharedInstance] isReady];
	lua_pushboolean(L, ready);
	return 1;
}

//MARK: - TapResearch Setter functions

static int l_tap_set_user_identifier(lua_State* L) {
	const char* userId = luaL_checkstring(L, 1);
	[[TapResearchLoveBridge sharedInstance] setUserIdentifier:[NSString stringWithUTF8String:userId]];
	return 0;
}

static int l_tap_send_user_attributes(lua_State* L) {
	NSDictionary *dict = nil;
	if (!lua_istable(L, 1)) {
		luaL_error(L, "Expected a table");
	}
	else {
		dict = lua_to_dict(L, 1);
	}
	BOOL clear = BOOL(lua_toboolean(L, 2));

	[[TapResearchLoveBridge sharedInstance] sendUserAttributes:dict clearAttributes:clear];
	return 0;
}

static int l_tap_set_reward_callback(lua_State* L) {
	NSLog(@"l_tap_set_reward_callback called!");
	BOOL enabled = BOOL(lua_toboolean(L, 1));
	[[TapResearchLoveBridge sharedInstance] setRewardCallback:enabled];
	return 0;
}

static int l_tap_set_quick_question_callback(lua_State* L) {
	BOOL enabled = BOOL(luaL_checkint(L, 1));
	[[TapResearchLoveBridge sharedInstance] setQuickQuestionCallback:enabled];
	return 0;
}

//MARK: - TapResearch Content functions

static int l_tap_can_show(lua_State* L) {
	const char* placement = luaL_checkstring(L, 1);
	BOOL available = [[TapResearchLoveBridge sharedInstance] canShowContentForPlacement:[NSString stringWithUTF8String:placement]];
	lua_pushboolean(L, available);
	return 1;
}

static int l_tap_show_content(lua_State* L) {
	const char* placement = luaL_checkstring(L, 1);
	[[TapResearchLoveBridge sharedInstance] showContentForPlacement:[NSString stringWithUTF8String:placement]];
	return 0;
}

static int l_tap_show_content_with_custom_parameters(lua_State* L) {
	const char* placement = luaL_checkstring(L, 1);

	NSDictionary *dict = nil;
	if (!lua_istable(L, 2)) {
		luaL_error(L, "Expected a table");
	}
	else {
		dict = lua_to_dict(L, 2);
	}

	[[TapResearchLoveBridge sharedInstance] showContentForPlacement:[NSString stringWithUTF8String:placement] customParameters:dict];
	return 0;
}

//MARK: Lua to object data parsing

static id lua_to_obj(lua_State* L, int index);

static NSArray *lua_to_array(lua_State* L, int index) {
	NSMutableArray *array = [NSMutableArray array];
	int length = (int)lua_objlen(L, index);
	for (int i = 1; i <= length; i++) {
		lua_rawgeti(L, index, i);
		id value = lua_to_obj(L, -1);
		if (value) [array addObject:value];
		lua_pop(L, 1);
	}
	return array;
}

static NSDictionary *lua_to_dict(lua_State* L, int index) {
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	lua_pushnil(L);
	while (lua_next(L, index) != 0) {
		const char *key = lua_tostring(L, -2);
		if (key) {
			id value = lua_to_obj(L, -1);
			if (value) [dict setObject:value forKey:[NSString stringWithUTF8String:key]];
		}
		lua_pop(L, 1);
	}
	return dict;
}

static id lua_to_obj(lua_State* L, int index) {
	switch (lua_type(L, index)) {
		case LUA_TSTRING:
			return [NSString stringWithUTF8String:lua_tostring(L, index)];
		case LUA_TNUMBER:
			return [NSNumber numberWithDouble:lua_tonumber(L, index)];
		case LUA_TBOOLEAN:
			return [NSNumber numberWithBool:lua_toboolean(L, index)];
		case LUA_TTABLE: {
			// Check if it is array-like or dictionary-like
			lua_pushnil(L);
			BOOL isArray = YES;
			while (lua_next(L, index) != 0) {
				if (lua_type(L, -2) != LUA_TNUMBER || lua_tonumber(L, -2) != floor(lua_tonumber(L, -2))) isArray = NO;
				lua_pop(L, 1);
				if (!isArray) break;
			}
			if (isArray) {
				return lua_to_array(L, index);
			}
			else {
				return lua_to_dict(L, index);
			}
		}
		default:
			return nil;
	}
}

//MARK: - Register functions

lua_State* g_luaState = nullptr;

void setLuaState(lua_State* L) {
	g_luaState = L;
}

extern "C" int luaopen_tapresearch_native(lua_State* L) {
	setLuaState(L); // cache for future callbacks
	luaL_Reg funcs[] = {
		{"initialize", l_tap_initialize},
		{"initializeWithUserAttributes", l_tap_initialize_with_user_attributes},
		{"isReady", l_tap_is_ready},
		{"setUserIdentifier", l_tap_set_user_identifier},
		{"sendUserAttributes", l_tap_send_user_attributes},
		{"setRewardCallback", l_tap_set_reward_callback},
		{"setQuickQuestionCallback", l_tap_set_quick_question_callback},
		{"canShow", l_tap_can_show},
		{"showContent", l_tap_show_content},
		{"showContentWithCustomParameters", l_tap_show_content_with_custom_parameters},
		{NULL, NULL}
	};
	luaL_newlib(L, funcs);
	return 1;
}

