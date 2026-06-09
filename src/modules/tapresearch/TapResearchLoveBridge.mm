//
//  TapResearchBridge.m
//  
//
//  Created by Jeroen Verbeek on 5/5/25.
//
extern "C" {
#include "lua.h"
#include "lauxlib.h"
}

#define SET_STRING(key, val) lua_pushstring(L, key); lua_pushstring(L, [val UTF8String]); lua_settable(L, -3)

#import "TapResearchLoveBridge.h"
#import <UserNotifications/UserNotifications.h>
#import <TapResearchSDK/TapResearchSDK-Swift.h>

extern "C" {
	extern lua_State* g_luaState;
}

@interface TapResearchLoveBridge () <
TapResearchSDKDelegate,
TapResearchContentDelegate,
TapResearchQuickQuestionDelegate,
TapResearchRewardDelegate,
TapResearchSurveysDelegate,
TapResearchGrantBoostResponseDelegate
>

@end

@implementation TapResearchLoveBridge

/// ---------------------------------------------------------------------------------------------
+ (NSString*)bridgeVersion {
	return @"3.8.0--beta01";
}

/// ---------------------------------------------------------------------------------------------
+ (instancetype)sharedInstance {
	static TapResearchLoveBridge *shared = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		shared = [[self alloc] init];
	});
	return shared;
}

/// ---------------------------------------------------------------------------------------------
- (void)initializeWithAPIToken:(NSString *)apiToken userId:(NSString *)userId {
	TR_DEBUG_LOG(@"");

	[TapResearch initializeWithAPIToken:apiToken
						 userIdentifier:userId
							sdkDelegate:self
						 rewardDelegate:nil
				  quickQuestionDelegate:nil
							 completion:^(NSError * _Nullable error) {
		if (error) {
			[self onTapResearchDidError:error];
			NSLog(@"[TapResearchLoveBridge-Native] Initialization error: %@", error.localizedDescription);
		}
	}];
}

/// ---------------------------------------------------------------------------------------------
- (void)initializeWithAPIToken:(NSString *)apiToken userId:(NSString *)userId userAttributes:(NSDictionary*)attributes clearAttributes:(BOOL)clear {
	TR_DEBUG_LOG(@"");

	[TapResearch initializeWithAPIToken:apiToken
						 userIdentifier:userId
							sdkDelegate:self
						 rewardDelegate:nil
				  quickQuestionDelegate:nil
							 completion:^(NSError * _Nullable error) {
		if (error) {
			[self onTapResearchDidError:error];
			NSLog(@"[TapResearchLoveBridge-Native] Initialization error: %@", error.localizedDescription);
		}
	}];
}

/// ---------------------------------------------------------------------------------------------
- (BOOL)isReady {
	TR_DEBUG_LOG(@"");

	return [TapResearch isReady];
}

//MARK: - Setters

/// ---------------------------------------------------------------------------------------------
- (void)setUserIdentifier:(NSString*)userId {
	TR_DEBUG_LOG(@"");

	[TapResearch setUserIdentifier:userId completion:^(NSError * _Nullable error) {
		if (error) {
			[self onTapResearchDidError:error];
			NSLog(@"[TapResearchLoveBridge-Native] setUserIdentifier error: %@", error.localizedDescription);
		}
	}];
}

/// ---------------------------------------------------------------------------------------------
- (void)sendUserAttributes:(NSDictionary*)attributes clearAttributes:(BOOL)clear {
	TR_DEBUG_LOG(@"");
	NSString *string = [NSString stringWithFormat:@"%@ %d", attributes, (int)clear];
	TR_DEBUG_LOG(string);

	[TapResearch sendUserAttributesWithAttributes:attributes clearPreviousAttributes:clear];
}

/// ---------------------------------------------------------------------------------------------
- (void)setRewardCallback:(BOOL)enabled {
	TR_DEBUG_LOG(@"");

	if (enabled) {
		[TapResearch setRewardDelegate:self];
	}
	else {
		[TapResearch setRewardDelegate:nil];
	}
}

/// ---------------------------------------------------------------------------------------------
- (void)setQuickQuestionCallback:(BOOL)enabled {
	TR_DEBUG_LOG(@"");

	if (enabled) {
		[TapResearch setQuickQuestionDelegate:self];
	}
	else {
		[TapResearch setQuickQuestionDelegate:nil];
	}
}

