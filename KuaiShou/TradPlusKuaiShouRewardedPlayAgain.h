#import <Foundation/Foundation.h>
#import <KSAdSDK/KSAdSDK.h>
#import "TradPlusKuaiShouRewardedAdapter.h"

NS_ASSUME_NONNULL_BEGIN

@interface TradPlusKuaiShouRewardedPlayAgain : NSObject<KSRewardedVideoAdDelegate>

@property (nonatomic,weak)TradPlusKuaiShouRewardedAdapter *rewardedAdapter;
@end

NS_ASSUME_NONNULL_END
