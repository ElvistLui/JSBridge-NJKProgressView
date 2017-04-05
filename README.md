[博客地址](http://www.jianshu.com/p/19449a11f5cd)
>造成这个冲突的原因是因为 webview的delegete 被置换了，delegate 在arc下都是week ，所以当你使用了[NJKWebViewProgress](https://github.com/ninjinkun/NJKWebViewProgress)指定了webdelegate，然后又指定 了[WebViewJavascriptBridge](https://github.com/marcuswestin/WebViewJavascriptBridge)的webdelegate ，所以两次交替，最终只会一个webdelegate存在。

这里给出解决冲突的[原文地址](http://www.cocoachina.com/bbs/read.php?tid=302587)，但是原文给出的方法在设置时不能设置handlerName，这样在特殊条件下无法获取前端发出的callHandler来进行判断

修改后的解决方法[Demo下载](https://github.com/ElvistLui/JSBridge-NJKProgressViewDemo)：
##### 1. 扩展 WebViewJavascriptBridge 的方法。

```
/** Andrew add method to compatible with NJK */
+ (instancetype)bridgeUserNJKForWebView:(WVJB_WEBVIEW_TYPE*)webView handlerName:(NSString*)handlerName handler:(WVJBHandler)messageHandler;
```
```
/** Andrew add method to compatible with NJK */
+ (instancetype)bridgeUserNJKForWebView:(WVJB_WEBVIEW_TYPE*)webView handlerName:(NSString*)handlerName handler:(WVJBHandler)messageHandler;
{
    WebViewJavascriptBridge *bridge = [[self alloc] init];
    [bridge _platformNJKSpecificSetup:webView handlerName:handlerName handler:messageHandler resourceBundle:nil];
    return bridge;
}
- (void) _platformNJKSpecificSetup:(WVJB_WEBVIEW_TYPE*)webView handlerName:(NSString*)handlerName handler:(WVJBHandler)messageHandler resourceBundle:(NSBundle*)bundle{

    _webView = webView;    
    _webViewDelegate = nil;
    _base = [[WebViewJavascriptBridgeBase alloc] init];
    _base.messageHandler = messageHandler;
    _base.messageHandlers[handlerName] = [messageHandler copy];
    _base.delegate = self;
}
```
#####  2. 扩展NJKWebViewProgress 属性
```
@property (nonatomic, njk_weak) id<UIWebViewDelegate>webBridgeDelegate;
```
##### 3. 修改NJKWebViewProgress 中的UIWebViewDelegate 方法。
```
//
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if ([request.URL.absoluteString isEqualToString:completeRPCURLPath]) {

        [self completeProgress];
        return NO;
    }
    
    BOOL ret = YES;
    if ([_webViewProxyDelegate respondsToSelector:@selector(webView:shouldStartLoadWithRequest:navigationType:)]) {

        ret = [_webViewProxyDelegate webView:webView shouldStartLoadWithRequest:request navigationType:navigationType];
    }
    if ([_webBridgeDelegate respondsToSelector:@selector(webView:shouldStartLoadWithRequest:navigationType:)]) {

        [_webBridgeDelegate webView:webView shouldStartLoadWithRequest:request navigationType:navigationType];
    }
    
    BOOL isFragmentJump = NO;
    if (request.URL.fragment) {

        NSString *nonFragmentURL = [request.URL.absoluteString stringByReplacingOccurrencesOfString:[@"#" stringByAppendingString:request.URL.fragment] withString:@""];
        isFragmentJump = [nonFragmentURL isEqualToString:webView.request.URL.absoluteString];
    }
    
    BOOL isTopLevelNavigation = [request.mainDocumentURL isEqual:request.URL];
    
    BOOL isHTTP = [request.URL.scheme isEqualToString:@"http"] || [request.URL.scheme isEqualToString:@"https"];
    if (ret && !isFragmentJump && isHTTP && isTopLevelNavigation) {

        _currentURL = request.URL;
        [self reset];
    }
    return ret;
}
//
- (void)webViewDidStartLoad:(UIWebView *)webView
{   
    if ([_webViewProxyDelegate respondsToSelector:@selector(webViewDidStartLoad:)]) {

        [_webViewProxyDelegate webViewDidStartLoad:webView];
    }
    if ([_webBridgeDelegate respondsToSelector:@selector(webViewDidStartLoad:)]) {

        [_webBridgeDelegate webViewDidStartLoad:webView];
    }
    
    _loadingCount++;
    _maxLoadCount = fmax(_maxLoadCount, _loadingCount);
    
    [self startProgress];
}
//
- (void)webViewDidFinishLoad:(UIWebView *)webView
{   
    if ([_webViewProxyDelegate respondsToSelector:@selector(webViewDidFinishLoad:)]) {

        [_webViewProxyDelegate webViewDidFinishLoad:webView];
    }
    if ([_webBridgeDelegate respondsToSelector:@selector(webViewDidFinishLoad:)]) {

        [_webBridgeDelegate webViewDidFinishLoad:webView];
    }
    _loadingCount--;
    [self incrementProgress];
    
    NSString *readyState = [webView stringByEvaluatingJavaScriptFromString:@"document.readyState"];
    
    BOOL interactive = [readyState isEqualToString:@"interactive"];
    if (interactive) {

        _interactive = YES;
        NSString *waitForCompleteJS = [NSString stringWithFormat:@"window.addEventListener('load',function() { var iframe = document.createElement('iframe'); iframe.style.display = 'none'; iframe.src = '%@'; document.body.appendChild(iframe);  }, false);", completeRPCURLPath];
        [webView stringByEvaluatingJavaScriptFromString:waitForCompleteJS];
    }
    
    BOOL isNotRedirect = _currentURL && [_currentURL isEqual:webView.request.mainDocumentURL];
    BOOL complete = [readyState isEqualToString:@"complete"];
    if (complete && isNotRedirect) {

        [self completeProgress];
    }

}
//
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{    
    if ([_webViewProxyDelegate respondsToSelector:@selector(webView:didFailLoadWithError:)]) {

        [_webViewProxyDelegate webView:webView didFailLoadWithError:error];
    }
    if ([_webBridgeDelegate respondsToSelector:@selector(webView:didFailLoadWithError:)]) {

        [_webBridgeDelegate webView:webView didFailLoadWithError:error];
    }
    
    _loadingCount--;
    [self incrementProgress];
    
    NSString *readyState = [webView stringByEvaluatingJavaScriptFromString:@"document.readyState"];
    
    BOOL interactive = [readyState isEqualToString:@"interactive"];
    if (interactive) {

        _interactive = YES;
        NSString *waitForCompleteJS = [NSString stringWithFormat:@"window.addEventListener('load',function() { var iframe = document.createElement('iframe'); iframe.style.display = 'none'; iframe.src = '%@'; document.body.appendChild(iframe);  }, false);", completeRPCURLPath];
        [webView stringByEvaluatingJavaScriptFromString:waitForCompleteJS];
    }
    
    BOOL isNotRedirect = _currentURL && [_currentURL isEqual:webView.request.mainDocumentURL];
    BOOL complete = [readyState isEqualToString:@"complete"];
    if (complete && isNotRedirect) {

        [self completeProgress];
    }
}
```
##### 4. 外部使用 
```
if (_bridge) {

    return;
}            

// 开启调试信息    
[WebViewJavascriptBridge enableLogging];       

// 这里的testObjcCallback是用来判断前端传过来的callHandler
_bridge = [WebViewJavascriptBridge bridgeUserNJKForWebView:self.webView handlerName:@"testObjcCallback" handler:^(id data, WVJBResponseCallback responseCallback) {

    // 注意，block里必须使用weakSelf，否则会造成循环引用
    NSLog(@"ObjC received message from JS: %@", data);
    NSString *dataStr=(NSString *)data;
    // ....    
}]; 

//  这里一定要将这个代理设置为_bridge对象    
self.progressProxy.webBridgeDelegate = _bridge;
```