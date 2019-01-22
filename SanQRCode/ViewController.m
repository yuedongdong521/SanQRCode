//
//  ViewController.m
//  SanQRCode
//
//  Created by ydd on 2019/1/22.
//  Copyright © 2019 ydd. All rights reserved.
//

#import "ViewController.h"
#import "SanQRCodeViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view, typically from a nib.
  self.view.backgroundColor = [UIColor whiteColor];
  UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
  button.frame = CGRectMake(20, 100, 100, 50);
  [button setTitle:@"scanQR" forState:UIControlStateNormal];
  [button addTarget:self action:@selector(pushSanQRCodeViewController) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:button];
}

- (void)pushSanQRCodeViewController
{
  [self.navigationController pushViewController:[[SanQRCodeViewController alloc] init] animated:YES];
}


@end
