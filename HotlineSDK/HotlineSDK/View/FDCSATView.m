//
//  FDCSATView.m
//  HotlineSDK
//
//  Created by user on 17/10/16.
//  Copyright © 2016 Freshdesk. All rights reserved.
//

#import "FDCSATView.h"
#import "HCSStarRatingView.h"
#import "FDAutolayoutHelper.h"
#import "HLTheme.h"
#import "FDGrowingTextView.h"
#import "HLLocalization.h"

@interface FDCSATView() <UIGestureRecognizerDelegate>

@property (nonatomic, strong) UIView *transparentView;
@property (nonatomic, strong) UIView *CSATPrompt;
@property (nonatomic, strong) FDGrowingTextView *feedbackView;
@property (nonatomic) float rating;

@end

// Dismiss prompt & Add config
// Add theme

@implementation FDCSATView

- (instancetype)initWithController:(UIViewController *)controller andDelegate:(id <FDCSATViewDelegate>)delegate{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.delegate = delegate;
        
        //Transparent background view
        self.transparentView  = [UIView new];
        self.transparentView.translatesAutoresizingMaskIntoConstraints = NO;
        self.transparentView.backgroundColor =  [UIColor colorWithWhite:0.5 alpha:0.5];
        UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedOutsidePrompt)];
        singleTap.delegate = self;
        singleTap.numberOfTapsRequired = 1;
        [self.transparentView addGestureRecognizer:singleTap];
        [controller.view addSubview:self.transparentView];

        //CSAT prompt
        self.CSATPrompt = [UIView new];
        self.CSATPrompt.translatesAutoresizingMaskIntoConstraints = NO;
        self.CSATPrompt.backgroundColor = [UIColor whiteColor];
        self.CSATPrompt.center = self.transparentView.center;
        self.CSATPrompt.layer.cornerRadius = 15;
        [self.transparentView addSubview:self.CSATPrompt];
        
        UIView *starRatingView = [self createStarRatingView];
        [self.CSATPrompt addSubview:starRatingView];
        
        //Survey title
        UILabel *surveyTitle = [UILabel new];
        surveyTitle.numberOfLines = 0;
        surveyTitle.textAlignment = NSTextAlignmentCenter;
        surveyTitle.translatesAutoresizingMaskIntoConstraints = NO;
        surveyTitle.text = @"How would you rate your interaction with us ?";
        [self.CSATPrompt addSubview:surveyTitle];
        
        //Submit button
        UIButton *submitButton = [UIButton buttonWithType:UIButtonTypeSystem];
        submitButton.translatesAutoresizingMaskIntoConstraints = NO;
        [submitButton setTitle:@"SUBMIT" forState:(UIControlStateNormal)];
        [submitButton addTarget:self action:@selector(submitButtonPressed) forControlEvents:(UIControlEventTouchUpInside)];
        [self.CSATPrompt addSubview:submitButton];
        
        //Feedback textview
        self.feedbackView = [FDGrowingTextView new];
        self.feedbackView.placeholder = HLLocalizedString(LOC_CSAT_FEEDBACK_VIEW_PLACEHOLDER_TEXT);
        self.feedbackView.opaque = NO;
        self.feedbackView.alpha = 0.7;
        self.feedbackView.layer.borderWidth = 0.5;
        self.feedbackView.layer.borderColor = [UIColor lightGrayColor].CGColor;
        self.feedbackView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.CSATPrompt addSubview:self.feedbackView];
        
        //Horizontal line
        UIView *horizontalLine = [UIView new];
        horizontalLine.opaque = NO;
        horizontalLine.alpha = 0.3;
        horizontalLine.backgroundColor = [UIColor lightGrayColor];
        horizontalLine.translatesAutoresizingMaskIntoConstraints = NO;
        [self.CSATPrompt addSubview:horizontalLine];
        
        //Layout constraints
        NSDictionary *views = @{@"survey_title" : surveyTitle, @"submit_button" : submitButton,
                                @"horizontal_line" : horizontalLine, @"feedback_view" : self.feedbackView,
                                @"superview" : controller.view, @"transparent_view" : self.transparentView,
                                @"star_rating_view" : starRatingView};
        
        //Transparent view constraints
        [controller.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[transparent_view]|" options:0 metrics:nil views:views]];
        [controller.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[transparent_view]|" options:0 metrics:nil views:views]];
        
        //CSAT prompt constraints
        [FDAutolayoutHelper setWidth:250 forView:self.CSATPrompt inView:self.transparentView];
        [FDAutolayoutHelper setHeight:200 forView:self.CSATPrompt inView:self.transparentView];
        [FDAutolayoutHelper centerX:self.CSATPrompt onView:self.transparentView];
        self.CSATPromptCenterYConstraint = [FDAutolayoutHelper centerY:self.CSATPrompt onView:self.transparentView];
        
        //CSAT prompt subviews
        [FDAutolayoutHelper setWidth:150 forView:starRatingView inView:self.CSATPrompt];
        [FDAutolayoutHelper centerX:starRatingView onView:self.CSATPrompt];
        [FDAutolayoutHelper centerX:surveyTitle onView:self.CSATPrompt];
        [FDAutolayoutHelper centerX:self.feedbackView onView:self.CSATPrompt];
        [FDAutolayoutHelper centerX:submitButton onView:self.CSATPrompt];

        [FDAutolayoutHelper setWidth:200 forView:surveyTitle inView:self.CSATPrompt];
        [self.CSATPrompt addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[horizontal_line]|" options:0 metrics:nil views:views]];
        [FDAutolayoutHelper setWidth:200 forView:self.feedbackView inView:self.CSATPrompt];
        //TODO: Change survey title to intrinsic content size (by setting dynamically)
        [self.CSATPrompt addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[survey_title(50)][star_rating_view(50)][feedback_view]-[horizontal_line(1)]-8-[submit_button(20)]-8-|" options:0 metrics:nil views:views]];

        //Hide by default
        self.transparentView.hidden = YES;
        self.CSATPrompt.hidden = YES;
    }
    return self;
}

-(UIView *)createStarRatingView{
    HCSStarRatingView *starRatingView = [HCSStarRatingView new];
    starRatingView.translatesAutoresizingMaskIntoConstraints = NO;
    starRatingView.maximumValue = 5;
    starRatingView.minimumValue = 0;
    starRatingView.value = 0; // Initial value
    starRatingView.tintColor = [UIColor orangeColor];
    starRatingView.emptyStarImage = [[UIImage imageNamed:@"heart-empty"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    starRatingView.filledStarImage = [[UIImage imageNamed:@"heart-full"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [starRatingView addTarget:self action:@selector(didChangeValue:) forControlEvents:UIControlEventValueChanged];
    return starRatingView;
}

- (IBAction)didChangeValue:(HCSStarRatingView *)sender {
    self.rating = sender.value;
}

-(void)submitButtonPressed{
    //TODO: Add validation and enforce user if they do not rate
    if (self.delegate) {
        NSMutableDictionary *userFeedback = [[NSMutableDictionary alloc]init];
        
        if (self.rating) {
            userFeedback[@"ratingStars"]  = [NSString stringWithFormat:@"%d", (int)self.rating];
        }
        
        if (self.feedbackView.text && ![self.feedbackView.text isEqualToString:@""]) {
            userFeedback[@"feedback"] = self.feedbackView.text;
        }
        [self.delegate submittedCSATWithInfo:userFeedback];
    }
    [self dismiss];
}

-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch{
    return (touch.view == self.transparentView);
}

-(void)tappedOutsidePrompt{
    [self dismiss];
}

-(void)show{
    self.transparentView.hidden = NO;
    self.CSATPrompt.hidden = NO;
}

-(void)dismiss{
    self.transparentView.hidden = YES;
    self.CSATPrompt.hidden = YES;
}

@end
