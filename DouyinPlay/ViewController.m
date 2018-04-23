//
//  ViewController.m
//  DouyinPlay
//
//  Created by cyan on 2018/4/16.
//  Copyright © 2018年 cyan. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/ALAsset.h>
#import <AssetsLibrary/ALAssetsLibrary.h>
#import <AssetsLibrary/ALAssetsGroup.h>
#import <AssetsLibrary/ALAssetRepresentation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "CYVideoView.h"

#define SCREEN_WIDTH [UIScreen mainScreen].bounds.size.width
#define SCREEN_HEIGHT [UIScreen mainScreen].bounds.size.height
#define degreesToRadians( degrees ) ( ( degrees ) / 180.0 * M_PI )

@interface ViewController (){
//     CMTime *myS;
}

@property(nonatomic,strong)CYVideoView *videoView;
@property(nonatomic,strong)AVMutableVideoComposition *videoComposition;
@property(nonatomic,strong)AVMutableComposition *composition;
@property(nonatomic,strong)AVAssetExportSession *exportSession;
@property(nonatomic,strong)NSURL *videoUrl;
@property CALayer *watermarkLayer;
@property(nonatomic,assign)BOOL isAddWaterMark;
@property(nonatomic,assign)BOOL isRotate;

@end

@implementation ViewController

-(void)loadView{
    
    _videoView = [[CYVideoView alloc]initWithFrame:[UIScreen mainScreen].bounds];
    _videoView.backgroundColor = [UIColor whiteColor];
    self.view = _videoView;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"%@",NSHomeDirectory());
    [self initConfiguration];

}

-(NSURL *)videoUrl{
    if (!_videoUrl) {
        _videoUrl = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"Movie.m4v" ofType:nil]];
    }
    return _videoUrl;
}


-(void)initConfiguration{
    //获取一下视频的时间长度
    AVAsset *asset = [AVAsset assetWithURL:self.videoUrl];
    
     _videoView.allTime =  asset.duration;
     _videoView.newStartTime = kCMTimeZero;
     _videoView.newEndTime = _videoView.allTime;
    //初始化播放器
    [_videoView initPlayerWithVideoUrl:self.videoUrl];
    [_videoView.saveBtn addTarget:self action:@selector(saveVideo) forControlEvents:UIControlEventTouchUpInside];
    [_videoView.watermarkBtn addTarget:self action:@selector(addWaterMarkAction:) forControlEvents:UIControlEventTouchUpInside];
    [_videoView.rotateBtn addTarget:self action:@selector(rotateAction:) forControlEvents:UIControlEventTouchUpInside];
}

#pragma mark - 添加水印
-(void)addWaterMarkAction:(UIButton *)btn{
    NSLog(@"添加水印");
    self.isAddWaterMark = YES;
    //只能选择一次
    btn.hidden = YES;
    [self videoEdit];
    [self reloadPlayer];
}

#pragma mark - 旋转视频
-(void)rotateAction:(UIButton *)btn{
    NSLog(@"旋转视频");
    self.isRotate = YES;
    [self videoEdit];
    [self reloadPlayer];

}

/**
 刷新播放器，旋转添加水印操作之后
 */
-(void)reloadPlayer{
    //必须清空水印设置才可以生成playerItem
    self.videoComposition.animationTool = NULL;
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:self.composition];
    playerItem.videoComposition = self.videoComposition;
    
    if(self.isAddWaterMark) {
        CGSize layerBgViewSize =  self.videoView.videoShowView.layer.bounds.size;
        CALayer *layer = [self watermarkLayerForSize:layerBgViewSize];
        layer.position = CGPointMake(layerBgViewSize.width/2, layerBgViewSize.height/4);
        [self.videoView.videoShowView.layer addSublayer:layer];
    }
    [self.videoView.player replaceCurrentItemWithPlayerItem:playerItem];

}

