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

#import <Foundation/Foundation.h>
#import "lua.h"
#import "lauxlib.h"

#import "TapResearchLoveBridge.h"

static NSDictionary *lua_to_dict(lua_State* L, int index);
static void pushNSDictionary(lua_State *L, NSDictionary *dict);

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
	BOOL enabled = BOOL(lua_toboolean(L, 1));
	[[TapResearchLoveBridge sharedInstance] setRewardCallback:enabled];
	return 0;
}

static int l_tap_set_quick_question_callback(lua_State* L) {
	BOOL enabled = BOOL(lua_toboolean(L, 1));
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

static int l_tap_has_surveys(lua_State* L) {
	const char* placement = luaL_checkstring(L, 1);
	BOOL available = [[TapResearchLoveBridge sharedInstance] hasSurveysForPlacement:[NSString stringWithUTF8String:placement]];
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

static int l_tap_show_survey(lua_State* L) {
	const char* survey = luaL_checkstring(L, 1);
	const char* placement = luaL_checkstring(L, 2);
	[[TapResearchLoveBridge sharedInstance] showSurveyForPlacement:[NSString stringWithUTF8String:survey] placement:[NSString stringWithUTF8String:placement]];
	return 0;
}

static int l_tap_show_survey_with_custom_parameters(lua_State* L) {
	const char* survey = luaL_checkstring(L, 1);
	const char* placement = luaL_checkstring(L, 2);

	NSDictionary *dict = nil;
	if (!lua_istable(L, 3)) {
		luaL_error(L, "Expected a table");
	}
	else {
		dict = lua_to_dict(L, 3);
	}

	[[TapResearchLoveBridge sharedInstance] showSurveyForPlacement:[NSString stringWithUTF8String:survey] placement:[NSString stringWithUTF8String:placement] customParameters:dict];
	return 0;
}

static int l_tap_get_surveys(lua_State* L) {
	const char* placementTag = luaL_checkstring(L, 1);

	NSArray *surveys = [[TapResearchLoveBridge sharedInstance] getSurveysForPlacement:[NSString stringWithUTF8String:placementTag]];

	lua_newtable(L);

	for (NSUInteger i = 0; i < surveys.count; i++) {

		TRSurvey *survey = surveys[i];
		NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
		if (survey.surveyIdentifier) { dict[@"surveyIdentifier"] = survey.surveyIdentifier; }
		if (survey.currencyName)     { dict[@"currencyName"    ] = survey.currencyName;     }
		if (survey.saleEndDate)      { dict[@"saleEndDate"     ] = survey.saleEndDate;      }
		if (survey.category)         { dict[@"category"        ] = survey.category;         }
		dict[@"preSaleRewardAmount"] = @(survey.preSaleRewardAmount);
		dict[@"lengthInMinutes"    ] = @(survey.lengthInMinutes);
		dict[@"saleMultiplier"     ] = @(survey.saleMultiplier);
		dict[@"rewardAmount"       ] = @(survey.rewardAmount);
		dict[@"isHotTile"          ] = [NSNumber numberWithBool:survey.isHotTile];
		dict[@"isSale"             ] =  [NSNumber numberWithBool:survey.isSale];
		pushNSDictionary(L, dict);
		lua_rawseti(L, -2, (int)i + 1);
	}

	return 1;
}

//MARK: - Boost

static int l_tap_grant_boost(lua_State* L) {
	const char* boostTag = luaL_checkstring(L, 1);
	[[TapResearchLoveBridge sharedInstance] grantBoostWithTag:[NSString stringWithUTF8String:boostTag]];
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

static void pushNSDictionary(lua_State *L, NSDictionary *dict) {
	lua_newtable(L); // creates {}

	for (id key in dict) {
		id value = dict[key];

		// key
		lua_pushstring(L, [[key description] UTF8String]);

		// value
		if ([value isKindOfClass:[NSString class]]) {
			lua_pushstring(L, [value UTF8String]);
		}
		else if ([value isKindOfClass:[NSNumber class]]) {
			const char *type = [value objCType];

			if (strcmp(type, @encode(BOOL)) == 0) {
				lua_pushboolean(L, [value boolValue]);
			} else {
				lua_pushnumber(L, [value doubleValue]);
			}
		}
		else if ([value isKindOfClass:[NSDictionary class]]) {
			pushNSDictionary(L, value);
		}
		else if ([value isKindOfClass:[NSArray class]]) {
			NSArray *array = value;
			lua_newtable(L);

			for (NSUInteger i = 0; i < array.count; i++) {
				id item = array[i];

				if ([item isKindOfClass:[NSDictionary class]]) {
					pushNSDictionary(L, item);
				}
				else if ([item isKindOfClass:[NSString class]]) {
					lua_pushstring(L, [item UTF8String]);
				}
				else if ([item isKindOfClass:[NSNumber class]]) {
					if (strcmp([item objCType], @encode(BOOL)) == 0) {
						lua_pushboolean(L, [item boolValue]);
					}
					else {
						lua_pushnumber(L, [item doubleValue]);
					}
				}
				else {
					lua_pushnil(L);
				}

				lua_rawseti(L, -2, (int)i + 1); // Lua arrays are 1-based
			}
		}
		else if (value == [NSNull null] || value == nil) {
			lua_pushnil(L);
		}
		else {
			lua_pushstring(L, [[value description] UTF8String]);
		}

		lua_settable(L, -3);
	}
}

//MARK: - Placement details

static NSDictionary *dictionaryFromBonusTier(TRBonusTier *tier) {
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];

	dict[@"tierNumber"] = @(tier.tierNumber);
	dict[@"completesNeeded"] = @(tier.completesNeeded);
	dict[@"rewardAmount"] = @(tier.rewardAmount);

	if (tier.status) {
		dict[@"status"] = tier.status;
	}

	return dict;
}

static NSDictionary *dictionaryFromBonusBarProgress(TRBonusBarProgress *progress) {
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];

	dict[@"isActive"        ] = @(progress.isActive);
	dict[@"currentCompletes"] = @(progress.currentCompletes);

	if (progress.bonusWindowEndAt) { dict[@"bonusWindowEndAt"] = progress.bonusWindowEndAt; }

	if (progress.bonusTiers) {
		NSMutableArray *tiers = [NSMutableArray array];
		for (TRBonusTier *tier in progress.bonusTiers) {
			[tiers addObject:dictionaryFromBonusTier(tier)];
		}
		dict[@"bonusTiers"] = tiers;
	}

	if (progress.error) {
		dict[@"error"] = @{
			@"domain": progress.error.domain ?: @"",
			@"code": @(progress.error.code),
			@"localizedDescription": progress.error.localizedDescription ?: @""
		};
	}

	return dict;
}

static NSDictionary *dictionaryFromPlacementDetails(TRPlacementDetails *details) {
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];

	dict[@"name"] = details.name;
	dict[@"contentType"] = details.contentType;
	dict[@"currencyName"] = details.currencyName;
	dict[@"isSale"] = @(details.isSale);
	dict[@"saleMultiplier"] = @(details.saleMultiplier);

	if (details.saleType)         { dict[@"saleType"        ] = details.saleType; }
	if (details.saleEndDate)      { dict[@"saleEndDate"     ] = details.saleEndDate; }
	if (details.saleDisplayName)  { dict[@"saleDisplayName" ] = details.saleDisplayName; }
	if (details.saleTag)          { dict[@"saleTag"         ] = details.saleTag; }
	if (details.bonusBarProgress) { dict[@"bonusBarProgress"] = dictionaryFromBonusBarProgress(details.bonusBarProgress); }

	return dict;
}

static int l_tap_get_placement_details(lua_State *L) {
	const char *placementTag = luaL_checkstring(L, 1);

	TRPlacementDetails *details = [[TapResearchLoveBridge sharedInstance] getPlacementDetails:[NSString stringWithUTF8String:placementTag]];
	if (!details) {
		lua_pushnil(L);
		return 1;
	}

	NSDictionary *dict = dictionaryFromPlacementDetails(details);
	pushNSDictionary(L, dict);
	return 1;
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
		{"getPlacementDetails", l_tap_get_placement_details},
		{"grantBoost", l_tap_grant_boost},
		{"hasSurveys", l_tap_has_surveys},
		{"getSurveys", l_tap_get_surveys},
		{"showSurvey", l_tap_show_survey},
		{"showSurveytWithCustomParameters", l_tap_show_survey_with_custom_parameters},
		{NULL, NULL}
	};
	luaL_newlib(L, funcs);
	return 1;
}
