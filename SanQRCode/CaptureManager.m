//
//  CaptureManager.m
//  SanQRCode
//
//  Created by ydd on 2019/1/22.
//  Copyright © 2019 ydd. All rights reserved.
//

#import "CaptureManager.h"

#define ScreenHeight  [UIScreen mainScreen].bounds.size.height
#define ScreenWidth   [UIScreen mainScreen].bounds.size.width
#define ScanWidth  240

@interface CaptureManager ()<AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureDevice *capDevice;
@property (nonatomic, strong) AVCaptureDeviceInput *capInput;
@property (nonatomic, strong) AVCaptureSession *capSession;
@property (nonatomic, strong) AVCaptureMetadataOutput *metaOutput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;
@property (nonatomic, strong) dispatch_semaphore_t sqrSemaphore;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *perviewLayer;
@property (nonatomic, weak) UIViewController *curViewController;

@property (nonatomic, strong) UIImageView *qrCodeView;
@property (nonatomic, strong) UIImageView *qrLineView;

@property (nonatomic, assign) int scanZoom;
@property (nonatomic, strong) NSTimer *timer;

@end

@implementation CaptureManager

- (instancetype)initWithViewController:(UIViewController *)viewController
{
  self = [super init];
  if (self) {
    _sqrSemaphore = dispatch_semaphore_create(1);
    _curViewController = viewController;
    self.perviewLayer.frame = viewController.view.bounds;
    [viewController.view.layer addSublayer:self.perviewLayer];
    [viewController.view addSubview:self.qrCodeView];
    [self initCapture];
  }
  return self;
}

- (void)timerAction
{
  _scanZoom++;
  [self setCapDeviceZoom:_scanZoom rate:50];
}

- (void)startTimer
{
  if (!_timer) {
    _timer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(timerAction) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
  }
  _scanZoom = 2;
  [self setCapDeviceZoom:_scanZoom rate:50];
}

- (void)invaliTimer
{
  if (_timer) {
    if ([_timer isValid]) {
      [_timer invalidate];
    }
    _timer = nil;
  }
}

- (void)startAnimate
{
  if (!_qrLineView) {
    return;
  }
  _qrCodeView.hidden = NO;
  __weak typeof(self) weakself = self;
  _qrLineView.frame = CGRectMake(0, 0, ScanWidth, _qrLineView.frame.size.height);
  CGRect animateRect = CGRectMake(0, ScanWidth - _qrLineView.frame.size.height, ScanWidth,
                                  _qrLineView.frame.size.height);
  [UIView animateWithDuration:3.0
                        delay:0.0
                      options:UIViewAnimationOptionRepeat
                   animations:^{
                     weakself.qrLineView.frame = animateRect;
                   }
                   completion:nil];
}


- (void)backScanQrValue:(NSString *)qrStr
{
  if (qrStr.length == 0) {
    return;
  }
  [self captureStopRuning];
  if (_qrCodeValue) {
    _qrCodeValue(qrStr);
  }
}

- (void)captureStartRuning
{
  if (!_capSession.isRunning) {
    [_capSession startRunning];
  }
  [self startTimer];
}

- (void)captureStopRuning
{
  if (_capSession.isRunning) {
    [_capSession stopRunning];
  }
  [self invaliTimer];
}


- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
  if (self.metaOutput != output) {
    return;
  }
  AVMetadataMachineReadableCodeObject* metadataObject = metadataObjects.firstObject;
  if (!metadataObject) {
    return;
  }
  NSString *qrStr = metadataObject.stringValue;
  [self backScanQrValue:qrStr];
}

- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
  if (self.videoOutput != output) {
    return;
  }
  CVPixelBufferRef pixelbuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  [self scanCodePixelbuffer:pixelbuffer];
}

