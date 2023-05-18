#import <Foundation/Foundation.h>
#import <TradPlusAds/TPSDKLoaderDelegate.h>

NS_ASSUME_NONNULL_BEGIN

@interface TradPlusInMobiSDKLoader : NSObject

+ (TradPlusInMobiSDKLoader *)sharedInstance;
- (void)initWithAccountID:(NSString *)accountID
                 delegate:(nullable id <TPSDKLoaderDelegate>)delegate;
- (NSDictionary *)getExtras;
@property (nonatomic,assign)BOOL didInit;
@property (nonatomic,assign)NSInteger initSource;
@end
NS_ASSUME_NONNULL_END
