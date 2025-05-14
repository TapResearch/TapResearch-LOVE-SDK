//
//  TapResearchBridge.h
//  
//
//  Created by Jeroen Verbeek on 5/5/25.
//

#import <Foundation/Foundation.h>
#import <TapResearchSDK/TapResearchSDK.h>

@interface TapResearchLoveBridge : NSObject

+ (NSString*)bridgeVersion;
+ (instancetype)sharedInstance;

- (void)initializeWithAPIToken:(NSString *)apiToken userId:(NSString *)userId;
- (void)initializeWithAPIToken:(NSString *)apiToken userId:(NSString *)userId userAttributes:(NSDictionary*)attributes clearAttributes:(BOOL)clear;

- (BOOL)isReady;
- (BOOL)canShowContentForPlacement:(NSString *)placement;

- (void)setUserIdentifier:(NSString*)userId;
- (void)sendUserAttributes:(NSDictionary*)attributes clearAttributes:(BOOL)clear;
- (void)setRewardCallback:(BOOL)enabled;
- (void)setQuickQuestionCallback:(BOOL)enabled;

- (void)showContentForPlacement:(NSString *)placement;
- (void)showContentForPlacement:(NSString *)placement customParameters:(NSDictionary*)parameters;

@end