#pragma mark - 视频编辑
-(void)videoEdit{
    //1,将素材拖入到素材库
    AVAsset *asset = [AVAsset assetWithURL:self.videoUrl];
    //素材的视频轨
    AVAssetTrack *videoAssetTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    //素材的音频轨
    AVAssetTrack *audioAssetTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
    
    // Trim to half duration
//    double halfDuration = CMTimeGetSeconds([asset duration]) - 5;
    CMTime trimmedDuration = CMTimeSubtract(_videoView.newEndTime, _videoView.newStartTime);
    CMTimeShow(trimmedDuration);

    //2，将素材的视频插入视频轨，音频插入音频轨
    //这是工程文件
    self.composition  = [AVMutableComposition composition];
    //视频轨道
    AVMutableCompositionTrack *videoCompositionTrack = [self.composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    //在视频轨道插入一个时间段的视频
    [videoCompositionTrack insertTimeRange:CMTimeRangeMake(_videoView.newStartTime, trimmedDuration) ofTrack:videoAssetTrack atTime:kCMTimeZero error:nil];
    //音频轨道
    AVMutableCompositionTrack *audioCompositionTrack = [self.composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    //插入音频数据，否则没声音
    [audioCompositionTrack insertTimeRange:CMTimeRangeMake(_videoView.newStartTime,trimmedDuration) ofTrack:audioAssetTrack atTime:kCMTimeZero error:nil];
    //可以添加其他音视频
//    [videoCompositionTrack insertTimeRange:CMTimeRangeMake(_newStartTime, trimmedDuration) ofTrack:videoAssetTrack atTime:kCMTimeZero error:nil];
    
//    //3，裁剪视频
    //AVMutableVideoComposition：管理所有视频轨道，可以决定最终视频的尺寸，裁剪需要在这里进行
    self.videoComposition = [AVMutableVideoComposition videoComposition];
    self.videoComposition.frameDuration = CMTimeMake(1, 30);
    self.videoComposition.renderSize = videoAssetTrack.naturalSize;
    
//    AVMutableVideoCompositionInstruction 视频轨道中的一个视频，可以缩放、旋转等
    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    instruction.timeRange = CMTimeRangeMake(kCMTimeZero, trimmedDuration);
    // 3.2 AVMutableVideoCompositionLayerInstruction 一个视频轨道，包含了这个轨道上的所有视频素材
    AVAssetTrack *videoTrack = [self.composition tracksWithMediaType:AVMediaTypeVideo][0];
    AVMutableVideoCompositionLayerInstruction *layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
    //视频旋转处理
    if (self.isRotate) {
        CGAffineTransform t1 = CGAffineTransformMakeTranslation(videoCompositionTrack.naturalSize.height, 0.0);
        // Rotate transformation
        CGAffineTransform  t2 = CGAffineTransformRotate(t1, degreesToRadians(90.0));
        [layerInstruction setTransform:t2 atTime:kCMTimeZero];
        self.videoComposition.renderSize = CGSizeMake(videoAssetTrack.naturalSize.height,  videoAssetTrack.naturalSize.width);
    }
    
    // 3.3 - Add instructions
    instruction.layerInstructions = [NSArray arrayWithObjects:layerInstruction,nil];
    self.videoComposition.instructions = [NSArray arrayWithObject:instruction];
    
    //添加水印 重新刷新player的时候会重置 所以在导出水印的时候添加水印

}
#pragma mark - 更新保存进度条
-(void)updateExportProgress:(NSTimer *)timer{
//    NSLog(@"progress : %f",self.exportSession.progress);
    self.videoView.exportProgressView.progress = self.exportSession.progress;
    if (self.exportSession.progress == 1) {
        self.videoView.exportProgressView.progress = 0;
        [timer invalidate];
    }
}
//保存编辑后的视频
-(void)saveVideo{
    [NSTimer scheduledTimerWithTimeInterval:0.05
                                     target:self
                                   selector:@selector(updateExportProgress:)
                                   userInfo:nil
                                    repeats:YES];
    
    [self videoEdit];

    //需要从新编辑一下 reloadPlayer 会清空水印设置
    //添加水印
    if (self.isAddWaterMark) {
        CGSize videoSize = self.videoComposition.renderSize;
        self.watermarkLayer = [self watermarkLayerForSize:videoSize];
        CALayer *exportWatermarkLayer = [self copyWatermarkLayer:self.watermarkLayer];
        CALayer *parentLayer = [CALayer layer];
        CALayer *videoLayer = [CALayer layer];
        parentLayer.frame = CGRectMake(0, 0, self.videoComposition.renderSize.width, self.videoComposition.renderSize.height);
        videoLayer.frame = CGRectMake(0, 0, self.videoComposition.renderSize.width, self.videoComposition.renderSize.height);
        [parentLayer addSublayer:videoLayer];
        exportWatermarkLayer.position = CGPointMake(self.videoComposition.renderSize.width/2, self.videoComposition.renderSize.height/4);
        [parentLayer addSublayer:exportWatermarkLayer];
        
        CABasicAnimation *anima = [CABasicAnimation animationWithKeyPath:@"opacity"];
        anima.fromValue = [NSNumber numberWithFloat:1.0f];
        anima.toValue = [NSNumber numberWithFloat:0.0f];
        anima.repeatCount = 0;
        anima.duration = 5.0f;  //5s之后消失
        [anima setRemovedOnCompletion:NO];
        [anima setFillMode:kCAFillModeForwards];
        anima.beginTime = AVCoreAnimationBeginTimeAtZero;
        [exportWatermarkLayer addAnimation:anima forKey:@"opacityAniamtion"];
        
        self.videoComposition.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
    }
    //4,导出
    //保存至沙盒路径
    [self creatSandBoxFilePathIfNoExist];
    //保存至沙盒路径
    NSString *pathDocuments = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *videoPath = [NSString stringWithFormat:@"%@/Video", pathDocuments];
    NSString *urlPath = [videoPath stringByAppendingPathComponent:@"cyan.mp4"];
    //先移除
    NSFileManager *manager = [NSFileManager defaultManager];
    [manager removeItemAtPath:urlPath error:nil];
    
    //    AVAssetExportPresetPassthrough AVAssetExportPresetHighestQuality
   self.exportSession = [[AVAssetExportSession alloc] initWithAsset:self.composition presetName:AVAssetExportPresetHighestQuality];
    
    self.exportSession.videoComposition = self.videoComposition;
    self.exportSession.outputURL = [NSURL fileURLWithPath:urlPath];
    self.exportSession.outputFileType = AVFileTypeMPEG4;
    //    exporter.shouldOptimizeForNetworkUse = YES;
    
    [self.exportSession exportAsynchronouslyWithCompletionHandler:^{
        int exportStatus = self.exportSession.status;
        NSLog(@"exportStatus ： %d",exportStatus);
        switch (exportStatus)
        {
            case AVAssetExportSessionStatusFailed:
            {
                // log error to text view
                NSError *exportError = self.exportSession.error;
                NSLog (@"AVAssetExportSessionStatusFailed: %@", exportError);
                break;
            }
            case AVAssetExportSessionStatusCompleted:
            {
                //保存到相册
                [self writeVideoToPhotoLibrary:[NSURL fileURLWithPath:urlPath]];
                
                NSLog(@"视频转码成功");
                
            }
        }
    }];
    
}

- (CALayer*)copyWatermarkLayer:(CALayer*)inputLayer
{
    CALayer *exportWatermarkLayer = [CALayer layer];
    CATextLayer *titleLayer = [CATextLayer layer];
    CATextLayer *inputTextLayer = (CATextLayer *)[inputLayer sublayers][0];
    titleLayer.string = inputTextLayer.string;
    titleLayer.foregroundColor = inputTextLayer.foregroundColor;
    titleLayer.font = inputTextLayer.font;
    titleLayer.shadowOpacity = inputTextLayer.shadowOpacity;
    titleLayer.alignmentMode = inputTextLayer.alignmentMode;
    titleLayer.bounds = inputTextLayer.bounds;
    
    [exportWatermarkLayer addSublayer:titleLayer];
    return exportWatermarkLayer;
}

- (CALayer*)watermarkLayerForSize:(CGSize)videoSize
{
    // Create a layer for the title
    CALayer *_watermarkLayer = [CALayer layer];
    
    // Create a layer for the text of the title.
    CATextLayer *titleLayer = [CATextLayer layer];
    titleLayer.string = @"cyan";
    titleLayer.foregroundColor = [[UIColor whiteColor] CGColor];
    titleLayer.shadowOpacity = 0.5;
    titleLayer.alignmentMode = kCAAlignmentCenter;
    titleLayer.bounds = CGRectMake(0, 0, videoSize.width/2, videoSize.height/2);
    
    // Add it to the overall layer.
    [_watermarkLayer addSublayer:titleLayer];
    
    return _watermarkLayer;
}
- (void)writeVideoToPhotoLibrary:(NSURL *)url
{
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    
    [library writeVideoAtPathToSavedPhotosAlbum:url completionBlock:^(NSURL *assetURL, NSError *error){
        if (error) {
            NSLog(@"Video could not be saved");
        }
    }];
}



- (void)creatSandBoxFilePathIfNoExist
{
    //沙盒路径
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [paths objectAtIndex:0];
    NSLog(@"databse--->%@",documentDirectory);
    
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSString *pathDocuments = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    //创建目录
    NSString *createPath = [NSString stringWithFormat:@"%@/Video", pathDocuments];
    // 判断文件夹是否存在，如果不存在，则创建
    if (![[NSFileManager defaultManager] fileExistsAtPath:createPath]) {
        [fileManager createDirectoryAtPath:createPath withIntermediateDirectories:YES attributes:nil error:nil];
    } else {
        NSLog(@"FileImage is exists.");
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
