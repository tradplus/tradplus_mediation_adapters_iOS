#import <Foundation/Foundation.h>
#import <TradPlusAds/TPSDKLoaderDelegate.h>

NS_ASSUME_NONNULL_BEGIN

@interface TradPlusBigoSDKLoader : NSObject

+ (TradPlusBigoSDKLoader *)sharedInstance;

- (void)initWithAppID:(NSString *)appID
             delegate:(nullable id <TPSDKLoaderDelegate>)delegate;

@property (nonatomic,assign)BOOL didInit;
@property (nonatomic,assign)NSInteger initSource;

@end

NS_ASSUME_NONNULL_END
