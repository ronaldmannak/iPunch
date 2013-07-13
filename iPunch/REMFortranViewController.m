//
//  REMFortranViewController.m
//  iPunch
//
//  Created by Ronald Mannak on 7/13/13.
//  Copyright (c) 2013 Ronald Mannak. All rights reserved.
//

#import "REMFortranViewController.h"

@interface REMFortranViewController () {

}
@property (weak, nonatomic) IBOutlet UITextView *consoleTextView;
@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (nonatomic) NSUInteger webViewCount;

@end

@implementation REMFortranViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    self.webViewCount = 0;
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.compileonline.com/compile_fortran_online.php"]];
    [self.webView loadRequest:request];
}

#pragma mark - Getters and Setters

- (void)setWebViewCount:(NSUInteger)webViewCount
{
    _webViewCount = webViewCount;
    if (_webViewCount == 0) {
        // Finished loading
        self.consoleTextView.text = [self readConsole];
    }
}

#pragma mark - Web View

- (void)setCode:(NSString *)code
{
    
}

- (NSString *)readConsole
{
    // Unsuccessful attempt to read iFrame. 
    NSString *jsString = @"$('iframe').ready(function() { \
    var document1 = window.document.getElementsByTagName('iframe')[2].contentWindow.document.getElementsByTagName('contentview'); \
}";
    
    NSString *consoleOutput = [self.webView stringByEvaluatingJavaScriptFromString:jsString];

    return consoleOutput;
}

#pragma mark - Web View Delegate

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    self.webViewCount--;
    
    if ([error code] == NSURLErrorCancelled) {
        NSLog(@"Webview Cancelled");
        return;
    }
    
    [UIAlertView displayError:error];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    self.webViewCount--;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    self.webViewCount++;
}
@end
