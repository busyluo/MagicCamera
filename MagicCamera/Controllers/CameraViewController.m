//
//  CameraViewController.m
//  MagicCamera
//
//  Created by Xavier on 4/4/16.
//  Copyright © 2016 busyluo. All rights reserved.
//

#import "CameraViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "PreviewView.h"
#import "ForegroundView.h"
#import "UIImage+fixOrientation.h"
#import "VPInteractiveImageView.h"
#import "VPInteractiveImageViewController.h"

@import AVFoundation;
@import Photos;

static void * CapturingStillImageContext = &CapturingStillImageContext;
static void * SessionRunningContext = &SessionRunningContext;

typedef NS_ENUM( NSInteger, AVCamSetupResult ) {
    AVCamSetupResultSuccess,
    AVCamSetupResultCameraNotAuthorized,
    AVCamSetupResultSessionConfigurationFailed
};

@interface CameraViewController () <CameraHandleDelegate, InteractiveImageViewControllerDelegate>{
    CGColorSpaceRef imageColorRef;
    CGContextRef imageContextRef;
}

// Views
@property (nonatomic) UIButton *menuButton;
@property (nonatomic) UISlider *zoomSlider;
//@property (nonatomic) UIButton *flashButton;
//@property (nonatomic) UIButton *focusIn;
//@property (nonatomic) UIButton *focusOut;
//@property (nonatomic) UIButton *switchButton;

@property (nonatomic) UIButton *resetButton;
//@property (nonatomic) UIButton *undoButton;
@property (nonatomic) UIButton *takeButton;

@property (nonatomic) PreviewView *previewView;
@property (nonatomic) UIImageView *photoView;
@property (nonatomic) ForegroundView *foregroundView;

// Session management.
@property (nonatomic) dispatch_queue_t sessionQueue;
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic) AVCaptureStillImageOutput *stillImageOutput;

// Utilities.
@property (nonatomic) AVCamSetupResult setupResult;
@property (nonatomic, getter=isSessionRunning) BOOL sessionRunning;
@property (nonatomic) UIBackgroundTaskIdentifier backgroundRecordingID;
@property (nonatomic) BOOL firstPhoto;
@property (nonatomic) UIImage *imageTemp;
@end


@implementation CameraViewController

#pragma mark - Life cycle

- (instancetype)init {
    self = [super init];
    if (self) {
        _firstPhoto = YES;
    }
    return self;
}

- (void)loadView {
    [super loadView];
    
    [self configureViews];
    [self configureButtons];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initAVCaptureSession];
}

- (void)viewWillAppear:(BOOL)animated{
    
    [super viewWillAppear:YES];
    
    [self.sideViewControllerDelegate shouldDisableGesture];
    
    [self sessionStartRunning];
}