//MARK: - Content

/// ---------------------------------------------------------------------------------------------
- (BOOL)canShowContentForPlacement:(NSString *)placementTag {
	TR_DEBUG_LOG(@"");

	return [TapResearch canShowContentForPlacement:placementTag error:^(NSError * _Nullable error) {
		if (error) {
			[self onTapResearchDidError:error];
			NSLog(@"[TapResearchLoveBridge-Native] canShowPlacement check error: %@", error.localizedDescription);
		}
	}];
}

/// ---------------------------------------------------------------------------------------------
- (BOOL)hasSurveysForPlacement:(NSString *)placementTag {
	TR_DEBUG_LOG(@"");

	return [TapResearch hasSurveysFor:placementTag errorHandler:^(NSError * _Nullable error) {
		if (error) {
			[self onTapResearchDidError:error];
			NSLog(@"[TapResearchLoveBridge-Native] hasSurveysFor check error: %@", error.localizedDescription);
		}
	}];
}

/// ---------------------------------------------------------------------------------------------
- (void)showContentForPlacement:(NSString *)placementTag {
	TR_DEBUG_LOG(@"");

	if (![self canShowContentForPlacement:placementTag]) {
		NSLog(@"[TapResearchLoveBridge-Native] Cannot show content for placement: %@", placementTag);
		return;
	}

	[TapResearch showContentForPlacement:placementTag delegate:self completion:^(NSError * _Nullable error) {
		if (error) {
			[self onTapResearchDidError:error];
			NSLog(@"[TapResearchLoveBridge-Native] showContentForPlacement (not iPhone) show error: %@", error.localizedDescription);
		}
	}];
}

/// ---------------------------------------------------------------------------------------------
- (void)showContentForPlacement:(NSString *)placementTag customParameters:(NSDictionary*)parameters {
	TR_DEBUG_LOG(@"");

	if (![self canShowContentForPlacement:placementTag]) {
		NSLog(@"[TapResearchLoveBridge-Native] Cannot show content for placement: %@", placementTag);
		return;
	}

	[TapResearch showContentForPlacement:placementTag delegate:self completion:^(NSError * _Nullable error) {
		if (error) {
			[self onTapResearchDidError:error];
			NSLog(@"[TapResearchLoveBridge-Native] showContentForPlacement (not iPhone) show error: %@", error.localizedDescription);
		}
	}];
}

/// ---------------------------------------------------------------------------------------------
- (void)showSurveyForPlacement:(NSString *)survey placement:(NSString *)placementTag {
	TR_DEBUG_LOG(@"");

	if (![self canShowContentForPlacement:placementTag]) {
		NSLog(@"[TapResearchLoveBridge-Native] Cannot show content for placement: %@", placementTag);
		return;
	}

	[TapResearch showSurveyWithSurveyId:survey placementTag:placementTag delegate:self errorHandler:^(NSError * _Nullable error) {
		if (error) {
			[self onTapResearchDidError:error];
			NSLog(@"[TapResearchLoveBridge-Native] showSurveyWithSurveyId show error: %@", error.localizedDescription);
		}
	}];
}

/// ---------------------------------------------------------------------------------------------
- (void)showSurveyForPlacement:(NSString *)survey placement:(NSString *)placementTag customParameters:(NSDictionary*)parameters {
	TR_DEBUG_LOG(@"");

	if (![self canShowContentForPlacement:placementTag]) {
		NSLog(@"[TapResearchLoveBridge-Native] Cannot show content for placement: %@", placementTag);
		return;
	}
	[TapResearch showSurveyWithSurveyId:survey placementTag:placementTag delegate:self customParameters:parameters errorHandler:^(NSError * _Nullable error) {
		if (error) {
			[self onTapResearchDidError:error];
			NSLog(@"[TapResearchLoveBridge-Native] showSurveyWithSurveyId show error: %@", error.localizedDescription);
		}
	}];
}

/// ---------------------------------------------------------------------------------------------
- (NSArray *)getSurveysForPlacement:(NSString *)placementTag {
	TR_DEBUG_LOG(@"");

	return [TapResearch getSurveysFor:placementTag errorHandler:^(NSError * _Nullable error) {
		if (error) {
			[self onTapResearchDidError:error];
			NSLog(@"[TapResearchLoveBridge-Native] getSurveysForPlacement error: %@", error.localizedDescription);
		}
	}];
}