- (void)scanCodePixelbuffer:(CVPixelBufferRef)pixelbuffer {
  //
  static CVPixelBufferRef buff = NULL;
  if (buff) {
    CVPixelBufferRelease(buff);
    buff = NULL;
  }
  buff = CVPixelBufferRetain(pixelbuffer);
  CIImage* ciImage;
  
  if (@available(iOS 9.0, *)) {
    ciImage = [CIImage imageWithCVImageBuffer:buff];
  } else {
    CVPixelBufferLockBaseAddress(buff, 0);
    void* baseAddress = CVPixelBufferGetBaseAddress(buff);
    size_t width = CVPixelBufferGetWidth(buff);
    size_t height = CVPixelBufferGetHeight(buff);
    size_t bufferSize = CVPixelBufferGetDataSize(buff);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buff, 0);
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef provider =
    CGDataProviderCreateWithData(NULL, baseAddress, bufferSize, NULL);
    CGImageRef cgImage =
    CGImageCreate(width, height, 8, 32, bytesPerRow, rgbColorSpace,
                  kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little,
                  provider, NULL, true, kCGRenderingIntentDefault);
    ciImage = [CIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CVPixelBufferUnlockBaseAddress(buff, 0);
  }
  
  if (!ciImage) {
    dispatch_semaphore_signal(_sqrSemaphore);
    return;
  }
  static CIDetector* detector = nil;
  if (detector == nil) {
    CIContext* context = [CIContext
                          contextWithOptions:
                          [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
                                                      forKey:kCIContextUseSoftwareRenderer]];
    
    detector = [CIDetector
                detectorOfType:CIDetectorTypeQRCode
                context:context
                options:@{CIDetectorAccuracy : CIDetectorAccuracyHigh}];
  }
  NSArray* features = [detector featuresInImage:ciImage];
  if (!features) {
    dispatch_semaphore_signal(_sqrSemaphore);
    return;
  }
  CIQRCodeFeature* feature = [features firstObject];
  if (!feature) {
    dispatch_semaphore_signal(_sqrSemaphore);
    return;
  }
  NSString* qrStr = feature.messageString;
  __weak typeof(self) weakself = self;
  dispatch_async(dispatch_get_main_queue(), ^{
    [weakself backScanQrValue:qrStr];
    dispatch_semaphore_signal(weakself.sqrSemaphore);
  });
}

- (void)initCapture
{
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    if ([self.capSession canAddInput:self.capInput]) {
      [self.capSession addInput:self.capInput];
    }
    if ([self.capSession canAddOutput:self.videoOutput]) {
      [self.capSession addOutput:self.videoOutput];
    }
    if ([self.capSession canAddOutput:self.metaOutput]) {
      [self.capSession addOutput:self.metaOutput];
    }
    self.metaOutput.metadataObjectTypes = @[
                                        AVMetadataObjectTypeQRCode, AVMetadataObjectTypeEAN13Code,
                                        AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode128Code
                                        ];
    self.metaOutput.rectOfInterest = CGRectMake(0.1, 0.2, 0.8, 0.4);
    dispatch_async(dispatch_get_main_queue(), ^{
      if ([self getCaptureDeviceAuthorizationStatus]) {
        [self captureStartRuning];
        [self startAnimate];
      }
    });
  });
}

- (void)setCapDeviceZoom:(CGFloat)zoom
{
  if (self.capDevice.position == AVCaptureDevicePositionFront) {
    return;
  }
  if ([_capDevice lockForConfiguration:nil]) {
    CGFloat max = self.capDevice.activeFormat.videoMaxZoomFactor;
    CGFloat scale = MIN(zoom, max);
    self.capDevice.videoZoomFactor = scale;
    [_capDevice unlockForConfiguration];
  }
}

- (void)setCapDeviceZoom:(CGFloat)zoom rate:(CGFloat)rate {
  if (self.capDevice.position == AVCaptureDevicePositionFront) {
    return;
  }
  if ([_capDevice lockForConfiguration:nil]) {
    CGFloat max = self.capDevice.activeFormat.videoMaxZoomFactor;
    if (zoom > max) {
      [self invaliTimer];
    } else {
      [self.capDevice rampToVideoZoomFactor:zoom withRate:rate];
    }
    [_capDevice unlockForConfiguration];
  }
}

