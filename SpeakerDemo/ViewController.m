//
//  ViewController.m
//  SpeakerDemo
//
//  Created by 赵赤赤 on 2017/2/23.
//  Copyright © 2017年 mhz. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

#define ScreenWidth self.view.frame.size.width
#define ScreenHeight self.view.frame.size.height

@interface ViewController ()

// 地面
@property (nonatomic, strong) UIView *groundView;
// 角色
@property (nonatomic, strong) UIImageView *roleView;

// 显示声音的label
@property (nonatomic, strong) UILabel *voiceLabel;

// 麦克风
@property (nonatomic, strong) AVAudioRecorder *recorder;

// 检测音量的定时器
@property (nonatomic, strong) NSTimer *levelTimer;

// 创建白色的沟
@property (nonatomic, strong) UIView *gapView;

// 角色是否在地面上
@property (nonatomic, assign) BOOL isGround;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 创建UI
    [self configUI];
    
    // 请求麦克风的使用
    [self askForRecorder];
}




# pragma mark - 创建UI
- (void)configUI {
    // 创建一个地面
    self.groundView = [[UIView alloc] initWithFrame:CGRectMake(0, ScreenHeight*0.6, ScreenWidth, ScreenHeight*0.4)];
    self.groundView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:self.groundView];
    
    
    
    // 创建沟
    self.gapView = [[UIView alloc] initWithFrame:CGRectMake(ScreenWidth-100, ScreenHeight*0.6, 100, ScreenHeight*0.4)];
    self.gapView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.gapView];
    
    
    
    
    // 防止label，显示分贝
    self.voiceLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100, 30)];
    self.voiceLabel.textColor = [UIColor redColor];
    [self.view addSubview:self.voiceLabel];
    
    
    
    // 放置一个角色在地面上
    self.roleView = [[UIImageView alloc] initWithFrame:CGRectMake(100, ScreenHeight*0.6-50, 50, 50)];
    self.roleView.image = [UIImage imageNamed:@"role.png"];
    [self.view addSubview:self.roleView];
    // 设置角色现在的状态为在地面上
    self.isGround = YES;
}




# pragma mark - 麦克风相关
- (void)askForRecorder {
    // 获取麦克风权限
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    
    /* 不需要保存录音文件 */
    NSURL *url = [NSURL fileURLWithPath:@"/dev/null"];
    NSDictionary *settings = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithFloat: 44100.0], AVSampleRateKey,
                              [NSNumber numberWithInt: kAudioFormatAppleLossless], AVFormatIDKey,
                              [NSNumber numberWithInt: 2], AVNumberOfChannelsKey,
                              [NSNumber numberWithInt: AVAudioQualityMax], AVEncoderAudioQualityKey,
                              nil];
    
    NSError *error;
    self.recorder = [[AVAudioRecorder alloc] initWithURL:url settings:settings error:&error];
    if (self.recorder) {
        [self.recorder prepareToRecord];
        self.recorder.meteringEnabled = YES;
        [self.recorder record];
        self.levelTimer = [NSTimer scheduledTimerWithTimeInterval:0.01 target: self selector: @selector(levelTimerCallback:) userInfo: nil repeats: YES];
    } else {
        NSLog(@"%@", [error description]);
    }
}

/* 该方法确实会随环境音量变化而变化，但具体分贝值是否准确暂时没有研究 */
- (void)levelTimerCallback:(NSTimer *)timer {
    [self.recorder updateMeters];
    
    float   level;                // The linear 0.0 .. 1.0 value we need.
    float   minDecibels = -80.0f; // Or use -60dB, which I measured in a silent room.
    float   decibels    = [self.recorder averagePowerForChannel:0];
    
    if (decibels < minDecibels)
    {
        level = 0.0f;
    }
    else if (decibels >= 0.0f)
    {
        level = 1.0f;
    }
    else
    {
        float   root            = 2.0f;
        float   minAmp          = powf(10.0f, 0.05f * minDecibels);
        float   inverseAmpRange = 1.0f / (1.0f - minAmp);
        float   amp             = powf(10.0f, 0.05f * decibels);
        float   adjAmp          = (amp - minAmp) * inverseAmpRange;
        
        level = powf(adjAmp, 1.0f / root);
    }
    
    /* level 范围[0 ~ 1], 转为[0 ~120] 之间 */
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.voiceLabel setText:[NSString stringWithFormat:@"%f", level*120]];
        
        // 如果大于30，则让角色可以移动
        if (level*120 > 30) {
            // 创建白色框进行移动
            CGRect gapFrame = self.gapView.frame;
            gapFrame.origin.x -= 2;
            self.gapView.frame = gapFrame;
        }
        
        // 判断落地地点是否在陷阱上
        if (self.isGround) {
            if ((self.roleView.frame.origin.x > self.gapView.frame.origin.x) && ((self.roleView.frame.origin.x + self.roleView.frame.size.width) < (self.gapView.frame.origin.x + self.gapView.frame.size.width))) {
                // 关闭定时器并落到消失无踪
                [self.levelTimer setFireDate:[NSDate distantFuture]];
                [UIView animateWithDuration:1 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
                    CGRect roleFram = self.roleView.frame;
                    roleFram.origin.y = ScreenHeight;
                    self.roleView.frame = roleFram;
                } completion:^(BOOL finished) {
                }];
            }
        }
        
        // 让角色可以跳动
        if (level*120 >= 70 && self.isGround) {
            self.isGround = NO;
            
            // 让角色进行跳动
            [UIView animateWithDuration:1 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
                CGRect roleFram = self.roleView.frame;
                roleFram.origin.y -= 100;
                self.roleView.frame = roleFram;
            } completion:^(BOOL finished) {
                [UIView animateWithDuration:1 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                    CGRect roleFram = self.roleView.frame;
                    roleFram.origin.y += 100;
                    self.roleView.frame = roleFram;
                } completion:^(BOOL finished) {
                    self.isGround = YES;
                    
                    // 判断落地地点是否在陷阱上
                    if ((self.roleView.frame.origin.x > self.gapView.frame.origin.x) && ((self.roleView.frame.origin.x + self.roleView.frame.size.width) < (self.gapView.frame.origin.x + self.gapView.frame.size.width))) {
                        // 关闭定时器并落到消失无踪
                        [self.levelTimer setFireDate:[NSDate distantFuture]];
                        [UIView animateWithDuration:1 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
                            CGRect roleFram = self.roleView.frame;
                            roleFram.origin.y = ScreenHeight;
                            self.roleView.frame = roleFram;
                        } completion:^(BOOL finished) {
                        }];
                    }
                }];
            }];
        }
        
        // 判断是否有陷阱，陷阱如果不在屏幕上，则重置他的宽度和位置
        if (self.gapView.frame.origin.x + self.gapView.frame.size.width < 0) {
            CGRect gapFrame = self.gapView.frame;
            gapFrame.origin.x = ScreenWidth;
            self.gapView.frame = gapFrame;
        }
    });
}


@end
