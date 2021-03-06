//
//  NetworkDaoTestVC.m
//  HAccess
//
//  Created by zhangchutian on 15/7/3.
//  Copyright (c) 2015年 zhangchutian. All rights reserved.
//

#import "NetworkDaoTestVC.h"
#import <HTextInput/HTextField.h>
#import <HTextInput/HTextView.h>
#import <HTextInput/HTextInputMotherBoard.h>
#import <HTextInput/HTextAnimationBottom.h>
#import <HTextInput/HTextAnimationPosition.h>
#import <HCommon.h>

#import "TestNetworkDAO.h"

@interface NetworkDaoTestVC ()
@property (nonatomic) UIView *textBack;
@property (nonatomic) HTextField *textView;
@end

@implementation NetworkDaoTestVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.view.backgroundColor = [UIColor whiteColor];
        self.title = @"HNetworkDAO TEST";
        
        [self addMenu:@"Download File" callback:^(id sender, id data) {
            HNetworkDAO *dao = [HNetworkDAO new];
            dao.baseURL = @"http://7xon1u.com1.z0.glb.clouddn.com/IMG_4842.JPG";
            dao.isFileDownload = YES;
            [dao startWithQueueName:nil sucess:^(id sender, id data) { //4
                NSLog(@"resp: %@\n%@", NSStringFromClass([data class]), [data jsonString]);
            } failure:^(id sender, NSError *error) {
                NSLog(@"error: %@", error);
            }];
        }];
        
        [self addMenu:@"Simple Request" callback:^(id sender, id data) {
            
            SimpleNetDAO *dao = [SimpleNetDAO new];
            dao.mobile = @"18628140435";
            [dao startWithQueueName:nil finish:^(SimpleNetDAO *sender, id data, NSError *error) {
                if (error)
                {
                    NSString *orgStr = [[NSString alloc] initWithData:sender.responseData encoding:NSUTF8StringEncoding];
                    NSLog(@"error: %@\n orignal: %@", error, orgStr);
                }
                else NSLog(@"resp: %@\n%@", NSStringFromClass([data class]), [data jsonString]);
            }];
            
            
            
        }];
        
        [self addMenu:@"Resp is Array" callback:^(id sender, id data) {
            StockNetDAO *dao = [StockNetDAO new];
            dao.date = @"2016-01-25";
            [dao startWithQueueName:nil finish:^(SimpleNetDAO *sender, id data, NSError *error) {
                if (error)
                {
                    NSString *orgStr = [[NSString alloc] initWithData:sender.responseData encoding:NSUTF8StringEncoding];
                    NSLog(@"error: %@\n orignal:%@", error, orgStr);
                }
                else NSLog(@"resp: %@\n%@", NSStringFromClass([data class]), [data jsonString]);
            }];
        }];
        
        [self addMenu:@"manual deserializtion" callback:^(id sender, id data) {
            StockNetDAO *dao = [StockNetDAO2 new];
            dao.date = @"2016-01-25";
            [dao startWithQueueName:nil finish:^(SimpleNetDAO *sender, id data, NSError *error) {
                if (error)
                {
                    NSString *orgStr = [[NSString alloc] initWithData:sender.responseData encoding:NSUTF8StringEncoding];
                    NSLog(@"error: %@\n orignal:%@", error, orgStr);
                }
                else NSLog(@"resp: %@\n%@", NSStringFromClass([data class]), [data jsonString]);
            }];
        }];
        
    }
    return self;
}

