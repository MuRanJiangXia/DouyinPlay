//
//  CYVideoView.m
//  DouyinPlay
//
//  Created by cyan on 2018/4/17.
//  Copyright © 2018年 cyan. All rights reserved.
//

#import "CYVideoView.h"
#define SCREEN_WIDTH [UIScreen mainScreen].bounds.size.width
#define SCREEN_HEIGHT [UIScreen mainScreen].bounds.size.height

@interface CYVideoView()
@property(nonatomic,strong)NSURL *videoUrl;
@property(nonatomic,assign)BOOL isLeftCanMove;
@property(nonatomic,assign)BOOL isRightCanMove;
@property (nonatomic, strong) NSMutableArray    *framesArray; // 视频帧数组


@end
@implementation CYVideoView

- (void)dealloc
{
    NSLog(@"销毁了");
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}

-(instancetype)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        [self creatUI];
    }
    
    return self;
}


-(void)creatUI{
//    {640, 360}
    _videoShowView = [[UIView alloc]initWithFrame:CGRectMake((SCREEN_WIDTH - 300)/2.0, 40, 300, 9/16.0 * 300)];
    _videoShowView.backgroundColor = [UIColor yellowColor];
    [self addSubview:_videoShowView];
    
    _exportProgressView = [[UIProgressView alloc]initWithFrame:CGRectMake((SCREEN_WIDTH - 100)/2.0, CGRectGetMaxY(_videoShowView.frame) + 10, 100, 10)];
    [self addSubview:_exportProgressView];
    
    _bottomView = [[UIView alloc]initWithFrame:CGRectMake(0, CGRectGetMaxY(_exportProgressView.frame)+40, SCREEN_WIDTH, 40)];
    _bottomView.backgroundColor = [UIColor yellowColor];
    [self addSubview:_bottomView];
    
    _showImageViewBgView = [[UIView alloc]initWithFrame:_bottomView.bounds];
    _showImageViewBgView.backgroundColor = [UIColor grayColor];
    [_bottomView addSubview:_showImageViewBgView];
    

    
    _leftView= [[UIView alloc]initWithFrame:CGRectMake(0, 0, 20, 40)];
    _leftView.backgroundColor = [UIColor greenColor];
    [_bottomView addSubview:_leftView];
    
    _rightView = [[UIView alloc]initWithFrame:CGRectMake(CGRectGetMaxX(_bottomView.frame) - 20, 0, 20, 40)];
    _rightView.backgroundColor = [UIColor redColor];
    [_bottomView addSubview:_rightView];

    _leftShadowView = [[UIView alloc]initWithFrame:CGRectZero];
    _leftShadowView.backgroundColor = [UIColor groupTableViewBackgroundColor];
    _leftShadowView.alpha = 0.5;
    [self.bottomView addSubview:_leftShadowView];
    
    _rightShadowView = [[UIView alloc]initWithFrame:CGRectZero];
    _rightShadowView.backgroundColor = [UIColor groupTableViewBackgroundColor];
    _rightShadowView.alpha = 0.5;
    [self.bottomView addSubview:_rightShadowView];
    
    _playBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _playBtn.frame = CGRectMake((SCREEN_WIDTH - 100)/2.0, CGRectGetMaxY(_bottomView.frame) + 20, 100, 40);
    _playBtn.backgroundColor = [UIColor greenColor];
    [_playBtn setTitle:@"播放" forState:UIControlStateNormal];
    [_playBtn setTitle:@"暂停" forState:UIControlStateSelected];
    [_playBtn addTarget:self action:@selector(playAction:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_playBtn];
    
    _rotateBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _rotateBtn.frame = CGRectMake((SCREEN_WIDTH - 220)/2.0, CGRectGetMaxY(_playBtn.frame) + 20, 100, 40);
    [_rotateBtn setTitle:@"旋转" forState:UIControlStateNormal];
    _rotateBtn.backgroundColor = [UIColor purpleColor];
    [self addSubview:_rotateBtn];

    _watermarkBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _watermarkBtn.frame = CGRectMake(CGRectGetMaxX(_rotateBtn.frame) + 20 , CGRectGetMaxY(_playBtn.frame) + 20, 100, 40);;
    [_watermarkBtn setTitle:@"水印" forState:UIControlStateNormal];
    _watermarkBtn.backgroundColor = [UIColor purpleColor];
    [self addSubview:_watermarkBtn];


    //旋转，加水印，
    _saveBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _saveBtn.frame = CGRectMake((SCREEN_WIDTH - 100)/2.0, CGRectGetMaxY(_rotateBtn.frame) + 20, 100, 40);
    _saveBtn.backgroundColor = [UIColor purpleColor];
    [_saveBtn setTitle:@"保存视频" forState:UIControlStateNormal];

    [self addSubview:_saveBtn];
    
    
    //添加滑动手势
    UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveOverlayView:)];
    [self.bottomView addGestureRecognizer:panGestureRecognizer];
    
}


#pragma mark - 初始化player
- (void)initPlayerWithVideoUrl:(NSURL *)videlUrl{
    self.videoUrl = videlUrl;
    self.playItem = [[AVPlayerItem alloc] initWithURL:videlUrl];
    
    self.player = [AVPlayer playerWithPlayerItem:self.playItem];
    
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    self.playerLayer.contentsScale = [UIScreen mainScreen].scale;
    self.playerLayer.frame = self.videoShowView.bounds;
    [self.videoShowView.layer addSublayer:self.playerLayer];
    
    __weak typeof(self)weakSelf = self;
    //把时间间隔设置为， 1/ 30 秒，然后 block 里面更新 UI。就是一秒钟更新 30次UI
    //playe播放的时候会一直调用
    [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 30.0) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        [weakSelf reloadPlayStatusByTime:time];
    }];
    //显示每帧图片
    [self analysisVideoFrames];
}


