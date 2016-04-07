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

@interface CameraViewController ()

//Views
@property (strong, nonatomic) UIButton *backButton;
@property (strong, nonatomic) UIButton *flashButton;
@property (strong, nonatomic) UIButton *timerButton;
@property (strong, nonatomic) UIButton *switchButton;

@property (strong, nonatomic) UIButton *resetScopeButton;
@property (strong, nonatomic) UIButton *resetPhotoButton;
@property (strong, nonatomic) UIButton *undoScopeButton;
@property (strong, nonatomic) UIButton *undoPhotoButton;
@property (strong, nonatomic) UIButton *startButton;

@property (strong, nonatomic) PreviewView *previewView;         //显示相机预览图
@property (strong, nonatomic) ForegroundView *foregroundView;   //显示分割路径以及提示

//AVFoundation
@property (strong, nonatomic) dispatch_queue_t sessionQueue;
@property (strong, nonatomic) AVCaptureSession* session;                    //AVCaptureSession对象来执行输入设备和输出设备之间的数据传递
@property (strong, nonatomic) AVCaptureDeviceInput* videoInput;             // 输入设备
@property (strong, nonatomic) AVCaptureStillImageOutput* stillImageOutput;  //照片输出流

@property (strong, nonatomic) AVCaptureVideoPreviewLayer* previewLayer;     //预览图层
@property (strong, nonatomic) CALayer* previewLayer2;                       //预览图层
@property (assign, nonatomic) CGFloat beginGestureScale;                    //记录开始的缩放比例
@property (assign, nonatomic) CGFloat effectiveScale;                       //最后的缩放比例

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
    self.view.backgroundColor = [UIColor blackColor];
    
    [self configureButtons];

    self.previewView = [[PreviewView alloc] initWithFrame:CGRectMake(0, 40, kScreenWidth, kScreenHeight - 100)];
    self.previewView.backgroundColor = [UIColor greenColor];
    [self.view addSubview:self.previewView];
    
    self.foregroundView = [[ForegroundView alloc] initWithFrame:CGRectMake(0, 40, kScreenWidth, kScreenHeight - 100)];
    self.foregroundView.backgroundColor = [UIColor clearColor];
    
    [self.view addSubview:self.foregroundView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initAVCaptureSession];
    
    [self.session startRunning];
    
    self.effectiveScale = self.beginGestureScale = 1.0f;
}

- (void)viewWillAppear:(BOOL)animated{
    
    [super viewWillAppear:YES];
    
    [self.sideViewControllerDelegate shouldDisableGesture];
    
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didRotateDeviceChangeNotification:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
    
    if (self.session) {
        [self.session startRunning];
    }
}

- (void)viewDidDisappear:(BOOL)animated{
    
    [super viewDidDisappear:YES];
    
    [self.sideViewControllerDelegate shouldEnableGesture];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
    
    if (self.session) {
        [self.session stopRunning];
    }
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

//http://www.jianshu.com/p/f014d0dfeac3

#pragma mark - AVCapture
- (void)initAVCaptureSession{
    
    /*
     session的一端是相机的输入，另一端是输出到相册
     */
    
    NSError *error;
    
    //初始化输入端
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if ([device lockForConfiguration:&error]) {      //You must call this method before attempting to configure the hardware related properties of the device.
        [device setFlashMode:AVCaptureFlashModeAuto];//设置闪光灯为自动
        [device unlockForConfiguration];
    } else {
        NSLog(@"%@",error);
    }

    
    self.videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:device error:&error];
    if (error) {
        NSLog(@"%@",error);
    }
    
    //初始化输出端
    self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary * outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey, nil];//输出设置。AVVideoCodecJPEG   输出jpeg格式图片
    [self.stillImageOutput setOutputSettings:outputSettings];
    
    //初始化连接
    self.session = [[AVCaptureSession alloc] init];
    if ([self.session canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
        self.session.sessionPreset = AVCaptureSessionPreset1280x720;  //默认是AVCaptureSessionPresetHigh
    }
    else {
        // Handle the failure.
    }
    
    //将输入和输出端添加到连接中
    if ([self.session canAddInput:self.videoInput]) {
        [self.session addInput:self.videoInput];
    }
    if ([self.session canAddOutput:self.stillImageOutput]) {
        [self.session addOutput:self.stillImageOutput];
    }
    
    //初始化预览图层
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    /*
     AVLayerVideoGravityResizeAspect      保持长宽比，显示所有内容，可能会有白边
     AVLayerVideoGravityResizeAspectFill  保持长宽比，填充图层，会有一部分内容无法显示
     AVLayerVideoGravityResize            拉伸以填满图层
     */
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    //self.previewLayer.contents = (id)[UIImage imageNamed:@"test"].CGImage;
    
    ////////////////
    CGFloat radius = 30.0;
    
    CGSize size = self.previewView.frame.size;
    CAShapeLayer *shapeLayer = [CAShapeLayer layer];
    [shapeLayer setFillColor:[[UIColor whiteColor] CGColor]];
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, size.width - radius, size.height);
    CGPathAddArc(path, NULL, size.width-radius, size.height-radius, radius, M_PI/2, 0.0, YES);
    CGPathAddLineToPoint(path, NULL, size.width, 0.0);
    CGPathAddLineToPoint(path, NULL, 110.0, 0.0);
    CGPathAddLineToPoint(path, NULL, 0.0, size.height - radius);
    CGPathAddArc(path, NULL, radius, size.height - radius, radius, M_PI, M_PI/2, YES);
    CGPathCloseSubpath(path);
    [shapeLayer setPath:path];
    CFRelease(path);

    
    self.previewLayer.frame = self.previewView.bounds;
    //self.previewLayer.mask = shapeLayer;
    [self.previewView.layer addSublayer:self.previewLayer];
    //////////////////////////
    
    self.previewLayer2 = [CALayer layer];
    self.previewLayer2.frame = self.previewView.bounds;
    self.previewLayer2.contents = (id)[UIImage imageNamed:@"test"].CGImage;
    
    CAShapeLayer *layer2 = [CAShapeLayer layer];
    layer2.frame = self.previewView.bounds;
    
    CGMutablePathRef path2 = CGPathCreateMutable();
    CGPathMoveToPoint(path2, NULL, 0.0, 0.0);
    CGPathAddLineToPoint(path2, NULL, 110.0, 0.0);
    CGPathAddLineToPoint(path2, NULL, 0.0, size.height - radius);
    CGPathMoveToPoint(path2, NULL, 0.0, 0.0);
    CGPathCloseSubpath(path2);
    [layer2 setPath:path2];
    CFRelease(path2);
    
    self.previewLayer2.frame = self.previewView.bounds;
    self.previewLayer2.mask = layer2;
    //[self.previewView.layer addSublayer:self.previewLayer2];
    
    /*

    CAShapeLayer *layer2 = [CAShapeLayer layer];
    layer2.frame = self.previewView.bounds;
    //layer2.zPosition = 0;
    
    UIImage *image = [UIImage imageNamed:@"test"];
    layer2.contents = (id)image.CGImage;
    //layer2.backgroundColor = [UIColor clearColor].CGColor;

    //[layer2 setFillColor:[[UIColor whiteColor] CGColor]];
    
    CGMutablePathRef path2 = CGPathCreateMutable();
    CGPathMoveToPoint(path2, NULL, 0.0, 0.0);
    CGPathAddLineToPoint(path2, NULL, 110.0, 0.0);
    CGPathAddLineToPoint(path2, NULL, 0.0, size.height - radius);
    CGPathMoveToPoint(path2, NULL, 0.0, 0.0);
    CGPathCloseSubpath(path2);
    [layer2 setPath:path2];
    CFRelease(path2);
    
    
    self.previewLayer2.frame = self.previewView.bounds;
    //self.previewLayer2.mask = layer2;
    [self.previewView.layer addSublayer:layer2];*/
}

