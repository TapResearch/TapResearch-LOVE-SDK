//
//  TapResearchBridge.h
//  
//
//  Created by Jeroen Verbeek on 5/5/25.
//

#import <Foundation/Foundation.h>
#import <TapResearchSDK/TapResearchSDK.h>
#import <UserNotifications/UserNotifications.h>
#import <TapResearchSDK/TapResearchSDK-Swift.h>

#define TR_DEBUG_LOG(str) NSLog(@"[TapResearchLoveBridge-Native] [%@] %@", [NSString stringWithUTF8String:__PRETTY_FUNCTION__], str);

@interface TapResearchLoveBridge : NSObject

+ (NSString*)bridgeVersion;
+ (instancetype)sharedInstance;

- (void)initializeWithAPIToken:(NSString *)apiToken userId:(NSString *)userId;
- (void)initializeWithAPIToken:(NSString *)apiToken userId:(NSString *)userId userAttributes:(NSDictionary*)attributes clearAttributes:(BOOL)clear;

- (BOOL)isReady;
- (BOOL)canShowContentForPlacement:(NSString *)placementTag;

- (void)setUserIdentifier:(NSString*)userId;
- (void)sendUserAttributes:(NSDictionary*)attributes clearAttributes:(BOOL)clear;
- (void)setRewardCallback:(BOOL)enabled;
- (void)setQuickQuestionCallback:(BOOL)enabled;

- (void)showContentForPlacement:(NSString *)placementTag;
- (void)showContentForPlacement:(NSString *)placementTag customParameters:(NSDictionary*)parameters;

- (TRPlacementDetails *)getPlacementDetails:(NSString *)placementTag;
- (void)grantBoostWithTag:(NSString*)boostTag;

- (BOOL)hasSurveysForPlacement:(NSString *)placementTag;
- (NSArray *)getSurveysForPlacement:(NSString*)placement;
- (void)showSurveyForPlacement:(NSString *)survey placement:(NSString *)placementTag;
- (void)showSurveyForPlacement:(NSString *)survey placement:(NSString *)placementTag customParameters:(NSDictionary*)parameters;

@end
