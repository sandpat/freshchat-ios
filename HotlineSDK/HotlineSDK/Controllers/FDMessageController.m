//
//  FDMessageController.m
//  HotlineSDK
//
//  Created by Aravinth Chandran on 27/10/15.
//  Copyright © 2015 Freshdesk. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "FDMessageController.h"
#import "FDMessageCell.h"
#import "KonotorImageInput.h"
#import "Hotline.h"
#import "KonotorMessage.h"
#import "Konotor.h"
#import "HLMacros.h"
#import "FDLocalNotification.h"
#import "FDAudioMessageInputView.h"
#import "HLConstants.h"
#import "HLArticle.h"
#import "HLArticleDetailViewController.h"
#import "HLArticlesController.h"
#import "HLContainerController.h"
#import "HLLocalization.h"
#import "HLTheme.h"
#import "FDUtilities.h"
#import "FDImagePreviewController.h"
#import "HLMessageServices.h"
#import "HotlineAppState.h"
#import "FDBarButtonItem.h"
#import "FDSecureStore.h"
#import "HLNotificationHandler.h"

typedef struct {
    BOOL isLoading;
    BOOL isShowingAlert;
    BOOL isFirstWordOnLine;
    BOOL isKeyboardOpen;
    BOOL isModalPresentationPreferred;
} FDMessageControllerFlags;


@interface FDMessageController () <UITableViewDelegate, UITableViewDataSource, FDMessageCellDelegate, FDAudioInputDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *messages;
@property (nonatomic, strong) HLChannel *channel;
@property (nonatomic, strong) FDInputToolbarView *inputToolbar;
@property (nonatomic, strong) FDAudioMessageInputView *audioMessageInputView;
@property (nonatomic, strong) NSLayoutConstraint *bottomViewHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *bottomViewBottomConstraint;
@property (nonatomic, strong) UIView *bottomView;
@property (nonatomic, strong) UIImage *sentImage;
@property (nonatomic, strong) KonotorConversation *conversation;
@property (nonatomic, strong) KonotorImageInput *imageInput;
@property (nonatomic, strong) NSTimer *pollingTimer;
@property (nonatomic, strong) NSString* currentRecordingMessageId;
@property (nonatomic, strong) NSMutableDictionary* messageHeightMap;
@property (nonatomic, strong) NSMutableDictionary* messageWidthMap;
@property (nonatomic, assign) FDMessageControllerFlags flags;
@property (strong, nonatomic) NSString *appAudioCategory;

@property (nonatomic) CGFloat keyboardHeight;
@property (nonatomic) NSInteger messageCount;
@property (nonatomic) NSInteger messageCountPrevious;
@property (nonatomic) NSInteger messagesDisplayedCount;
@property (nonatomic) NSInteger loadmoreCount;

@end

@implementation FDMessageController

#define INPUT_TOOLBAR_HEIGHT  43
#define TABLE_VIEW_TOP_OFFSET 10
#define CELL_HORIZONTAL_PADDING 4

-(instancetype)initWithChannel:(HLChannel *)channel andPresentModally:(BOOL)isModal{
    self = [super init];
    if (self) {
        self.messageHeightMap = [[NSMutableDictionary alloc]init];
        self.messageWidthMap = [[NSMutableDictionary alloc]init];
        
        _flags.isFirstWordOnLine = YES;
        _flags.isModalPresentationPreferred = isModal;

        self.messageCount = 0;
        self.messageCountPrevious = 0;
        self.messagesDisplayedCount=20;
        self.loadmoreCount=20;
        
        self.channel = channel;
        self.imageInput = [[KonotorImageInput alloc]initWithConversation:self.conversation onChannel:self.channel];
        [Konotor setDelegate:self];
    }
    return self;
}

-(KonotorConversation *)conversation{
    if(!_conversation){
        _conversation = [_channel primaryConversation];
    }
    return _conversation;
}

-(BOOL)isModal{
    return  _flags.isModalPresentationPreferred;
}