- (void)viewDidLoad
{
    UIImageView *bg = [[UIImageView alloc] initWithImage:img(@"bg.jpg")];
    bg.frame = self.view.bounds;
    ALWAYS_FULL(bg);
    bg.contentMode = UIViewContentModeScaleAspectFit;
    [self.view addSubview:bg];
    
    [super viewDidLoad];
    self.tableView.backgroundColor = [UIColor clearColor];

    
    self.automaticallyAdjustsScrollViewInsets = NO;
    [self.view addSubview:self.textBack];
    
    
    
}
- (UIView *)textBack
{
    if (!_textBack)
    {
        UIView *back = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.height - 60, self.view.width, 60)];
        back.backgroundColor = [UIColor colorWithHex:0xf5f5f5];
        back.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        if (!_textView)
        {
            HTextField *textView = [[HTextField alloc] initWithFrame:CGRectMake(10, (back.height - 44)/2, back.width - 20 - 60 - 5, 44)];
            textView.placeholder = @"say something";
            textView.font = [UIFont systemFontOfSize:24];
            textView.layer.cornerRadius = 4;
            textView.backgroundColor = [UIColor whiteColor];
            textView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            [back addSubview:textView];
            HTextAnimationBottom *animation1 = [HTextAnimationBottom new];
            animation1.animationView = self.tableView;
            animation1.inputView = textView;
            __weak typeof(back) weakBack = back;
            [animation1 setAdjustDistanceCallback: ^float(float distance){
                return distance + weakBack.height;
            }];
            HTextAnimationPosition *animation2 = [HTextAnimationPosition new];
            animation2.animationView = back;
            animation2.inputView = textView;
            textView.animations = @[animation1, animation2];
            _textView = textView;
        }


        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.layer.cornerRadius = 5;
        btn.backgroundColor = [UIColor colorWithHex:0x0066cc];
        btn.frame = CGRectMake(back.width - 60 - 10, (back.height - 44)/2, 60, 44);
        [btn setTintColor:[UIColor darkGrayColor]];
        [btn setTitle:@"send" forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        [back addSubview:btn];
        btn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [btn addTarget:self action:@selector(send) forControlEvents:UIControlEventTouchUpInside];
        _textBack = back;
    }
    return _textBack;
}
- (void)send
{
    UITextField *textView = self.textView;
    NSString *msg = [textView text];
    if (msg.length > 0)
    {
        [self sendMsg:msg textView:textView];
    }
}
- (void)sendMsg:(NSString *)msg textView:(UITextField *)textView
{
    DemoNetworkDAO *dao = [DemoNetworkDAO new];
    dao.appkey = @"db5c321697d0fd38ce68988d5a28f97e";
    dao.info = msg;

    @weakify(self)
    [dao startWithQueueName:nil sucess:^(id sender, DemoEntity *data) {
        @strongify(self)
        UIToolbar *toolBar = [[UIToolbar alloc] initWithFrame:self.view.bounds];
        HTextView *textView = [[HTextView alloc] initWithFrame:CGRectMake(0, 0, self.view.width, self.view.height)];
        textView.backgroundColor = [UIColor clearColor];
        textView.font = [UIFont systemFontOfSize:16];
        textView.textColor = [UIColor blackColor];
        textView.text = data.text;
        textView.contentInset = UIEdgeInsetsMake(20 + 64, 20, 20, 20);
        [toolBar addSubview:textView];
        
        toolBar.alpha = 0;
        [self.view insertSubview:toolBar belowSubview:self.textBack];
        [UIView animateWithDuration:0.2 animations:^{
            toolBar.alpha = 1;
        }];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.2 animations:^{
                toolBar.alpha = 0;
            } completion:^(BOOL finished) {
                [toolBar removeFromSuperview];
            }];
        });
        
    } failure:^(id sender, NSError *error) {
        
        NSLog(@"error:%@", [error localizedDescription]);
        
    }];
}

@end



@implementation DemoNetworkDAO

ppx(appkey, HPMapto(@"key"))

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.baseURL = @"http://www.tuling123.com";
        self.pathURL = @"openapi/api";
//#ifdef DEBUG
//        self.isMock = YES;
//#endif
        self.deserializer = [HNEntityDeserializer deserializerWithClass:[DemoEntity class]];
    }
    return self;
}
@end


@implementation DemoEntity
ppx(otherInfo, HPIgnore)
@end