- (void)viewDidDisappear:(BOOL)animated{
    
    [self.sideViewControllerDelegate shouldEnableGesture];
    
    dispatch_async( self.sessionQueue, ^{
        if ( self.setupResult == AVCamSetupResultSuccess ) {
            [self.session stopRunning];
            [self removeObservers];
        }
    } );
    
    [super viewDidDisappear:YES];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - System Config

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

/*
 - (BOOL)prefersStatusBarHidden {
 return YES; // 返回NO表示要显示，返回YES将hiden
 }
*/

#pragma  mark - Rotate Notification
-(void)didRotateDeviceChangeNotification:(NSNotification *)notification {
    UIDeviceOrientation currentDeviceOrientation =  [[UIDevice currentDevice] orientation];
    NSLog(@"%ld", (long)currentDeviceOrientation);
}

#pragma mark - AVCapture
- (void)initAVCaptureSession{
    
    // Create the AVCaptureSession.
    self.session = [[AVCaptureSession alloc] init];
    
    // Setup the preview view.
    self.previewView.session = self.session;
    
    // Communicate with the session and other session objects on this queue.
    self.sessionQueue = dispatch_queue_create( "session queue", DISPATCH_QUEUE_SERIAL );
    
    self.setupResult = AVCamSetupResultSuccess;
    
    // Check video authorization status. Video access is required and audio access is optional.
    // If audio access is denied, audio is not recorded during movie recording.
    switch ( [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo] ) {
        case AVAuthorizationStatusAuthorized: {
            // The user has previously granted access to the camera.
            break;
        }
        case AVAuthorizationStatusNotDetermined: {
            dispatch_suspend( self.sessionQueue );
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^( BOOL granted ) {
                if ( ! granted ) {
                    self.setupResult = AVCamSetupResultCameraNotAuthorized;
                }
                dispatch_resume( self.sessionQueue );
            }];
            break;
        }
        default: {
            // The user has previously denied access.
            self.setupResult = AVCamSetupResultCameraNotAuthorized;
            break;
        }
    }
    
    dispatch_async( self.sessionQueue, ^{
        if ( self.setupResult != AVCamSetupResultSuccess ) {
            return;
        }
        
        self.backgroundRecordingID = UIBackgroundTaskInvalid;
        NSError *error = nil;
        
        AVCaptureDevice *videoDevice = [CameraViewController deviceWithMediaType:AVMediaTypeVideo preferringPosition:AVCaptureDevicePositionBack];
        AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
        
        if ( ! videoDeviceInput ) {
            NSLog( @"Could not create video device input: %@", error );
        }
        
        [self.session beginConfiguration];
        
        if ([self.session canSetSessionPreset:AVCaptureSessionPresetPhoto]) {
            self.session.sessionPreset = AVCaptureSessionPresetPhoto;  //默认是AVCaptureSessionPresetHigh
        }
        else {
            NSLog( @"Could not set the preset" );
        }
        
        if ( [self.session canAddInput:videoDeviceInput] ) {
            [self.session addInput:videoDeviceInput];
            self.videoDeviceInput = videoDeviceInput;
            
            dispatch_async( dispatch_get_main_queue(), ^{
                UIInterfaceOrientation statusBarOrientation = [UIApplication sharedApplication].statusBarOrientation;
                AVCaptureVideoOrientation initialVideoOrientation = AVCaptureVideoOrientationPortrait;
                if ( statusBarOrientation != UIInterfaceOrientationUnknown ) {
                    initialVideoOrientation = (AVCaptureVideoOrientation)statusBarOrientation;
                }
                AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.previewView.layer;
                previewLayer.connection.videoOrientation = initialVideoOrientation;
                [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
            } );
        }
        else {
            NSLog( @"Could not add video device input to the session" );
            self.setupResult = AVCamSetupResultSessionConfigurationFailed;
        }
        
        AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
        if ( [self.session canAddOutput:stillImageOutput] ) {
            stillImageOutput.outputSettings = @{AVVideoCodecKey : AVVideoCodecJPEG};
            [self.session addOutput:stillImageOutput];
            self.stillImageOutput = stillImageOutput;
        }
        else {
            NSLog( @"Could not add still image output to the session" );
            self.setupResult = AVCamSetupResultSessionConfigurationFailed;
        }
        
        [self.session commitConfiguration];
    } );
}

- (void) sessionStartRunning {
    
    dispatch_async( self.sessionQueue, ^{
        switch ( self.setupResult )
        {
            case AVCamSetupResultSuccess:
            {
                // Only setup observers and start the session running if setup succeeded.
                [self addObservers];
                [self.session startRunning];
                self.sessionRunning = self.session.isRunning;
                break;
            }
            case AVCamSetupResultCameraNotAuthorized:
            {
                dispatch_async( dispatch_get_main_queue(), ^{
                    NSString *message = NSLocalizedString( @"AVCam doesn't have permission to use the camera, please change privacy settings", @"Alert message when the user has denied access to the camera" );
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"AVCam" message:message preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"OK", @"Alert OK button" ) style:UIAlertActionStyleCancel handler:nil];
                    [alertController addAction:cancelAction];
                    // Provide quick access to Settings.
                    UIAlertAction *settingsAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"Settings", @"Alert button to open Settings" ) style:UIAlertActionStyleDefault handler:^( UIAlertAction *action ) {
                        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
                    }];
                    [alertController addAction:settingsAction];
                    [self presentViewController:alertController animated:YES completion:nil];
                } );
                break;
            }
            case AVCamSetupResultSessionConfigurationFailed:
            {
                dispatch_async( dispatch_get_main_queue(), ^{
                    NSString *message = NSLocalizedString( @"Unable to capture media", @"Alert message when something goes wrong during capture session configuration" );
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"AVCam" message:message preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"OK", @"Alert OK button" ) style:UIAlertActionStyleCancel handler:nil];
                    [alertController addAction:cancelAction];
                    [self presentViewController:alertController animated:YES completion:nil];
                } );
                break;
            }
        }
    } );
}