-(void)willMoveToParentViewController:(UIViewController *)parent{
    parent.title = self.channel.name;
    self.messagesDisplayedCount = 20;
    self.view.backgroundColor = [UIColor whiteColor];
    [self setSubviews];
    [self updateMessages];
    [self setNavigationItem];
    [self registerAppAudioCategory];
    [self localNotificationSubscription];
    [self scrollTableViewToLastCell];
    [HLMessageServices downloadAllMessages:nil];
    [KonotorMessage markAllMessagesAsReadForChannel:self.channel];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDismissMessageInputView) name:@"CLOSE_AUDIO_RECORDING" object:nil];
}

-(UIView *)tableHeaderView{
    UIView *headerView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, self.view.frame.size.height, TABLE_VIEW_TOP_OFFSET)];
    headerView.backgroundColor = self.tableView.backgroundColor;
    return headerView;
}

-(void)viewWillAppear:(BOOL)animated{
    self.tableView.tableHeaderView = [self tableHeaderView];
    [HotlineAppState sharedInstance].currentVisibleChannel = self.channel;
    [super viewWillAppear:animated];
    
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self startPoller];
}

-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [self cancelPoller];
    [Konotor stopRecording];
    if([Konotor getCurrentPlayingMessageID]){
        [Konotor StopPlayback];
    }
    [self resetAudioSessionCategory];
    [self handleDismissMessageInputView];
    [HotlineAppState sharedInstance].currentVisibleChannel = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"CLOSE_AUDIO_RECORDING" object:nil];
}

-(void)registerAppAudioCategory{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    self.appAudioCategory = audioSession.category;
}

-(void)resetAudioSessionCategory{
        [self setAudioCategory:self.appAudioCategory];
}

-(void)setAudioCategory:(NSString *) audioSessionCategory{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *setCategoryError = nil;
    
    if (![audioSession setCategory:audioSessionCategory error:&setCategoryError]) {
        FDLog(@"%s setCategoryError=%@", __PRETTY_FUNCTION__, setCategoryError);
    }
}

- (void) handleDismissMessageInputView{
    if(self.audioMessageInputView.window)
        [self audioMessageInput:self.audioMessageInputView dismissButtonPressed:nil];

}

-(void)startPoller{
    if(![self.pollingTimer isValid]){
        self.pollingTimer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(pollMessages:)
                                                           userInfo:nil repeats:YES];
        FDLog(@"Starting Poller");
    }
}

-(void)cancelPoller{
    if([self.pollingTimer isValid]){
        [self.pollingTimer invalidate];
        FDLog(@"Cancelled Poller");
    }
}

-(void)pollMessages:(NSTimer *)timer{
    [HLMessageServices downloadAllMessages:nil];
}

-(void)setNavigationItem{
    if(_flags.isModalPresentationPreferred){
        UIBarButtonItem *closeButton = [[FDBarButtonItem alloc]initWithTitle:HLLocalizedString(LOC_MESSAGES_CLOSE_BUTTON_TEXT)  style:UIBarButtonItemStylePlain target:self action:@selector(closeButtonAction:)];
        
        [self.parentViewController.navigationItem setLeftBarButtonItem:closeButton];
    }else{
        if (!self.embedded) {
            [self configureBackButtonWithGestureDelegate:self];
        }
    }
}