//MARK: - Placement details

/// ---------------------------------------------------------------------------------------------
- (TRPlacementDetails *)getPlacementDetails:(NSString *)placementTag {
	TR_DEBUG_LOG(@"");

	return [TapResearch getPlacementDetails:placementTag errorHandler:^(NSError * _Nullable error) {
		if (error) {
			[self onTapResearchDidError:error];
			NSLog(@"[TapResearchLoveBridge-Native] getPlacementDetails error: %@", error.localizedDescription);
		}
	}];
}

//MARK: - Boost

/// ---------------------------------------------------------------------------------------------
- (void)grantBoostWithTag:(NSString *)boostTag {
	TR_DEBUG_LOG(@"");

	[TapResearch grantBoost:boostTag delegate:self errorHandler:^(NSError * _Nullable error) {
		if (error) {
			[self onTapResearchDidError:error];
			NSLog(@"[TapResearchLoveBridge-Native] showSurveyWithSurveyId show error: %@", error.localizedDescription);
		}
	}];
}

//MARK: - SDK delegates

/// ---------------------------------------------------------------------------------------------
- (void)onTapResearchSdkReady {
	TR_DEBUG_LOG(@"SDK is ready");

	dispatch_async(dispatch_get_main_queue(), ^{
		if (g_luaState) {
			lua_getglobal(g_luaState, "require");
			lua_pushstring(g_luaState, "tapresearch");
			lua_call(g_luaState, 1, 1); // returns the tapresearch module table

			lua_getfield(g_luaState, -1, "onSdkReady");

			if (lua_isfunction(g_luaState, -1)) {
				lua_call(g_luaState, 0, 0); // call onContentShown(placement)
			}
			lua_pop(g_luaState, 1); // pop tapresearch module
		}
	});
}

/// ---------------------------------------------------------------------------------------------
- (void)onTapResearchDidError:(NSError * _Nonnull)error {
	NSString *string = [NSString stringWithFormat:@"SDK Did Error : %@", error.localizedDescription];
	TR_DEBUG_LOG(string);

	dispatch_async(dispatch_get_main_queue(), ^{
		if (g_luaState) {
			lua_getglobal(g_luaState, "require");
			lua_pushstring(g_luaState, "tapresearch");
			lua_call(g_luaState, 1, 1); // returns the tapresearch module table

			lua_getfield(g_luaState, -1, "onSdkError");

			if (lua_isfunction(g_luaState, -1)) {
				lua_pushstring(g_luaState, [error.localizedDescription UTF8String]);
				lua_pushinteger(g_luaState, error.code);
				lua_call(g_luaState, 2, 0); // call onSdkError(error, code)
			}
			lua_pop(g_luaState, 1); // pop tapresearch module
		}
	});
}