#pragma mark - Private method

- (void) configureButtons {
    
    //top
    self.menuButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.menuButton.frame = CGRectMake(5.0, 25, 30.0, 30.0);
    [self.menuButton setImage:[UIImage imageNamed:@"menu"] forState:UIControlStateNormal];
    [self.view addSubview:self.menuButton];
    [self.menuButton addTarget:self action:@selector(showMenu:) forControlEvents:UIControlEventTouchUpInside];
    
    self.zoomSlider = [[UISlider alloc] initWithFrame:CGRectMake(kScreenWidth / 2 - 100, 28, 200, 30)];
    self.zoomSlider.minimumValue = 1.0;
    self.zoomSlider.maximumValue = 3.0;
    self.zoomSlider.continuous = YES;
    [self.zoomSlider addTarget:self action:@selector(zoomSliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.zoomSlider];
    
    //bottom
    self.resetButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.resetButton.frame = CGRectMake(kScreenWidth - 50, kScreenHeight - 45.0, 20.0, 24.0);
    [self.resetButton setImage:[UIImage imageNamed:@"reset"] forState:UIControlStateNormal];
    [self.view addSubview:self.resetButton];
    [self.resetButton addTarget:self action:@selector(reset:) forControlEvents:UIControlEventTouchUpInside];
    
    self.takeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.takeButton.frame = CGRectMake(kScreenWidth / 2 - 30, kScreenHeight - 70.0, 60.0, 60.0);
    [self.takeButton setImage:[UIImage imageNamed:@"shutter"] forState:UIControlStateNormal];
    [self.view addSubview:self.takeButton];
    [self.takeButton addTarget:self action:@selector(takePhoto:) forControlEvents:UIControlEventTouchDown];
}

- (void) configureViews {
    self.previewView = [[PreviewView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, kScreenHeight)];
    self.previewView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:self.previewView];
    
    CGFloat photoHeight = kScreenWidth / 3.0 * 4.0;
    CGFloat photoViewOriginY = (kScreenHeight - photoHeight) / 2.0;
    self.photoView = [[UIImageView alloc] initWithFrame:CGRectMake(0, photoViewOriginY, kScreenWidth, photoHeight)];
    self.photoView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.photoView];
    
    self.foregroundView = [[ForegroundView alloc] initWithFrame:CGRectMake(0, photoViewOriginY, kScreenWidth, photoHeight)];
    self.foregroundView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.foregroundView];
    self.foregroundView.delegate = self;
    
    self.view.backgroundColor = [UIColor blackColor];
}

- (IBAction)zoomSliderValueChanged:(id)sender {
    UISlider* control = (UISlider*)sender;
    float value = control.value;
    
    AVCaptureDevice *device = self.videoDeviceInput.device;
    NSError *error = nil;
    if ( [device lockForConfiguration:&error] ) {
        
        [device setVideoZoomFactor:value];
        
        [device unlockForConfiguration];
    }
    else {
        NSLog( @"Could not lock device for configuration: %@", error );
    }
    
}

#pragma mark Device Configuration

- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange
{
    dispatch_async( self.sessionQueue, ^{
        AVCaptureDevice *device = self.videoDeviceInput.device;
        NSError *error = nil;
        if ( [device lockForConfiguration:&error] ) {
            // Setting (focus/exposure)PointOfInterest alone does not initiate a (focus/exposure) operation.
            // Call -set(Focus/Exposure)Mode: to apply the new point of interest.
            if ( device.isFocusPointOfInterestSupported && [device isFocusModeSupported:focusMode] ) {
                device.focusPointOfInterest = point;
                device.focusMode = focusMode;
            }
            
            if ( device.isExposurePointOfInterestSupported && [device isExposureModeSupported:exposureMode] ) {
                device.exposurePointOfInterest = point;
                device.exposureMode = exposureMode;
            }
            
            device.subjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange;
            [device unlockForConfiguration];
        }
        else {
            NSLog( @"Could not lock device for configuration: %@", error );
        }
    } );
    
}

- (void)setSubjectAreaChangeMonitoring:(BOOL)monitorSubjectAreaChange
{
    dispatch_sync( self.sessionQueue, ^{
        AVCaptureDevice *device = self.videoDeviceInput.device;
        NSError *error = nil;
        if ( [device lockForConfiguration:&error] ) {
            
            device.subjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange;
            [device unlockForConfiguration];
        }
        else {
            NSLog( @"Could not lock device for configuration: %@", error );
        }
    } );
    
}

- (void)setFocusMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode{
    dispatch_async( self.sessionQueue, ^{
        AVCaptureDevice *device = self.videoDeviceInput.device;
        NSError *error = nil;
        if ( [device lockForConfiguration:&error] ) {
            if ([device isFocusModeSupported:focusMode] ) {
                device.focusMode = focusMode;
            }
            if ([device isExposureModeSupported:exposureMode] ) {
                device.exposureMode = exposureMode;
            }
            [device unlockForConfiguration];
        } else {
            NSLog( @"Could not lock device for configuration: %@", error );
        }
    } );
}

+ (void)setFlashMode:(AVCaptureFlashMode)flashMode forDevice:(AVCaptureDevice *)device
{
    if ( device.hasFlash && [device isFlashModeSupported:flashMode] ) {
        NSError *error = nil;
        if ( [device lockForConfiguration:&error] ) {
            device.flashMode = flashMode;
            [device unlockForConfiguration];
        }
        else {
            NSLog( @"Could not lock device for configuration: %@", error );
        }
    }
}

+ (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
    AVCaptureDevice *captureDevice = devices.firstObject;
    
    for ( AVCaptureDevice *device in devices ) {
        if ( device.position == position ) {
            captureDevice = device;
            break;
        }
    }
    
    return captureDevice;
}



#pragma mark KVO and Notifications

- (void)addObservers
{
    [self.session addObserver:self forKeyPath:@"running" options:NSKeyValueObservingOptionNew context:SessionRunningContext];
    [self.stillImageOutput addObserver:self forKeyPath:@"capturingStillImage" options:NSKeyValueObservingOptionNew context:CapturingStillImageContext];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(subjectAreaDidChange:)
                                                 name:AVCaptureDeviceSubjectAreaDidChangeNotification
                                               object:self.videoDeviceInput.device];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didRotateDeviceChangeNotification:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
}

