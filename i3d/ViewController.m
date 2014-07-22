//
//  ViewController.m
//  Hack
//
//  Created by Brian Chu on 7/19/14.
//  Copyright (c) 2014 Brian. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
@property (strong, nonatomic) UIView *touchView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(10, 10, 100, 100)];
    view.backgroundColor = [UIColor blueColor];
    self.touchView = view;
    [self.view addSubview:view];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *any = [touches anyObject];
    CGRect frame = self.touchView.frame;
    frame.origin = [any locationInView:self.view];
    self.touchView.frame = frame;
}

@end
