//
//  SanQRCodeViewController.m
//  SanQRCode
//
//  Created by ydd on 2019/1/22.
//  Copyright © 2019 ydd. All rights reserved.
//

#import "SanQRCodeViewController.h"
#import "CaptureManager.h"

@interface SanQRCodeViewController ()

@property (nonatomic, strong) CaptureManager *captureManager;

@end

@implementation SanQRCodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
  self.view.backgroundColor = [UIColor whiteColor];
  [self captureManager];
}

- (CaptureManager *)captureManager
{
  if (!_captureManager) {
    _captureManager = [[CaptureManager alloc] initWithViewController:self];
    __weak typeof(self) weakself = self;
    _captureManager.qrCodeValue = ^(NSString * _Nonnull qrStr) {
      [weakself handleQRCodeStr:qrStr];
    };
  }
  return _captureManager;
}

- (void)handleQRCodeStr:(NSString *)qrStr
{
  [[[UIAlertView alloc]initWithTitle:qrStr message:nil delegate:nil cancelButtonTitle:@"关闭" otherButtonTitles:nil, nil] show];
  [self.navigationController popViewControllerAnimated:YES];
}

- (void)dealloc
{
  NSLog(@"dealloc %@", NSStringFromClass(self.class));
}


/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