- (void)removeObservers
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self.session removeObserver:self forKeyPath:@"running" context:SessionRunningContext];
    [self.stillImageOutput removeObserver:self forKeyPath:@"capturingStillImage" context:CapturingStillImageContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ( context == CapturingStillImageContext ) {
        BOOL isCapturingStillImage = [change[NSKeyValueChangeNewKey] boolValue];
        
        if ( isCapturingStillImage ) {
            dispatch_async( dispatch_get_main_queue(), ^{
                self.previewView.layer.opacity = 0.0;
                [UIView animateWithDuration:0.25 animations:^{
                    self.previewView.layer.opacity = 1.0;
                }];
            } );
        }
    }
    else if ( context == SessionRunningContext ) {
        //BOOL isSessionRunning = [change[NSKeyValueChangeNewKey] boolValue];
        
        dispatch_async( dispatch_get_main_queue(), ^{
            // Only enable the ability to change camera if the device has more than one camera.
            
        } );
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)subjectAreaDidChange:(NSNotification *)notification
{
/*
    NSLog(@"NSNotification:subjectAreaDidChange");
    CGPoint devicePoint = CGPointMake( 0.5, 0.5 );
    [self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:YES];
*/
}

#pragma mark - Actions

- (IBAction) showMenu:(id)sender {
    [self.sideViewControllerDelegate showLeftViewController];
}

- (IBAction) reset:(id)sender {
    NSLog(@"reset");
    
    _firstPhoto = YES;
    self.photoView.image = nil;
    [self.foregroundView reset];
    
    
    CGPoint devicePoint = CGPointMake( 0.5, 0.5 );
    [self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:YES];
}


- (IBAction) takePhoto:(id)sender {
    NSLog(@"start");
    self.takeButton.enabled = NO;
    
    dispatch_async( self.sessionQueue, ^{
        AVCaptureConnection *connection = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
        AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.previewView.layer;
        
        NSLog(@"%f,%f,%f,%f", previewLayer.frame.origin.x, previewLayer.frame.origin.y,
              previewLayer.frame.size.width, previewLayer.frame.size.height);
        
        // Update the orientation on the still image output video connection before capturing.
        UIDeviceOrientation currentDeviceOrientation =  [[UIDevice currentDevice] orientation];
        //connection.videoOrientation = (AVCaptureVideoOrientation)currentDeviceOrientation;
        connection.videoOrientation = AVCaptureVideoOrientationPortrait;
        
        // Flash set to Auto for Still Capture.
        [CameraViewController setFlashMode:AVCaptureFlashModeOff forDevice:self.videoDeviceInput.device];
        
        // Capture a still image.
        [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:^( CMSampleBufferRef imageDataSampleBuffer, NSError *error ) {
            if ( imageDataSampleBuffer ) {
                // The sample buffer is not retained. Create image data before saving the still image to the photo library asynchronously.
                NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                UIImage *image = [UIImage imageWithData:imageData];
                image = [image fixOrientation];
                
                CGImageRef imageRef = [image CGImage];
                __block UIImage *imageDst;
                
                CGFloat height = self.foregroundView.frame.size.height;
                CGFloat scala = image.size.height / height;
        
                if (_firstPhoto) {
                    
                    [self setFocusMode:AVCaptureFocusModeLocked exposeWithMode:AVCaptureExposureModeLocked];
                    
                    if (self.foregroundView.firstPath) {
                        imageContextRef = CGBitmapContextCreate(NULL, image.size.width, image.size.height,
                                                                CGImageGetBitsPerComponent(image.CGImage), 0,
                                                                CGImageGetColorSpace(image.CGImage),
                                                                kCGImageAlphaPremultipliedLast);
                        
                        CGContextSaveGState(imageContextRef);
                        
                        CGAffineTransform pathTransform = CGAffineTransformTranslate(CGAffineTransformScale(CGAffineTransformIdentity, scala, -scala), 0, -height);
                        CGMutablePathRef mutPath = CGPathCreateMutableCopyByTransformingPath(self.foregroundView.firstPath, &pathTransform);
                        CGContextAddPath(imageContextRef, mutPath);
                        CGContextClip(imageContextRef);
                        CGContextDrawImage(imageContextRef, CGRectMake(0, 0, image.size.width, image.size.height), imageRef);
                        CGPathRelease(mutPath);
                        
                        CGImageRef imageRef = CGBitmapContextCreateImage(imageContextRef);
                        imageDst = [UIImage imageWithCGImage:imageRef];
                        CGImageRelease(imageRef);
                        
                        CGContextRestoreGState(imageContextRef);

                        _firstPhoto = NO;
                    } else {
                        imageDst = image;
                    }
                } else {
                    CGPoint devicePoint = CGPointMake( 0.5, 0.5 );
                    [self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:YES];
                    
                    CGContextSaveGState(imageContextRef);
                    
                    CGAffineTransform pathTransform = CGAffineTransformTranslate(CGAffineTransformScale(CGAffineTransformIdentity, scala, -scala), 0, -height);
                    CGMutablePathRef mutPath = CGPathCreateMutableCopyByTransformingPath(self.foregroundView.secondPath, &pathTransform);
                    CGContextAddPath(imageContextRef, mutPath);
                    CGContextClip(imageContextRef);
                    CGPathRelease(mutPath);
                    
                    CGContextDrawImage(imageContextRef, CGRectMake(0, 0, image.size.width, image.size.height), image.CGImage);
                    
                    CGContextRestoreGState(imageContextRef);
                    
                    CGImageRef imageRef = CGBitmapContextCreateImage(imageContextRef);
                    imageDst = [UIImage imageWithCGImage:imageRef];
                    CGImageRelease(imageRef);
                    
                    CGContextRelease(imageContextRef);
                    imageContextRef = nil;
                    
                    _firstPhoto = YES;
                }
                
                dispatch_async( dispatch_get_main_queue(), ^{
                    
                    if(_firstPhoto){
                        UIImageOrientation imgOrientation = [self getImageOrientationFromDeviceOrientation:currentDeviceOrientation];
                        imageDst = [imageDst fixOrientationFromOrientation:imgOrientation];
                        self.imageTemp = imageDst;
                        VPInteractiveImageView *interactiveImageView = [[VPInteractiveImageView alloc] initWithImage:imageDst];
                        interactiveImageView.photoDelegate = self;
                        [interactiveImageView presentFullscreen];
                    } else {
                        self.photoView.image =  imageDst;
                    }
                    
                    self.takeButton.enabled = YES;
                } );
            }
            else {
                NSLog( @"Could not capture still image: %@", error );
            }
        }];
    } );
}

- (UIImageOrientation)getImageOrientationFromDeviceOrientation:(UIDeviceOrientation)deviceOrientation {
    UIImageOrientation imgOrientation;
    switch (deviceOrientation) {
        case UIDeviceOrientationLandscapeLeft:
            imgOrientation = UIImageOrientationLeft;
            break;
        case UIDeviceOrientationLandscapeRight:
            imgOrientation = UIImageOrientationRight;
        default:
            imgOrientation = UIImageOrientationUp;
            break;
    }
    return imgOrientation;
}

- (void)tapFirstPath {
    
}
- (void)tapSecondPath {
    
}

#pragma mark - ForegroundView delegate
- (void)setFoucusAtPoint:(CGPoint)point {
    
    AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.previewView.layer;
    CGPoint pointInDevice = [previewLayer captureDevicePointOfInterestForPoint:point];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposeWithMode:AVCaptureExposureModeAutoExpose atDevicePoint:pointInDevice monitorSubjectAreaChange:NO];
}

