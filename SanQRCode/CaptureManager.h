//
//  CaptureManager.h
//  SanQRCode
//
//  Created by ydd on 2019/1/22.
//  Copyright © 2019 ydd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CaptureManager : NSObject

@property (nonatomic, copy) void(^qrCodeValue)(NSString *qrStr);

- (instancetype)initWithViewController:(UIViewController *)viewController;

- (void)captureStartRuning;

- (void)captureStopRuning;
@end

NS_ASSUME_NONNULL_END