/// ---------------------------------------------------------------------------------------------
- (void)onTapResearchQuickQuestionResponse:(TRQQDataPayload *)payload {
	NSString *string = [NSString stringWithFormat:@"Quick Question response %@", payload];
	TR_DEBUG_LOG(string);

	if (!g_luaState) return;
	lua_State* L = g_luaState;

	dispatch_async(dispatch_get_main_queue(), ^{
		lua_getglobal(L, "require");
		lua_pushstring(L, "tapresearch");
		lua_call(L, 1, 1); // tapresearch module

		lua_getfield(L, -1, "onQuickQuestionResponse");
		if (!lua_isfunction(L, -1)) {
			lua_pop(L, 2); return;
		}

		lua_newtable(L); // payload

		SET_STRING("survey_identifier", payload.survey_identifier);
		SET_STRING("app_name", payload.app_name);
		SET_STRING("api_token", payload.api_token);
		SET_STRING("sdk_version", payload.sdk_version);
		SET_STRING("platform", payload.platform);
		SET_STRING("placement_tag", payload.placement_tag);
		SET_STRING("user_identifier", payload.user_identifier);
		SET_STRING("user_locale", payload.user_locale);
		SET_STRING("seen_at", payload.seen_at);

		// questions
		lua_pushstring(L, "questions");
		lua_newtable(L);
		int qi = 1;
		for (TRQQDataPayloadQuestion *q in payload.questions) {
			lua_newtable(L);
			SET_STRING("question_identifier", q.question_identifier);
			SET_STRING("question_text", q.question_text);
			SET_STRING("question_type", q.question_type);
			lua_pushstring(L, "rating_scale_size"); lua_pushinteger(L, q.rating_scale_size); lua_settable(L, -3);

			if (q.user_answer) {
				lua_pushstring(L, "user_answer");
				lua_newtable(L);
				SET_STRING("value", q.user_answer.value);
				lua_pushstring(L, "identifiers");
				lua_newtable(L);
				int ai = 1;
				for (NSString *idstr in q.user_answer.identifiers) {
					lua_pushstring(L, [idstr UTF8String]);
					lua_rawseti(L, -2, ai++);
				}
				lua_settable(L, -3); // user_answer.identifiers
				lua_settable(L, -3); // question.user_answer
			}
			lua_rawseti(L, -2, qi++);
		}
		lua_settable(L, -3); // payload.questions

		// target_audience
		if (payload.target_audience) {
			lua_pushstring(L, "target_audience");
			lua_newtable(L);
			int ti = 1;
			for (TRQQDataPayloadTargetFilter *f in payload.target_audience) {
				lua_newtable(L);
				SET_STRING("filter_attribute_name", f.filter_attribute_name);
				SET_STRING("filter_operator", f.filter_operator);
				SET_STRING("filter_value", f.filter_value);
				SET_STRING("user_value", f.user_value);
				lua_rawseti(L, -2, ti++);
			}
			lua_settable(L, -3);
		}

		// complete
		if (payload.complete) {
			lua_pushstring(L, "complete");
			lua_newtable(L);
			SET_STRING("complete_identifier", payload.complete.complete_identifier);
			SET_STRING("completed_at", payload.complete.completed_at);
			lua_settable(L, -3);
		}

		lua_call(L, 1, 0); // call onQuickQuestionResponse(payload)
		lua_pop(L, 1); // pop tapresearch module
	});
}

/// ---------------------------------------------------------------------------------------------
- (void)onTapResearchDidReceiveRewards:(NSArray<TRReward *> *)rewards {
	NSString *string = [NSString stringWithFormat:@"Received rewards %@", rewards];
	TR_DEBUG_LOG(string);

	if (g_luaState) {
		lua_State* L = g_luaState;

		// Get module
		lua_getglobal(L, "require");
		lua_pushstring(L, "tapresearch");
		lua_call(L, 1, 1); // returns the tapresearch module table

		lua_getfield(L, -1, "onRewardReceived");
		if (lua_isfunction(L, -1)) {
			lua_newtable(L); // rewards array table

			int i = 1;
			for (TRReward *reward in rewards) {
				lua_newtable(L); // reward table to hold dictionary

				lua_pushstring(L, "transactionIdentifier");
				lua_pushstring(L, [reward.transactionIdentifier UTF8String]);
				lua_settable(L, -3);

				lua_pushstring(L, "placementTag");
				lua_pushstring(L, [reward.placementTag UTF8String]);
				lua_settable(L, -3);

				lua_pushstring(L, "placementIdentifier");
				lua_pushstring(L, [reward.placementIdentifier UTF8String]);
				lua_settable(L, -3);

				lua_pushstring(L, "payoutEvent");
				lua_pushstring(L, [reward.placementIdentifier UTF8String]);
				lua_settable(L, -3);

				lua_pushstring(L, "currencyName");
				lua_pushstring(L, [reward.currencyName UTF8String]);
				lua_settable(L, -3);

				lua_pushstring(L, "rewardAmount");
				lua_pushnumber(L, reward.rewardAmount);
				lua_settable(L, -3);

				// array[i] = struct
				lua_rawseti(L, -2, i++); // add reward struct/table to array/table of rewards
			}

			lua_call(L, 1, 0); // onRewardReceived(array)
		} else {
			NSLog(@"[TapResearchLoveBridge-Native] No onRewardReceived function set.");
			lua_pop(L, 1); // pop non-function
		}
		lua_pop(L, 1); // pop tapresearch module
	}
}