-(void)closeButtonAction:(id)sender{
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(UIView *)headerView{
    float headerViewWidth      = self.view.frame.size.width;
    float headerViewHeight     = 25;
    CGRect headerViewFrame     = CGRectMake(0, 0, headerViewWidth, headerViewHeight);
    UIView *headerView = [[UIView alloc]initWithFrame:headerViewFrame];
    headerView.backgroundColor = [UIColor clearColor];
    return headerView;
}

-(void)setSubviews{
    
    FDSecureStore *secureStore = [FDSecureStore sharedInstance];
    NSString *overlayText = [secureStore objectForKey:HOTLINE_DEFAULTS_CONVERSATION_BANNER_MESSAGE];
    
    UIView *bannerMessageView= [UIView new];
    bannerMessageView.translatesAutoresizingMaskIntoConstraints = NO;
    bannerMessageView.backgroundColor = [[HLTheme sharedInstance] conversationOverlayBackgroundColor];
    [self.view addSubview:bannerMessageView];
    
    UILabel *bannerMesagelabel = [[UILabel alloc] init];
    bannerMesagelabel.font = [[HLTheme sharedInstance] conversationOverlayTextFont];
    bannerMesagelabel.text = overlayText;
    bannerMesagelabel.numberOfLines = 3;
    bannerMesagelabel.textColor = [[HLTheme sharedInstance] conversationOverlayTextColor];
    bannerMesagelabel.textAlignment = UITextAlignmentCenter;
    
    float overlayViewHeight = (MIN([self lineCountForLabel:bannerMesagelabel],3.0) *bannerMesagelabel.font.pointSize)+15;
    
    bannerMesagelabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [bannerMessageView addSubview:bannerMesagelabel];
    
    self.tableView = [[UITableView alloc]init];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.tableView.separatorStyle=UITableViewCellSeparatorStyleNone;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];
    
    //Bottomview
    self.bottomView = [[UIView alloc]init];
    self.bottomView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.bottomView];
    
    self.bottomViewHeightConstraint = [NSLayoutConstraint constraintWithItem:self.bottomView
                                                              attribute:NSLayoutAttributeHeight
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:nil
                                                              attribute:NSLayoutAttributeNotAnAttribute
                                                             multiplier:1.0
                                                               constant:0];
    
    self.bottomViewBottomConstraint = [NSLayoutConstraint constraintWithItem:self.bottomView
                                                              attribute:NSLayoutAttributeBottom
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:self.view
                                                              attribute:NSLayoutAttributeBottom
                                                             multiplier:1.0 constant:0];

    //Initial Constraints
    
    
    NSDictionary *views;
    
    NSDictionary *metrics = @{@"overlayHeight":[NSNumber numberWithFloat:overlayViewHeight]};

    if(overlayText.length >0){
        views = @{@"tableView" : self.tableView, @"bottomView" : self.bottomView, @"messageOverlayView": bannerMessageView, @"overlayText" : bannerMesagelabel};
        
        [bannerMessageView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[overlayText]|" options:0 metrics:nil views:views]];
        [bannerMessageView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-5-[overlayText]-5-|" options:0 metrics:nil views:views]];
        
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[messageOverlayView]|" options:0 metrics:nil views:views]];
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[messageOverlayView(overlayHeight)][tableView][bottomView]" options:0 metrics:metrics views:views]];
        
    }
    else{
        views = @{@"tableView" : self.tableView, @"bottomView" : self.bottomView};
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[tableView][bottomView]" options:0 metrics:nil views:views]];
    }
    
    [self.view addConstraint:self.bottomViewBottomConstraint];
    [self.view addConstraint:self.bottomViewHeightConstraint];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[bottomView]|" options:0 metrics:nil views:views]];
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[tableView]|" options:0 metrics:nil views:views]];
    
    if([self.channel.type isEqualToString:CHANNEL_TYPE_BOTH]){
        
        self.inputToolbar = [[FDInputToolbarView alloc]initWithDelegate:self];
        self.inputToolbar.translatesAutoresizingMaskIntoConstraints = NO;
        [self.inputToolbar showAttachButton:YES];
        
        self.audioMessageInputView = [[FDAudioMessageInputView alloc] initWithDelegate:self];
        self.audioMessageInputView.translatesAutoresizingMaskIntoConstraints = NO;
        
        [self updateBottomViewWith:self.inputToolbar andHeight:INPUT_TOOLBAR_HEIGHT];
    }
}

- (float)lineCountForLabel:(UILabel *)label {
    CGSize maximumLabelSize = CGSizeMake(self.view.frame.size.width-10,9999);
    CGSize sizeOfText = [label.text sizeWithFont:label.font
                                constrainedToSize:maximumLabelSize
                                    lineBreakMode:label.lineBreakMode];
    int numberOfLines = sizeOfText.height / label.font.pointSize;
    
    return numberOfLines;
}

-(void)updateBottomViewWith:(UIView *)view andHeight:(CGFloat) height{
    [[self.bottomView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    [self.bottomView addSubview:view];
    self.bottomViewHeightConstraint.constant = height;
    
    NSDictionary *views = @{ @"bottomInputView" : view };
    [self.bottomView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[bottomInputView]|" options:0 metrics:nil views:views]];
    [self.bottomView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[bottomInputView]|" options:0 metrics:nil views:views]];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    NSString *cellIdentifier = @"FDMessageCell";
    FDMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[FDMessageCell alloc] initWithReuseIdentifier:cellIdentifier andDelegate:self];
    }
    if (indexPath.row < self.messages.count) {
        KonotorMessageData *message = self.messages[(self.messageCount - self.messagesDisplayedCount)+indexPath.row];
        cell.messageData = message;
        [cell drawMessageViewForMessage:message parentView:self.view withWidth:[self getWidthForMessage:message]];
    }
    
    
    if(indexPath.row==0 && self.messagesDisplayedCount<self.messages.count){
        UITableViewCell* cell=[self getRefreshStatusCell];
        NSInteger oldnumber = self.messagesDisplayedCount;
        self.messagesDisplayedCount += self.loadmoreCount;
        if(self.messagesDisplayedCount > self.messageCount){
            self.messagesDisplayedCount = self.messageCount;
        }
        [self performSelector:@selector(refreshView:) withObject:@(oldnumber) afterDelay:0];
        return cell;
    }
    return cell;
}

- (UITableViewCell*) getRefreshStatusCell
{
    static NSString *CellIdentifier = @"KonotorRefreshCell";
    
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if(cell==nil){
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    [cell setBackgroundColor:[UIColor clearColor]];
    UIActivityIndicatorView* refreshIndicator=(UIActivityIndicatorView*)[cell viewWithTag:KONOTOR_REFRESHINDICATOR_TAG];
    if(refreshIndicator==nil){
        refreshIndicator=[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        [refreshIndicator setFrame:CGRectMake(self.view.frame.size.width/2-10, cell.contentView.frame.size.height/2-10, 20, 20)];
        refreshIndicator.tag=KONOTOR_REFRESHINDICATOR_TAG;
        [cell.contentView addSubview:refreshIndicator];
    }
    if(![refreshIndicator isAnimating])
        [refreshIndicator startAnimating];
    
    return cell;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.messagesDisplayedCount;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    KonotorMessageData *message = self.messages[(self.messageCount - self.messagesDisplayedCount)+indexPath.row];
    float height;
    NSString *key = [self getIdentityForMessage:message];
    if(self.messageHeightMap[key]){
        height = [self.messageHeightMap[key] floatValue];
    }
    else {
        height = [FDMessageCell getHeightForMessage:message parentView:self.view];
        self.messageHeightMap[key] = @(height);
    }
    return height+CELL_HORIZONTAL_PADDING;
}


-(CGFloat)getWidthForMessage:(KonotorMessageData *) message{
    float width;
    NSString *key = [self getIdentityForMessage:message];
    if(self.messageWidthMap[key]){
        width = [self.messageWidthMap[key] floatValue];
    }
    else {
        width = [FDMessageCell getWidthForMessage:message];
        self.messageWidthMap[key] = @(width);
    }
    return width;
}


-(NSString *)getIdentityForMessage:(KonotorMessageData *)message{
    return ((message.messageId==nil)?[NSString stringWithFormat:@"%ul",message.createdMillis.intValue]:message.messageId);
    //[FDUtilities getKeyForObject:message];
}

-(void)inputToolbar:(FDInputToolbarView *)toolbar attachmentButtonPressed:(id)sender{
    [self.view endEditing:YES];
    [self.imageInput showInputOptions:self];
}

-(void)inputToolbar:(FDInputToolbarView *)toolbar micButtonPressed:(id)sender{
    
    if([Konotor getCurrentPlayingMessageID]){
        [Konotor StopPlayback];
    }
    
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        if (granted) {
            BOOL recording=[Konotor startRecording];
            if(recording){
                [self updateBottomViewWith:self.audioMessageInputView andHeight:INPUT_TOOLBAR_HEIGHT];
            }
        }
        else {
            UIAlertView *permissionAlert = [[UIAlertView alloc] initWithTitle:nil message:HLLocalizedString(LOC_AUDIO_RECORDING_PERMISSION_DENIED_TEXT) delegate:nil cancelButtonTitle:@"Cancel" otherButtonTitles:nil, nil];
            [permissionAlert show];
        }
    }];
}

-(void)messageCell:(FDMessageCell *)cell playButtonIsPressed:(id)sender{
    //if recording
    
    //show prompt to continue of not
    
    //if cancel - play audio stop recording
    
    //
}

-(void)showAlertWithTitle:(NSString *)title andMessage:(NSString *)message{
    UIAlertView *alert=[[UIAlertView alloc] initWithTitle:title message:message delegate:self
                                        cancelButtonTitle:@"OK" otherButtonTitles: nil];
    [alert show];
}

-(void)inputToolbar:(FDInputToolbarView *)toolbar sendButtonPressed:(id)sender{
    NSCharacterSet *trimChars = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString *toSend = [self.inputToolbar.textView.text stringByTrimmingCharactersInSet:trimChars];
    if(([toSend isEqualToString:@""]) || ([toSend isEqualToString:HLLocalizedString(LOC_MESSAGE_PLACEHOLDER_TEXT)])){
        [self showAlertWithTitle:HLLocalizedString(LOC_EMPTY_MSG_TITLE) andMessage:HLLocalizedString(LOC_EMPTY_MSG_INFO_TEXT)];
        
    }else{
        [Konotor uploadTextFeedback:toSend onConversation:self.conversation onChannel:self.channel];
        [self checkPushNotificationState];
        self.inputToolbar.textView.text = @"";
        [self inputToolbar:toolbar textViewDidChange:toolbar.textView];
    }
    [self refreshView];
}

-(void)checkPushNotificationState{
    
    BOOL notificationEnabled = [HLNotificationHandler areNotificationsEnabled];
    
    if (!notificationEnabled) {
        if([Konotor showNotificationDisabledAlert]){
            [self showAlertWithTitle:HLLocalizedString(LOC_MODIFY_PUSH_SETTING_TITLE)
                          andMessage:HLLocalizedString(LOC_MODIFY_PUSH_SETTING_INFO_TEXT)];
        }
    }
}

-(void) askForNotifications{
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge) categories:nil]];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    }else{
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes: (UIRemoteNotificationTypeNewsstandContentAvailability| UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
    }
}

