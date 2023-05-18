//
//  TradPlusVungleNativeAdapter.m
//  fluteSDKSample
//
//  Created by xuejun on 2021/8/3.
//  Copyright © 2021 TradPlus. All rights reserved.
//

#import "TradPlusVungleNativeAdapter.h"
#import <TradPlusAds/TradPlusAdWaterfallItem.h>
#import <TradPlusAds/MsCommon.h>
#import <TradPlusAds/MSLogging.h>
#import "TradPlusVungleSDKLoader.h"
#import "TPVungleRouter.h"
#import "TPVungleAdapterBaseInfo.h"

@interface TradPlusVungleNativeAdapter()<TPVungleRouterDelegate,TPSDKLoaderDelegate>

@property (nonatomic,copy)NSString *placementId;
@property (nonatomic,strong)UIView *mrecView;
@property (nonatomic,copy)NSString *bidToken;
@property (nonatomic, assign)BOOL willLoad;
@end

@implementation TradPlusVungleNativeAdapter

#pragma mark - Extra
- (BOOL)extraActWithEvent:(NSString *)event info:(NSDictionary *)config
{
    if([event isEqualToString:@"StartInit"])
    {
        [self initSDKWithInfo:config];
    }
    else if([event isEqualToString:@"AdapterVersion"])
    {
        [self adapterVersionCallback];
    }
    else if([event isEqualToString:@"PlatformSDKVersion"])
    {
        [self platformSDKVersionCallback];
    }
    else
    {
        return NO;
    }
    return YES;
}

//初始化SDK
- (void)initSDKWithInfo:(NSDictionary *)config
{
    NSString *appId = config[@"appId"];
    if(appId == nil)
    {
        MSLogTrace(@"Vungle init Config Error %@",config);
        return;
    }
    if([TradPlusVungleSDKLoader sharedInstance].initSource == -1)
    {
        [TradPlusVungleSDKLoader sharedInstance].initSource = 1;
    }
    [[TradPlusVungleSDKLoader sharedInstance] initWithAppID:appId delegate:nil];
}

//版本号
- (void)adapterVersionCallback
{
    NSDictionary *dic = @{@"version":TP_VungleAdapter_Version};
    [self ADLoadExtraCallbackWithEvent:@"AdapterVersion" info:dic];
}

//三方SDK版本号
- (void)platformSDKVersionCallback
{
    NSString *version = VungleSDKVersion;
    if(version == nil)
    {
        version = @"";
    }
    NSDictionary *dic = @{
        @"version":version,
        @"adaptedVersion":TP_VungleAdapter_PlatformSDK_Version
    };
    [self ADLoadExtraCallbackWithEvent:@"PlatformSDKVersion" info:dic];
}

- (void)loadAdWithWaterfallItem:(TradPlusAdWaterfallItem *)item
{
    NSString *appId = item.config[@"appId"];
    self.placementId = item.config[@"placementId"];
    if(appId == nil || self.placementId == nil)
    {
        [self AdConfigError];
        return;;
    }
    if(self.waterfallItem.adsourceplacement != nil)
    {
        self.bidToken = self.waterfallItem.adsourceplacement.adm;
    }
    self.waterfallItem.nativeType = TPNativeADTYPE_Template;
    [[TradPlusVungleSDKLoader sharedInstance] initWithAppID:appId delegate:self];
}

- (void)loadAd
{
    [[TPVungleRouter sharedRouter] requestMRECAdWithPlacementId:self.placementId delegate:self bidToken:self.bidToken];
}

#pragma mark - TPSDKLoaderDelegate

- (void)tpInitFinish
{
    if([[TPVungleRouter sharedRouter] hasPlacementIdAd:self.placementId] && self.bidToken != nil)
    {
        self.willLoad = YES;
        [[TPVungleRouter sharedRouter] addPlacementId:self.placementId delegate:self];
        [[TPVungleRouter sharedRouter] finishedDisplayingAd:self.placementId];
    }
    else
    {
        [self loadAd];
    }
}

- (void)tpInitFailWithError:(NSError *)error
{
    [self AdLoadFailWithError:error];
}

- (BOOL)isReady
{
    return (self.mrecView != nil);
}

- (id)getCustomObject
{
    return self.mrecView;
}


#pragma mark - TPVungleRouterDelegate

- (void)vungleAdDidLoad
{
    if(self.mrecView == nil)
    {
        self.mrecView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 250)];
        TradPlusAdRes *res = [[TradPlusAdRes alloc] init];
        res.adView = self.mrecView;
        self.waterfallItem.adRes = res;
        [self AdLoadFinsh];
    }
}

- (void)templateRender:(UIView *)subView
{
    NSError *error = nil;
    if(![[TPVungleRouter sharedRouter] addAdViewToView:self.mrecView placementID:self.placementId bidToken:self.bidToken error:&error])
    {
        MSLogTrace(@"vungle show %@", error);
        [self AdShowFailWithError:error];
    }
    else
    {
        if(self.waterfallItem.templateContentMode == TPTemplateContentModeScaleToFill)
        {
            self.mrecView.frame = subView.bounds;
        }
        else//TPTemplateContentModeCenter
        {
            CGPoint center = CGPointZero;
            center.x = CGRectGetWidth(subView.bounds)/2;
            center.y = CGRectGetHeight(subView.bounds)/2;
            self.mrecView.center = center;
        }
    }
}

- (void)vungleAdDidFailToLoad:(NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.isAdReady)
    {
        return;
    }
    [[TPVungleRouter sharedRouter] clearDelegateForPlacementId:self.placementId];
    [self AdLoadFailWithError:error];
}

- (void)vungleAdDidFailToPlay:(NSError *)error
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShowFailWithError:error];
}

- (void)vungleAdWasTapped
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdClick];
}

- (void)vungleAdDidShow
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    [self AdShow];
}

- (void)vungleAdWillAppear
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
}

- (void)vungleAdWillDisappear
{
    MSLogTrace(@"%s", __PRETTY_FUNCTION__);
    if(self.willLoad)
    {
        self.willLoad = NO;
        [self loadAd];
    }
}
@end