#pragma mark - 读取解析视频帧图片
-(void)analysisVideoFrames{
    AVURLAsset *videoAsset = [[AVURLAsset alloc]initWithURL:self.videoUrl options:nil];
    //获取视频总长度 = 总帧数 / 每秒的帧数
    long videoSumTime = videoAsset.duration.value / videoAsset.duration.timescale;
    //创建AVAssetImageGenerator对象
    AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc]initWithAsset:videoAsset];
    generator.maximumSize = self.bottomView.frame.size;
    generator.appliesPreferredTrackTransform = YES;
    generator.requestedTimeToleranceBefore = kCMTimeZero;
    generator.requestedTimeToleranceAfter = kCMTimeZero;
    
    //添加需要帧数的时间集合
    self.framesArray = [NSMutableArray array];
    for (NSInteger index = 0; index < videoSumTime; index ++) {
        CMTime time = CMTimeMake(index * videoAsset.duration.timescale, videoAsset.duration.timescale);
        NSValue *value = [NSValue valueWithCMTime:time];
        [self.framesArray addObject:value];
    }
    
    
    __block long count = 0 ;
    __weak typeof(self)weakSelf = self;
    __block UIImage *showImage = [[UIImage alloc] init];
    __block CGFloat showImageViewWitd = (self.bottomView.frame.size.width - self.leftView.frame.size.width * 2)/videoSumTime;
    [generator generateCGImagesAsynchronouslyForTimes:self.framesArray completionHandler:^(CMTime requestedTime, CGImageRef  _Nullable image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError * _Nullable error) {
        if (result == AVAssetImageGeneratorSucceeded) {
            showImage = [UIImage imageWithCGImage:image];
            dispatch_async(dispatch_get_main_queue(), ^{
                UIImageView *thumImgView = [[UIImageView alloc]initWithFrame:CGRectMake( 20 +  count * showImageViewWitd , 0, showImageViewWitd, 40)];
                thumImgView.image = showImage;
                [weakSelf.showImageViewBgView addSubview:thumImgView];
                count++;
            }) ;
        }
        if (result == AVAssetImageGeneratorFailed) {
            NSLog(@"Failed with error: %@", [error localizedDescription]);
        }
        
        if (result == AVAssetImageGeneratorCancelled) {
            NSLog(@"AVAssetImageGeneratorCancelled");
        }
    }];
    
}


#pragma mark - 播放按钮
-(void)playAction:(UIButton *)btn{
    btn.selected = !btn.selected;
    if (btn.selected) {
        [self.player seekToTime:self.newStartTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
        
        [self.player play];
        
    }else{
        [self.player pause];
    }
    
}

/**
 根据当前播放时间和newEndTime比较，超过的时候暂停

 @param time 当前播放时间
 */
-(void)reloadPlayStatusByTime:(CMTime )time{
    if (CMTimeGetSeconds(time) >= CMTimeGetSeconds(self.newEndTime)) {
        [self.player pause];
        self.playBtn.selected = NO;
    }
    
}


#pragma mark - 移动手势
-(void)moveOverlayView:(UIPanGestureRecognizer *)pan{
    
    CGPoint point = [pan locationInView:self.bottomView];
    switch (pan.state) {
        case UIGestureRecognizerStateBegan:
        {//判断是在左右调控视图上么
            NSLog(@"开始平移了");
            if (CGRectContainsPoint(self.leftView.frame, point))  _isLeftCanMove = YES;
            else _isLeftCanMove = NO;
            
            if (CGRectContainsPoint(self.rightView.frame, point))  _isRightCanMove = YES;
            else _isRightCanMove = NO;
            
        }
            break;
        case UIGestureRecognizerStateChanged:
        {
            if (_isLeftCanMove) {
                //不能超过bottomview左边，不能超过rightviw左边
                if (point.x - 10 < 0 || point.x + 10 + 2 > CGRectGetMinX(self.rightView.frame) ) {
                    NSLog(@"超过范围了");
                    break;
                }
                self.leftView.center = CGPointMake(point.x, self.leftView.center.y);
                self.leftShadowView.frame = CGRectMake(0, 0, CGRectGetMinX(self.leftView.frame), self.bottomView.frame.size.height);
            }
            
            if (_isRightCanMove) {
                //不能超过bottomview右边，不能超过leftview右边
                if (point.x + 10 > CGRectGetMaxX(self.bottomView.frame) || point.x  - 10 - 2 < CGRectGetMaxX(self.leftView.frame) ) {
                    NSLog(@"超过范围了");
                    break;
                }
                self.rightView.center = CGPointMake(point.x, self.rightView.center.y);
                self.rightShadowView.frame = CGRectMake(CGRectGetMaxX(self.rightView.frame), 0, self.bottomView.frame.size.width - CGRectGetMaxX(self.rightView.frame) , self.bottomView.frame.size.height);
            }
            
        }
            break;
        case UIGestureRecognizerStateEnded:
        {
            //重新计算左右起始时间
            CGFloat time =  CMTimeGetSeconds(self.allTime);
            
            CGFloat startTime = CGRectGetMidX(self.leftView.frame) /self.bottomView.frame.size.width * time;
            _newStartTime = CMTimeMakeWithSeconds(startTime, 1 *NSEC_PER_SEC);
            
            CGFloat endTime = CGRectGetMaxX(self.rightView.frame) / self.bottomView.frame.size.width *time;
            _newEndTime = CMTimeMakeWithSeconds(endTime, 1 *NSEC_PER_SEC);
            
            CMTimeShow(_newStartTime);
            CMTimeShow(_newEndTime);
        }
            
        default:
            break;
    }
    
    
}

@end