-(void)localNotificationSubscription{
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleEnteredBackground:)
                                                 name: UIApplicationDidEnterBackgroundNotification
                                               object: nil];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleBecameActive:)
                                                 name: UIApplicationDidBecomeActiveNotification
                                               object: nil];
    
    [[NSNotificationCenter defaultCenter]addObserverForName:HOTLINE_NETWORK_REACHABLE object:nil
                                                      queue:nil usingBlock:^(NSNotification *note) {
         [KonotorMessage uploadAllUnuploadedMessages];
    }];
}

-(void)localNotificationUnSubscription{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)handleBecameActive:(NSNotification *)notification{
    [self startPoller];
}

-(void)handleEnteredBackground:(NSNotification *)notification{
    [self cancelPoller];
}

#pragma mark Keyboard delegate

-(void) keyboardWillShow:(NSNotification *)note{
    NSTimeInterval animationDuration = [[note.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    _flags.isKeyboardOpen = YES;
    CGRect keyboardFrame = [[note.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardRect = [self.view convertRect:keyboardFrame fromView:nil];
    CGFloat keyboardCoveredHeight = self.view.bounds.size.height - keyboardRect.origin.y;
    self.bottomViewBottomConstraint.constant = - keyboardCoveredHeight;
    self.keyboardHeight = keyboardCoveredHeight;
    [UIView animateWithDuration:animationDuration animations:^{
        [self.view layoutIfNeeded];
    }];
    [self scrollTableViewToLastCell];
}

-(void) keyboardWillHide:(NSNotification *)note{
    _flags.isKeyboardOpen = NO;
    NSTimeInterval animationDuration = [[note.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    self.keyboardHeight = 0.0;
    self.bottomViewBottomConstraint.constant = 0.0;
    [self.view layoutIfNeeded];
    [UIView animateWithDuration:animationDuration animations:^{
        [self.view layoutIfNeeded];
    }];
}

#pragma mark Text view delegates

-(void)inputToolbar:(FDInputToolbarView *)toolbar textViewDidChange:(UITextView *)textView{    
    
    CGSize txtSize = [textView sizeThatFits:CGSizeMake(textView.frame.size.width, 140)];
    float height=txtSize.height;
    if((height)>=67){
        height=67;
        if(_flags.isFirstWordOnLine == YES){
            _flags.isFirstWordOnLine = NO;
        }else{
            textView.scrollEnabled=YES;
        }
    }
    else{
        textView.scrollEnabled=NO;
    }
    
    if (height > self.bottomViewHeightConstraint.constant) {
        self.bottomViewHeightConstraint.constant = height+10; //Fix this
        self.bottomViewBottomConstraint.constant = - self.keyboardHeight;
    }
    else{
        self.bottomViewHeightConstraint.constant = height+10; //Fix this
        self.bottomViewBottomConstraint.constant = - self.keyboardHeight;
    }
    
    [UIView animateWithDuration:0.2 animations:^{
        textView.frame=CGRectMake(textView.frame.origin.x,textView.frame.origin.y,textView.frame.size.width,height);
        [self scrollTableViewToLastCell];

    }];
    
}

-(void)scrollTableViewToLastCell{

     NSInteger lastSpot = _flags.isLoading ? self.messagesDisplayedCount : (self.messagesDisplayedCount-1);
    
    if(lastSpot<0) return;
    
    NSIndexPath *indexPath=[NSIndexPath indexPathForRow:lastSpot inSection:0];
    @try {
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:NO];
    }
    @catch (NSException *exception ) {
        indexPath=[NSIndexPath indexPathForRow:(indexPath.row-1) inSection:0];
        @try{
            [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:NO];
        }
        @catch(NSException *exception){
        }
    }
}

-(void)scrollTableViewToCell:(int)lastSpot{
    
    if(lastSpot<0) return;
    NSIndexPath *indexPath=[NSIndexPath indexPathForRow:(self.messagesDisplayedCount-lastSpot) inSection:0];
    @try {
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
    }
    @catch (NSException *exception ) {
        indexPath=[NSIndexPath indexPathForRow:(indexPath.row-1) inSection:0];
        @try{
            [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
        }
        @catch(NSException *exception){
            
        }
    }
}

#pragma mark Konotor delegates

- (void) didStartUploadingNewMessage{
    [self refreshView];
}

- (void) didFinishDownloadingMessages{
    NSInteger count = [self fetchMessages].count;
    if( _flags.isLoading || (count > self.messageCountPrevious) ){
        _flags.isLoading = NO;
        [self refreshView];
    }
}

- (void) didFinishUploading:(NSString *)messageID{
    [self refreshView];
}

- (void) didEncounterErrorWhileUploading:(NSString *)messageID{
    if(!_flags.isShowingAlert){
        [self showAlertWithTitle:HLLocalizedString(LOC_MESSAGE_UNSENT_TITLE)
                      andMessage:HLLocalizedString(LOC_MESSAGE_UNSENT_INFO_TEXT)];
        _flags.isShowingAlert = YES;
    }
}

- (void) alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex{
    _flags.isShowingAlert = NO;
    
    if([alertView.title isEqualToString:HLLocalizedString(LOC_AUDIO_SIZE_LONG_ALERT_TITLE)]){
        if(buttonIndex == 1){
            [self sendMessage];
        }
    }
    if([alertView.title isEqualToString:HLLocalizedString(LOC_MODIFY_PUSH_SETTING_TITLE)]){
        //TODO: Handle this better. Checking for title looks bad
        [Konotor setDisabledNotificationAlertShown:YES];
        [self askForNotifications];
    }
}

- (void) didEncounterErrorWhileDownloading:(NSString *)messageID{
    //Show Toast
}

-(void) didEncounterErrorWhileDownloadingConversations{
    NSInteger count = [self fetchMessages].count;
    if(( _flags.isLoading )||(count > self.messageCountPrevious)){
        _flags.isLoading = NO;
        [self refreshView];
    }
}

-(void)updateMessages{
    self.messages = [self fetchMessages];
    self.messageCount=(int)[self.messages count];
    if((self.messagesDisplayedCount > self.messageCount)||
       (self.messageCount<=KONOTOR_MESSAGESPERPAGE)||
       ((self.messageCount - self.messagesDisplayedCount)<3)){
        
        self.messagesDisplayedCount = self.messageCount;
    }
}

- (void) refreshView{
    [self refreshView:nil];
}

- (void) refreshView:(id)obj{
    self.messageCountPrevious=(int)self.messages.count;
    self.messages = [self fetchMessages];
    self.messageCount=(int)[self.messages count];
    if((self.messagesDisplayedCount > self.messageCount)||
       (self.messageCount<=KONOTOR_MESSAGESPERPAGE)||
       ((self.messageCount - self.messagesDisplayedCount)<3)){
        self.messagesDisplayedCount = self.messageCount;
    }

    [self.tableView reloadData];
    [KonotorMessage markAllMessagesAsReadForChannel:self.channel];
    if(obj==nil)
        [self scrollTableViewToLastCell];
    else{
        [self scrollTableViewToCell:((NSNumber*)obj).intValue];
    }
}

-(NSArray *)fetchMessages{
    NSSortDescriptor* desc=[[NSSortDescriptor alloc] initWithKey:@"createdMillis" ascending:YES];
    NSMutableArray *messages = [NSMutableArray arrayWithArray:[[KonotorMessage getAllMesssageForChannel:self.channel] sortedArrayUsingDescriptors:@[desc]]];
    KonotorMessageData *firstMessage = messages.firstObject;
    if (firstMessage.isWelcomeMessage && !firstMessage.text.length) {
        [messages removeObject:firstMessage];
    }
    return messages;
}

#pragma Scrollview delegates
-(void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (_flags.isKeyboardOpen){
        CGPoint fingerLocation = [scrollView.panGestureRecognizer locationInView:scrollView];
        CGPoint absoluteFingerLocation = [scrollView convertPoint:fingerLocation toView:self.view];
        float viewFrameHeight = self.view.frame.size.height;
        NSInteger keyboardOffsetFromBottom = viewFrameHeight - absoluteFingerLocation.y;
        
        if (scrollView.panGestureRecognizer.state == UIGestureRecognizerStateChanged
            && absoluteFingerLocation.y >= (viewFrameHeight - self.keyboardHeight)) {
            self.bottomViewBottomConstraint.constant = -keyboardOffsetFromBottom;
        }
    }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [self.tableView reloadData];
    [self inputToolbar:self.inputToolbar textViewDidChange:self.inputToolbar.textView];
    [self scrollTableViewToLastCell];
}

#pragma mark - Message cell delegates


-(void)messageCell:(FDMessageCell *)cell pictureTapped:(UIImage *)image{
    FDImagePreviewController *imageController = [[FDImagePreviewController alloc]initWithImage:image];
    [imageController presentOnController:self];
    FDLog(@"Picture message tapped");
}

//TODO: Needs refractor
-(void)messageCell:(FDMessageCell *)cell openActionUrl:(id)sender{
    FDActionButton* button=(FDActionButton*)sender;
    if(button.articleID!=nil && button.articleID.integerValue > 0){
        @try{
            HLArticle *article = [HLArticle getWithID:button.articleID inContext:[KonotorDataManager sharedInstance].mainObjectContext];
            if(article!=nil){
                HLArticleDetailViewController* articleDetailController=[[HLArticleDetailViewController alloc] init];
                articleDetailController.articleID = article.articleID;
                articleDetailController.articleTitle = article.title;
                articleDetailController.articleDescription = article.articleDescription;
                articleDetailController.categoryTitle=article.category.title;
                articleDetailController.categoryID = article.categoryID;
                HLContainerController *container = [[HLContainerController alloc]initWithController:articleDetailController andEmbed:NO];
                [self.navigationController pushViewController:container animated:YES];
            }
        }
        @catch(NSException* e){
            NSLog(@"%@",e);
        }
    }
    else if(button.actionUrlString!=nil){
        @try{
            if (cell.messageData.marketingId.integerValue != 0) {
                [HLMessageServices markMarketingMessageAsClicked:cell.messageData.marketingId];
            }
            NSURL * actionUrl=[NSURL URLWithString:button.actionUrlString];
            if([[UIApplication sharedApplication] canOpenURL:actionUrl]){
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[UIApplication sharedApplication] openURL:actionUrl];
                });
            }
        }
        @catch(NSException* e){
            NSLog(@"%@",e);
        }
    }
}

#pragma mark - Audio toolbar delegates

-(void)audioMessageInput:(FDAudioMessageInputView *)toolbar dismissButtonPressed:(id)sender{
    [Konotor cancelRecording];
    [self updateBottomViewWith:self.inputToolbar andHeight:INPUT_TOOLBAR_HEIGHT];
}

-(void) audioMessageInput:(FDAudioMessageInputView *)toolbar stopButtonPressed:(id)sender{
    self.currentRecordingMessageId=[Konotor stopRecording];
}

-(void)audioMessageInput:(FDAudioMessageInputView *)toolbar sendButtonPressed:(id)sender{
    self.currentRecordingMessageId=[Konotor stopRecordingOnConversation:self.conversation];
    if(self.currentRecordingMessageId!=nil){
        
        [self updateBottomViewWith:self.inputToolbar andHeight:INPUT_TOOLBAR_HEIGHT];
        float audioMsgDuration = [[[KonotorMessage retriveMessageForMessageId:self.currentRecordingMessageId] durationInSecs] floatValue];
        
        if(audioMsgDuration <= 1){
            
            UIAlertView *shortMessageAlert = [[UIAlertView alloc] initWithTitle:HLLocalizedString(LOC_AUDIO_SIZE_SHORT_ALERT_TITLE) message:HLLocalizedString(LOC_AUDIO_SIZE_SHORT_ALERT_DESCRIPTION) delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
            [shortMessageAlert show];
            return;
        }
        
        else if(audioMsgDuration > 120){
            
            UIAlertView *longMessageAlert = [[UIAlertView alloc] initWithTitle:HLLocalizedString(LOC_AUDIO_SIZE_LONG_ALERT_TITLE) message:HLLocalizedString(LOC_AUDIO_SIZE_LONG_ALERT_DESCRIPTION) delegate:self cancelButtonTitle:@"No" otherButtonTitles:HLLocalizedString(LOC_AUDIO_SIZE_LONG_ALERT_POST_BUTTON_TITLE), nil];
            [longMessageAlert show];
        }
        else{
            [self sendMessage];
        }
    }
}

- (void) sendMessage{
    
    [Konotor uploadVoiceRecordingWithMessageID:self.currentRecordingMessageId toConversationID:([self.conversation conversationAlias]) onChannel:self.channel];
    [Konotor cancelRecording];
}

-(void)dealloc{
    [self localNotificationUnSubscription];
}

@end