#pragma mark - private method

- (void) configureButtons {
    
    //top
    self.backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.backButton.frame = CGRectMake(0.0, 0.0, 40.0, 40.0);
    [self.backButton setTitle:@"三" forState:UIControlStateNormal];
    [self.view addSubview:self.backButton];
    [self.backButton bk_addEventHandler:^(id sender) {
        [self.sideViewControllerDelegate showLeftViewController];
    } forControlEvents:UIControlEventTouchUpInside];
    
    self.flashButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.flashButton.frame = CGRectMake(kScreenWidth / 3.0 - 20, 0.0, 40.0, 40.0);
    [self.flashButton setTitle:@"X" forState:UIControlStateNormal];
    [self.view addSubview:self.flashButton];
    
    self.timerButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.timerButton.frame = CGRectMake( 2 * kScreenWidth / 3.0 - 20, 0.0, 40.0, 40.0);
    [self.timerButton setTitle:@"O" forState:UIControlStateNormal];
    [self.view addSubview:self.timerButton];
    
    self.switchButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.switchButton.frame = CGRectMake(kScreenWidth - 40, 0.0, 40.0, 40.0);
    [self.view addSubview:self.switchButton];
    [self.switchButton setTitle:@"S" forState:UIControlStateNormal];
    
    //bottom
    self.resetScopeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.resetScopeButton.frame = CGRectMake(20, kScreenHeight - 40.0, 40.0, 40.0);
    [self.resetScopeButton setTitle:@"R" forState:UIControlStateNormal];
    [self.view addSubview:self.resetScopeButton];
    
    self.undoScopeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.undoScopeButton.frame = CGRectMake(kScreenWidth / 5, kScreenHeight - 40.0, 40.0, 40.0);
    [self.undoScopeButton setTitle:@"U" forState:UIControlStateNormal];
    [self.view addSubview:self.undoScopeButton];
    
    self.startButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.startButton.frame = CGRectMake(kScreenWidth / 2 - 30, kScreenHeight - 60.0, 60.0, 60.0);
    [self.startButton setTitle:@"()" forState:UIControlStateNormal];
    [self.view addSubview:self.startButton];
    
    self.undoPhotoButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.undoPhotoButton.frame = CGRectMake(kScreenWidth * 4 / 5.0 - 40, kScreenHeight - 40.0, 40.0, 40.0);
    [self.undoPhotoButton setTitle:@"U`" forState:UIControlStateNormal];
    [self.view addSubview:self.undoPhotoButton];
    
    self.undoScopeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.undoScopeButton.frame = CGRectMake(kScreenWidth - 60, kScreenHeight - 40.0, 40.0, 40.0);
    [self.undoScopeButton setTitle:@"R`" forState:UIControlStateNormal];
    [self.view addSubview:self.undoScopeButton];
}

#pragma mark - Actions


@end
