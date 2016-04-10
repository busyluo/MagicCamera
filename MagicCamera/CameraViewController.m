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

@import AVFoundation;
@import Photos;

static void * CapturingStillImageContext = &CapturingStillImageContext;
static void * SessionRunningContext = &SessionRunningContext;

typedef NS_ENUM( NSInteger, AVCamSetupResult ) {
    AVCamSetupResultSuccess,
    AVCamSetupResultCameraNotAuthorized,
    AVCamSetupResultSessionConfigurationFailed
};

@interface CameraViewController (){
    CGColorSpaceRef imageColorRef;
    CGContextRef imageContextRef;
}

// Views
@property (nonatomic) UIButton *menuButton;
@property (nonatomic) UIButton *flashButton;
//@property (nonatomic) UIButton *timerButton;
@property (nonatomic) UIButton *focusIn;
@property (nonatomic) UIButton *focusOut;
@property (nonatomic) UIButton *switchButton;

@property (nonatomic) UIButton *resetButton;
@property (nonatomic) UIButton *undoButton;
@property (nonatomic) UIButton *startButton;

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

@end


@implementation CameraViewController

#pragma mark - life cycle

- (instancetype)init {
    self = [super init];
    if (self) {
        
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
    return NO;
}

- (BOOL)prefersStatusBarHidden {
    return YES; // 返回NO表示要显示，返回YES将hiden
}

#pragma  mark - Rotate Notification
-(void)didRotateDeviceChangeNotification:(NSNotification *)notification {
    UIDeviceOrientation currentDeviceOrientation =  [[UIDevice currentDevice] orientation];
    /*if ((newOrientation == UIInterfaceOrientationLandscapeLeft || newOrientation == UIInterfaceOrientationLandscapeRight))
     {
     }*/
    NSLog(@"%ld", currentDeviceOrientation);
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

#pragma mark - private method

- (void) configureButtons {
    
    //top
    self.menuButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.menuButton.frame = CGRectMake(0.0, 0.0, 40.0, 40.0);
    [self.menuButton setTitle:@"三" forState:UIControlStateNormal];
    [self.view addSubview:self.menuButton];
    [self.menuButton addTarget:self action:@selector(showMenu:) forControlEvents:UIControlEventTouchUpInside];
    
    self.flashButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.flashButton.frame = CGRectMake(kScreenWidth / 4.0 - 20, 0.0, 40.0, 40.0);
    [self.flashButton setTitle:@"X" forState:UIControlStateNormal];
    [self.view addSubview:self.flashButton];
    [self.flashButton addTarget:self action:@selector(changeFlash:) forControlEvents:UIControlEventTouchUpInside];
    
    self.focusOut = [UIButton buttonWithType:UIButtonTypeCustom];
    self.focusOut.frame = CGRectMake( 2 * kScreenWidth / 4.0 - 20, 0.0, 40.0, 40.0);
    [self.focusOut setTitle:@"-" forState:UIControlStateNormal];
    [self.view addSubview:self.focusOut];
    [self.focusOut addTarget:self action:@selector(focusOut:) forControlEvents:UIControlEventTouchUpInside];
    
    self.focusIn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.focusIn.frame = CGRectMake( 3 * kScreenWidth / 4.0 - 20, 0.0, 40.0, 40.0);
    [self.focusIn setTitle:@"+" forState:UIControlStateNormal];
    [self.view addSubview:self.focusIn];
    [self.focusIn addTarget:self action:@selector(focusIn:) forControlEvents:UIControlEventTouchUpInside];
    
    self.switchButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.switchButton.frame = CGRectMake(kScreenWidth - 40, 0.0, 40.0, 40.0);
    [self.view addSubview:self.switchButton];
    [self.switchButton setTitle:@"S" forState:UIControlStateNormal];
    [self.switchButton addTarget:self action:@selector(changeCamera:) forControlEvents:UIControlEventTouchUpInside];
    
    //bottom
    self.resetButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.resetButton.frame = CGRectMake(20, kScreenHeight - 40.0, 40.0, 40.0);
    [self.resetButton setTitle:@"R" forState:UIControlStateNormal];
    [self.view addSubview:self.resetButton];
    [self.resetButton addTarget:self action:@selector(reset:) forControlEvents:UIControlEventTouchUpInside];
    
    self.undoButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.undoButton.frame = CGRectMake(kScreenWidth - 60, kScreenHeight - 40.0, 40.0, 40.0);
    [self.undoButton setTitle:@"U" forState:UIControlStateNormal];
    [self.view addSubview:self.undoButton];
    [self.undoButton addTarget:self action:@selector(undo:) forControlEvents:UIControlEventTouchUpInside];
    
    self.startButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.startButton.frame = CGRectMake(kScreenWidth / 2 - 30, kScreenHeight - 60.0, 60.0, 60.0);
    [self.startButton setTitle:@"O" forState:UIControlStateNormal];
    [self.view addSubview:self.startButton];
    [self.startButton addTarget:self action:@selector(start:) forControlEvents:UIControlEventTouchDown];
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
    
    self.view.backgroundColor = [UIColor blackColor];
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
    CGPoint devicePoint = CGPointMake( 0.5, 0.5 );
    [self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:NO];
}

#pragma mark - Actions

- (IBAction) showMenu:(id)sender {
    [self.sideViewControllerDelegate showLeftViewController];
}

- (IBAction) changeFlash:(id)sender {
    NSLog(@"changeFlash");
}

- (IBAction) focusIn:(id)sender {
    NSLog(@"focusIn");
}

- (IBAction) focusOut:(id)sender {
    NSLog(@"focusOut");
}

- (IBAction) changeCamera:(id)sender {
    NSLog(@"changeCamera");
}

- (IBAction) undo:(id)sender {
    NSLog(@"undo");
}

- (IBAction) reset:(id)sender {
    NSLog(@"reset");
    
    //NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
    //UIImage *image = [UIImage imageWithData: imageData];
    UIImage *image1 = [UIImage imageNamed:@"test"];
    UIImage *image2 = [UIImage imageNamed:@"test"];
    
    //UIGraphicsBeginImageContext(image.size);
    //viewRect = self.foregroundView.bounds;
    
    CGColorSpaceRef colorRef = CGColorSpaceCreateDeviceRGB();
    CGContextRef contextRef = CGBitmapContextCreate(nil, image1.size.width, image1.size.height, 8, image1.size.width*4, colorRef, kCGImageAlphaPremultipliedFirst);
    CGContextSaveGState(contextRef);
    CGMutablePathRef mutPath = CGPathCreateMutable();
    CGPathMoveToPoint(mutPath, NULL, 0, 0);
    CGPathAddLineToPoint(mutPath, NULL, 0, image1.size.height);
    CGPathAddLineToPoint(mutPath, NULL, image1.size.width / 2, image1.size.height);
    CGPathAddLineToPoint(mutPath, NULL, image1.size.width / 2, 0);
    CGPathCloseSubpath(mutPath);
    CGContextAddPath(contextRef, mutPath);
    CGContextClip(contextRef);
    CGContextDrawImage(contextRef, CGRectMake(0, 0, image1.size.width, image1.size.height), image1.CGImage);
    CGContextRestoreGState(contextRef);
    
    CGContextSaveGState(contextRef);
    CGMutablePathRef mutPath2 = CGPathCreateMutable();
    CGPathMoveToPoint(mutPath2, NULL, image1.size.width / 2, 0);
    CGPathAddLineToPoint(mutPath2, NULL, image1.size.width / 2, image1.size.height);
    CGPathAddLineToPoint(mutPath2, NULL, image1.size.width, image1.size.height);
    CGPathAddLineToPoint(mutPath2, NULL, image1.size.width, 0);
    CGPathCloseSubpath(mutPath2);
    CGContextAddPath(contextRef, mutPath2);
    CGContextClip(contextRef);
    CGContextDrawImage(contextRef, CGRectMake(0, 0, image2.size.width, image2.size.height), image2.CGImage);
    CGContextRestoreGState(contextRef);
    
    
    CGImageRef imageRef = CGBitmapContextCreateImage(contextRef);
    UIImage* imageDst = [UIImage imageWithCGImage:imageRef scale:[UIScreen mainScreen].scale orientation:UIImageOrientationUp];
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorRef);
    
    UIImage *compressedImage = [CameraViewController compressImage:imageDst];
    self.photoView.image =  compressedImage;
}



- (IBAction) start:(id)sender {
    NSLog(@"start");
    self.startButton.enabled = NO;
    
    dispatch_async( self.sessionQueue, ^{
        AVCaptureConnection *connection = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
        AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.previewView.layer;
        
        NSLog(@"%f,%f,%f,%f", previewLayer.frame.origin.x, previewLayer.frame.origin.y,
              previewLayer.frame.size.width, previewLayer.frame.size.height);
        
        // Update the orientation on the still image output video connection before capturing.
        connection.videoOrientation = previewLayer.connection.videoOrientation;
        
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
                UIImage* imageDst;
                
                CGFloat height = self.foregroundView.frame.size.height;
                CGFloat scala = image.size.height / height;
                
                if (!imageContextRef) {
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
                    CGImageRef imageRef = CGBitmapContextCreateImage(imageContextRef);
                    imageDst = [UIImage imageWithCGImage:imageRef];
                    
                    CGContextRestoreGState(imageContextRef);
                } else {
                    CGContextSaveGState(imageContextRef);
                    CGAffineTransform pathTransform = CGAffineTransformTranslate(CGAffineTransformScale(CGAffineTransformIdentity, scala, -scala), 0, -height);
                    CGMutablePathRef mutPath = CGPathCreateMutableCopyByTransformingPath(self.foregroundView.secondPath, &pathTransform);
                    CGContextAddPath(imageContextRef, mutPath);
                    CGContextClip(imageContextRef);
                    CGContextDrawImage(imageContextRef, CGRectMake(0, 0, image.size.width, image.size.height), image.CGImage);
                    CGContextRestoreGState(imageContextRef);
                    
                    CGImageRef imageRef = CGBitmapContextCreateImage(imageContextRef);
                    imageDst = [UIImage imageWithCGImage:imageRef];
                    
                    CGContextRelease(imageContextRef);
                }
                
                dispatch_async( dispatch_get_main_queue(), ^{
                    self.photoView.image =  imageDst;
                    self.startButton.enabled = YES;
                } );
                
                /*
                 [PHPhotoLibrary requestAuthorization:^( PHAuthorizationStatus status ) {
                 if ( status == PHAuthorizationStatusAuthorized ) {
                 // To preserve the metadata, we create an asset from the JPEG NSData representation.
                 // Note that creating an asset from a UIImage discards the metadata.
                 // In iOS 9, we can use -[PHAssetCreationRequest addResourceWithType:data:options].
                 // In iOS 8, we save the image to a temporary file and use +[PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:].
                 if ( [PHAssetCreationRequest class] ) {
                 [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                 //[[PHAssetCreationRequest creationRequestForAsset] addResourceWithType:PHAssetResourceTypePhoto data:imageData options:nil];
                 [PHAssetCreationRequest creationRequestForAssetFromImage:image];
                 } completionHandler:^( BOOL success, NSError *error ) {
                 if ( ! success ) {
                 NSLog( @"Error occurred while saving image to photo library: %@", error );
                 }
                 }];
                 }
                 else {
                 NSString *temporaryFileName = [NSProcessInfo processInfo].globallyUniqueString;
                 NSString *temporaryFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[temporaryFileName stringByAppendingPathExtension:@"jpg"]];
                 NSURL *temporaryFileURL = [NSURL fileURLWithPath:temporaryFilePath];
                 
                 [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                 NSError *error = nil;
                 [imageData writeToURL:temporaryFileURL options:NSDataWritingAtomic error:&error];
                 if ( error ) {
                 NSLog( @"Error occured while writing image data to a temporary file: %@", error );
                 }
                 else {
                 [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:temporaryFileURL];
                 }
                 } completionHandler:^( BOOL success, NSError *error ) {
                 if ( ! success ) {
                 NSLog( @"Error occurred while saving image to photo library: %@", error );
                 }
                 
                 // Delete the temporary file.
                 [[NSFileManager defaultManager] removeItemAtURL:temporaryFileURL error:nil];
                 }];
                 }
                 }
                 }];*/
            }
            else {
                NSLog( @"Could not capture still image: %@", error );
            }
        }];
    } );
}

/*
 
 - (UIImage *) combine:(UIImage*)leftImage :(UIImage*)rightImage {
 CGFloat width = leftImage.size.width * 2;
 CGFloat height = leftImage.size.height;
 CGSize offScreenSize = CGSizeMake(width, height);
 
 UIGraphicsBeginImageContext(offScreenSize);
 
 // 描述圆形的路径
 // UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
 
 // 把圆形路径设置裁剪区域（将区域外的内容裁剪掉，是现实区域内的内容）
 [path addClip];
 
 CGRect rect = CGRectMake(0, 0, width/2, height);
 [leftImage drawInRect:rect];
 
 rect.origin.x += width/2;
 [rightImage drawInRect:rect];
 
 UIImage* imagez = UIGraphicsGetImageFromCurrentImageContext();
 
 UIGraphicsEndImageContext();
 
 return imagez;
 }*/

#pragma mark - image processing

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



@end