- (BOOL)getCaptureDeviceAuthorizationStatus
{
  AVAuthorizationStatus status =
  [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
  if (status == AVAuthorizationStatusDenied) {
    UIAlertController* alertController = [UIAlertController
                                          alertControllerWithTitle:@"温馨提示"
                                          message:@"没有开启相机权限"
                                          preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakself = self;
    [alertController
     addAction:[UIAlertAction
                actionWithTitle:@"确定"
                style:UIAlertActionStyleDefault
                handler:^(UIAlertAction* _Nonnull action) {
                  [weakself.curViewController dismissViewControllerAnimated:YES
                                           completion:nil];
                }]];
    
    [_curViewController presentViewController:alertController animated:YES completion:nil];
    return NO;
  }
  return YES;
}



- (UIImageView *)qrCodeView
{
  if (!_qrCodeView) {
    UIImage* hbImage = [UIImage imageNamed:@"qbScanbg@2x"];
    UIImage* strectImage =
    [hbImage stretchableImageWithLeftCapWidth:hbImage.size.width / 2
                                 topCapHeight:hbImage.size.height / 2];
    _qrCodeView = [[UIImageView alloc]
                   initWithFrame:CGRectMake((ScreenWidth - ScanWidth) / 2,
                                            (ScreenHeight - ScanWidth) / 2, ScanWidth, ScanWidth)];
    _qrCodeView.image = strectImage;
    UIImage* lineImage = [UIImage imageNamed:@"qbScanLight@2x"];
    _qrLineView = [[UIImageView alloc]
                   initWithFrame:CGRectMake(0, 0, ScanWidth, lineImage.size.height)];
    _qrLineView.image = lineImage;
    [_qrCodeView addSubview:_qrLineView];
    _qrCodeView.hidden = YES;
  }
  return _qrCodeView;
}

- (AVCaptureDevice *)capDevice
{
  if (!_capDevice) {
    _capDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [_capDevice lockForConfiguration:nil];
    if ([_capDevice isFlashModeSupported:AVCaptureFlashModeAuto]) {
      [_capDevice setFlashMode:AVCaptureFlashModeAuto];
    }
    if ([_capDevice isWhiteBalanceModeSupported:
         AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) {
      [_capDevice setWhiteBalanceMode:
       AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
    }
    if ([_capDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
      [_capDevice setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
    }
    if ([_capDevice isExposureModeSupported:
         AVCaptureExposureModeContinuousAutoExposure]) {
      [_capDevice setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
    }
    [_capDevice unlockForConfiguration];
  }
  return _capDevice;
}

- (AVCaptureDeviceInput *)capInput
{
  if (!_capInput) {
    _capInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.capDevice error:nil];
  }
  return _capInput;
}

- (AVCaptureSession *)capSession
{
  if (!_capSession) {
    _capSession = [[AVCaptureSession alloc] init];
    if ([_capSession canSetSessionPreset:AVCaptureSessionPreset1920x1080]) {
      [_capSession setSessionPreset:AVCaptureSessionPreset1920x1080];
    } else if ([_capSession canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
      [_capSession setSessionPreset:AVCaptureSessionPreset1280x720];
    } else {
      [_capSession setSessionPreset:AVCaptureSessionPresetHigh];
    }
  }
  return _capSession;
}

- (AVCaptureVideoDataOutput *)videoOutput
{
  if (!_videoOutput) {
    _videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [_videoOutput setSampleBufferDelegate:self queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    [_videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    //立即丢弃旧帧，节省内存，默认YES
    _videoOutput.alwaysDiscardsLateVideoFrames = NO;
  }
  return _videoOutput;
}

- (AVCaptureMetadataOutput *)metaOutput
{
  if (!_metaOutput) {
    _metaOutput = [[AVCaptureMetadataOutput alloc] init];
    [_metaOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
  }
  return _metaOutput;
}

- (AVCaptureVideoPreviewLayer *)perviewLayer
{
  if (!_perviewLayer) {
    _perviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.capSession];
  }
  return _perviewLayer;
}

- (void)dealloc
{
  [self captureStopRuning];
  NSLog(@"dealloc %@", NSStringFromClass(self.class));
}


@end