#pragma mark - Image processing
+ (UIImage *)compressImage:(UIImage *)sourceImage {
    CGSize imageSize = sourceImage.size;
    
    CGFloat width = imageSize.width;
    CGFloat height = imageSize.height;
    
    NSLog(@"compressImage %f，%f", width, height);
    
    CGFloat targetWidth = kScreenWidth;
    CGFloat targetHeight = (targetWidth / width) * height;
    
    UIGraphicsBeginImageContext(CGSizeMake(targetWidth, targetHeight));
    [sourceImage drawInRect:CGRectMake(0, 0, targetWidth, targetHeight)];
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    NSLog(@"compressImage %f，%f", newImage.size.width, newImage.size.height);
    
    return newImage;
}

#pragma mark - InteractiveImageViewDelegate
-(void)savePhoto {
    
    UIImage *image = self.imageTemp;
    if(!image){
        return;
    }
    UIImageWriteToSavedPhotosAlbum(image, self, nil, nil);
    
    [self reset:nil];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:@"照片已经保存到相册" preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alertController animated:YES completion:nil];
    
    [self performSelector:@selector(dismssAlertController:) withObject:alertController afterDelay:1.6];
}

-(void)dismssAlertController:(UIAlertController*)alertController
{
    [alertController dismissViewControllerAnimated:YES completion:nil];
}


-(void)discardPhoto {
    [self reset:nil];
}

@end

