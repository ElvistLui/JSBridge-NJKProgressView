//
//  ViewController.m
//  JSBridge-NJKProgressViewDemo
//
//  Created by Elvist on 16/9/13.
//  Copyright © 2016年 Elvist. All rights reserved.
//

#import "ViewController.h"
#import "NJKWebViewProgress.h"
#import "NJKWebViewProgressView.h"
#import "WebViewJavascriptBridge.h"

@interface ViewController ()<UIWebViewDelegate, NJKWebViewProgressDelegate>

@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) WebViewJavascriptBridge *bridge;

@end

@implementation ViewController
{
    NJKWebViewProgressView *_progressView;
    NJKWebViewProgress *_progress;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self initView];
}
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.navigationController.navigationBar addSubview:_progressView];
}
- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [_progressView removeFromSuperview];
}

#pragma mark - 初始化视图
- (void)initView
{
    self.navigationController.navigationBar.translucent = NO;
    self.view.backgroundColor = [UIColor whiteColor];
    
    // 初始化视图
    self.webView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height - 64)];
    [self.view addSubview:self.webView];
    self.webView.scalesPageToFit = YES;
    
    // 进度条
    _progress = [[NJKWebViewProgress alloc] init];
    self.webView.delegate = _progress;
    _progress.webViewProxyDelegate = self;
    _progress.progressDelegate = self;
    
    CGRect navBounds = self.navigationController.navigationBar.bounds;
    CGRect barFrame = CGRectMake(0,
                                 navBounds.size.height - 2,
                                 navBounds.size.width,
                                 2);
    _progressView = [[NJKWebViewProgressView alloc] initWithFrame:barFrame];
    _progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [_progressView setProgress:0 animated:YES];
    
    //
    [WebViewJavascriptBridge enableLogging];
    
    _bridge = [WebViewJavascriptBridge bridgeUserNJKForWebView:self.webView handlerName:@"testObjcCallback" handler:^(id data, WVJBResponseCallback responseCallback) {
        
#warning block里必须使用weakSelf，否则会造成循环引用
        NSLog(@"ObjC received message from JS: %@", data);
    }];
    
    //  这里一定要将这个代理设置为_bridge对象
    _progress.webBridgeDelegate = _bridge;
    
    [self loadRequest];
}

// 加载地址
- (void)loadRequest
{
    NSString *urlString = @"https://www.baidu.com";
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
    [self.webView loadRequest:request];
}

#pragma mark - NJKWebViewProgressDelegate
-(void)webViewProgress:(NJKWebViewProgress *)webViewProgress updateProgress:(float)progress
{
    [_progressView setProgress:progress animated:YES];
}

#pragma mark -
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
