//
//  CYVideoView.h
//  DouyinPlay
//
//  Created by cyan on 2018/4/17.
//  Copyright © 2018年 cyan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface CYVideoView : UIView
@property(nonatomic,strong)UIView *videoShowView;
@property(nonatomic,strong)UIView *bottomView;
@property(nonatomic,strong)UIView *showImageViewBgView;
@property(nonatomic,strong)UIProgressView *exportProgressView;
@property(nonatomic,strong)UIView *leftView;
@property(nonatomic,strong)UIView *rightView;
@property(nonatomic,strong)UIView *leftShadowView;
@property(nonatomic,strong)UIView *rightShadowView;

@property(nonatomic,strong)UIButton *playBtn;
@property(nonatomic,strong)UIButton *rotateBtn;
@property(nonatomic,strong)UIButton *watermarkBtn;
@property(nonatomic,strong)UIButton *saveBtn;

@property (nonatomic, strong)AVPlayerItem      *playItem;
@property (nonatomic, strong)AVPlayerLayer     *playerLayer;
@property (nonatomic, strong)AVPlayer          *player;

/**视频总时间*/
@property (nonatomic, assign)CMTime allTime;
/**视频开始时间*/
@property (nonatomic, assign)CMTime newStartTime;
/**视频结束时间*/
@property (nonatomic, assign)CMTime newEndTime;

- (void)initPlayerWithVideoUrl:(NSURL *)videlUrl;

@end