/// ---------------------------------------------------------------------------------------------
- (void)onTapResearchContentShownForPlacement:(NSString *)placementTag {
	NSString *string = [NSString stringWithFormat:@"Content shown for placement %@", placementTag];
	TR_DEBUG_LOG(string);

	dispatch_async(dispatch_get_main_queue(), ^{
		if (g_luaState) {
			lua_getglobal(g_luaState, "require");
			lua_pushstring(g_luaState, "tapresearch");
			lua_call(g_luaState, 1, 1); // returns the tapresearch module table

			lua_getfield(g_luaState, -1, "onContentShown");

			if (lua_isfunction(g_luaState, -1)) {
				lua_pushstring(g_luaState, [placementTag UTF8String]);
				lua_call(g_luaState, 1, 0); // call onContentShown(placement)
			}
			lua_pop(g_luaState, 1); // pop tapresearch module
		}
	});
}

/// ---------------------------------------------------------------------------------------------
- (void)onTapResearchContentDismissedForPlacement:(NSString *)placementTag {
	NSString *string = [NSString stringWithFormat:@"Content dismissed for placement %@", placementTag];
	TR_DEBUG_LOG(string);

	dispatch_async(dispatch_get_main_queue(), ^{
		if (g_luaState) {
			lua_getglobal(g_luaState, "require");
			lua_pushstring(g_luaState, "tapresearch");
			lua_call(g_luaState, 1, 1); // returns the tapresearch module table

			lua_getfield(g_luaState, -1, "onContentDismissed");

			if (lua_isfunction(g_luaState, -1)) {
				lua_pushstring(g_luaState, [placementTag UTF8String]);
				lua_call(g_luaState, 1, 0); // call onContentDismissed(placement)
			}
			lua_pop(g_luaState, 1); // pop tapresearch module
		}
	});
}

/// ---------------------------------------------------------------------------------------------
- (void)onTapResearchGrantBoostResponse:(TRGrantBoostResponse *)boostResponse {
	NSString *string = [NSString stringWithFormat:@"Received boostResponse %@", boostResponse];
	TR_DEBUG_LOG(string);

	if (g_luaState) {
		lua_State* L = g_luaState;

		// Get module
		lua_getglobal(L, "require");
		lua_pushstring(L, "tapresearch");
		lua_call(L, 1, 1); // returns the tapresearch module table

		lua_getfield(L, -1, "onBoostResponse");
		if (lua_isfunction(L, -1)) {

			lua_newtable(L); // boostResponse table to hold dictionary
			SET_STRING("boostTag", boostResponse.boostTag);

			lua_pushstring(L, "success");
			lua_pushboolean(L, boostResponse.success);

			if (boostResponse.error) {
				lua_pushstring(L, "error");
				lua_newtable(L);
				lua_pushstring(g_luaState, [boostResponse.error.localizedDescription UTF8String]);
				lua_pushinteger(g_luaState, boostResponse.error.code);
				lua_settable(L, -3);
			}

			lua_call(L, 1, 0); // onRewardReceived(array)
		} else {
			NSLog(@"[TapResearchLoveBridge-Native] No onRewardReceived function set.");
			lua_pop(L, 1); // pop non-function
		}
		lua_pop(L, 1); // pop tapresearch module
	}
}

/// ---------------------------------------------------------------------------------------------
- (void)onTapResearchSurveysRefreshedForPlacement:(NSString * _Nonnull)placementTag {
	NSString *string = [NSString stringWithFormat:@"Surveys refreshed for placement %@", placementTag];
	TR_DEBUG_LOG(string);

	dispatch_async(dispatch_get_main_queue(), ^{
		if (g_luaState) {
			lua_getglobal(g_luaState, "require");
			lua_pushstring(g_luaState, "tapresearch");
			lua_call(g_luaState, 1, 1); // returns the tapresearch module table

			lua_getfield(g_luaState, -1, "onSurveysRefreshed");

			if (lua_isfunction(g_luaState, -1)) {
				lua_pushstring(g_luaState, [placementTag UTF8String]);
				lua_call(g_luaState, 1, 0); // call onSurveysRefreshed(placement)
			}
			lua_pop(g_luaState, 1); // pop tapresearch module
		}
	});
}

@end

#undef SET_STRING
