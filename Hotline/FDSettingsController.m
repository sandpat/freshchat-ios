//
//  FDSettingsController.m
//  Hotline
//
//  Created by Aravinth Chandran on 29/10/15.
//  Copyright © 2015 Freshdesk. All rights reserved.
//

#import "FDSettingsController.h"
#import "HotlineSDK/Hotline.h"
#import "AppDelegate.h"

@interface FDSettingsController () <UIActionSheetDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property (strong, nonatomic) UIScrollView *containerView;

@property (strong, nonatomic) UITextField *domainField;
@property (strong, nonatomic) UITextField *appIDField;
@property (strong, nonatomic) UITextField *appKeyField;
@property (strong, nonatomic) UIButton *updateConfigButton;

@property (strong, nonatomic) UITextField *userFirstNameField;
@property (strong, nonatomic) UITextField *userLastNameField;
@property (strong, nonatomic) UITextField *emailField;
@property (strong, nonatomic) UITextField *phoneNumField;
@property (strong, nonatomic) UITextField *externalIDField;
@property (strong, nonatomic) UIButton *updateUserPropertiesButton;

@property (strong, nonatomic) UITextField *keyField;
@property (strong, nonatomic) UITextField *valueField;
@property (strong, nonatomic) UIButton *updateCustomPropertiesButton;

@property (strong, nonatomic) UIButton *selectImageButton;

@property (strong, nonatomic) UIButton *testNotificationButton;

@end

@implementation FDSettingsController

-(UITextField *)getTextFieldWithPlaceHolder:(NSString *)placeholder{
    UITextField *textField = [UITextField new];
    textField.placeholder = placeholder;
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    return textField;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.containerView = [[UIScrollView alloc]initWithFrame:self.view.frame];
    
    self.domainField = [self getTextFieldWithPlaceHolder:@"Domain name"];
    self.domainField.keyboardType = UIKeyboardTypeURL;
    
    self.appIDField = [self getTextFieldWithPlaceHolder:@"App ID"];
    self.appKeyField = [self getTextFieldWithPlaceHolder:@"App Key"];
    self.updateConfigButton = [self getCustomAutoLayoutButtonWithTitle:@"Update config" withAction:@selector(updateConfigButtonAction:)];
    
    self.userFirstNameField = [self getTextFieldWithPlaceHolder:@"First Name"];
    self.userLastNameField = [self getTextFieldWithPlaceHolder:@"Last Name"];
    
    self.emailField = [self getTextFieldWithPlaceHolder:@"Email address"];
    self.emailField.keyboardType = UIKeyboardTypeEmailAddress;
    
    self.phoneNumField = [self getTextFieldWithPlaceHolder:@"Phone number"];
    self.phoneNumField.keyboardType = UIKeyboardTypePhonePad;
    
    self.externalIDField = [self getTextFieldWithPlaceHolder:@"External ID"];
    self.updateUserPropertiesButton = [self getCustomAutoLayoutButtonWithTitle:@"Update user properties" withAction:@selector(updateUserPropertiesButtonAction:)];
    
    self.keyField = [self getTextFieldWithPlaceHolder:@"Key"];
    self.valueField = [self getTextFieldWithPlaceHolder:@"Value"];
    self.updateCustomPropertiesButton = [self getCustomAutoLayoutButtonWithTitle:@"➤" withAction:@selector(updateCustomPropertiesButtonAction:)];
    
    self.selectImageButton = [self getCustomAutoLayoutButtonWithTitle:@"choose image (+) from camera roll" withAction:@selector(selectImageButtonAction:)];
    
    self.testNotificationButton = [self getCustomAutoLayoutButtonWithTitle:@"Test Notification" withAction:@selector(testNotification:)];
    
    self.updateCustomPropertiesButton.backgroundColor = [UIColor colorWithHue:0.38 saturation:0.74 brightness:0.76 alpha:1];
    
    [self.view addSubview:self.containerView];
    [self.containerView addSubview:self.updateConfigButton];
    [self.containerView addSubview:self.updateUserPropertiesButton];
    [self.containerView addSubview:self.keyField];
    [self.containerView addSubview:self.valueField];
    [self.containerView addSubview:self.updateCustomPropertiesButton];
    [self.containerView addSubview:self.selectImageButton];
    [self.containerView addSubview:self.testNotificationButton];
    
    NSDictionary *configFields = @{ @"domainField":self.domainField, @"appIDField":self.appIDField, @"appKeyField":self.appKeyField, @"userFirstNameField":self.userFirstNameField, @"userLastNameField":self.userLastNameField, @"emailField":self.emailField, @"phoneNumField":self.phoneNumField, @"externalIDField":self.externalIDField, @"selectImageButton": self.selectImageButton};
    
    NSMutableDictionary *views = [NSMutableDictionary new];
    [views addEntriesFromDictionary:configFields];
    [views addEntriesFromDictionary:@{@"containerView":self.containerView,
                                     @"updateConfigButton":self.updateConfigButton,
                                     @"updateUserPropertiesButton":self.updateUserPropertiesButton,
                                     @"keyField":self.keyField, @"valueField":self.valueField,
                                      @"updateCustomPropButton":self.updateCustomPropertiesButton,
                                      @"testNotificationButton": self.testNotificationButton }];
    
    [self setupHorizontalConstraintsForViews:configFields onSuperView:self.containerView];
    
    NSDictionary *metrics = @{@"contentWidth": @(self.view.frame.size.width - 20) };
    
    [self.containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-10-[updateConfigButton(contentWidth)]-10-|" options:0 metrics:metrics views:views]];
    
    [self.containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-10-[updateUserPropertiesButton(contentWidth)]-10-|" options:0 metrics:metrics views:views]];
    
    [self.containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-15-[domainField]-[appIDField]-[appKeyField]-[updateConfigButton]-20-[userFirstNameField]-[userLastNameField]-[emailField]-[phoneNumField]-[externalIDField]-[updateUserPropertiesButton]-|" options:NSLayoutFormatAlignAllCenterX metrics:nil views:views]];
    
    [self.containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[updateUserPropertiesButton]-20-[keyField]" options:0 metrics:nil views:views]];
    
    [self.containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[keyField]-[valueField(keyField)]-[updateCustomPropButton(50)]-|" options:NSLayoutFormatAlignAllCenterY metrics:nil views:views]];
    
    [self.containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[keyField]-50-[selectImageButton]-50-[testNotificationButton]" options:0 metrics:nil views:views]];
    
    [self.containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-10-[testNotificationButton(contentWidth)]-10-|" options:0 metrics:metrics views:views]];

    [self updateFields];
}

-(void)viewDidLayoutSubviews{
    self.containerView.contentSize = CGSizeMake(self.view.frame.size.width, self.view.frame.size.height + 200);
}

-(UIButton *)getCustomAutoLayoutButtonWithTitle:(NSString *)title withAction:(SEL)action{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    button.titleLabel.numberOfLines = 0;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    button.layer.borderColor = [[UIColor colorWithHue:0.62 saturation:0.57 brightness:0.87 alpha:1]CGColor];
    button.backgroundColor = [UIColor colorWithHue:0.62 saturation:0.57 brightness:0.87 alpha:1];
    [[button layer] setBorderWidth:0.3f];
    button.layer.cornerRadius = 2;
    return button;
}

-(void)setupHorizontalConstraintsForViews:(NSDictionary *)views onSuperView:(UIView *)containerView{
    [views enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSString *constraintString = [NSString stringWithFormat:@"H:|-10-[%@]-10-|", key];
        [containerView addSubview:obj];
        [self.containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:constraintString options:0 metrics:nil views:views]];
    }];
}

- (void)selectImageButtonAction:(id)sender{
    UIImagePickerController* imagePicker=[[UIImagePickerController alloc] init];
    imagePicker.delegate=self;
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePicker.allowsEditing = NO;
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
        UIPopoverController  *popover=[[UIPopoverController alloc] initWithContentViewController:imagePicker];
        dispatch_async(dispatch_get_main_queue(), ^ {
            [popover presentPopoverFromRect:CGRectMake(self.view.frame.origin.x,self.view.frame.origin.y+self.view.frame.size.height-20,40,40) inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
        });
    }else{
        [self presentViewController:imagePicker animated:YES completion:NULL];
    }
}


- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info{
    [picker dismissViewControllerAnimated:NO completion:nil];
    UIImage* selectedImage = info[UIImagePickerControllerOriginalImage];
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    appDelegate.pickedImage = selectedImage;
    [[[UIAlertView alloc] initWithTitle:nil message: @"Background updated" delegate:nil
                      cancelButtonTitle:@"ok" otherButtonTitles:nil]show];
}

-(void)updateCustomPropertiesButtonAction:(id)sender{
    [[Hotline sharedInstance] updateUserPropertyforKey:self.keyField.text withValue:self.valueField.text];
}

-(void)updateConfigButtonAction:(id)sender{
    NSLog(@"Updating config");
    
    HotlineConfig *config = [[HotlineConfig alloc]initWithAppID:self.appIDField.text
                                                       andAppKey:self.appKeyField.text];
    config.domain = self.domainField.text;
    [[Hotline sharedInstance]initWithConfig:config];
}

-(void)updateUserPropertiesButtonAction:(id)sender{
    NSLog(@"updating user info");
    HotlineUser *user = [HotlineUser sharedInstance];
    user.firstName = self.userFirstNameField.text;
    user.lastName = self.userLastNameField.text;
    user.email = self.emailField.text;
    user.phoneNumber = self.phoneNumField.text;
    user.externalID = self.externalIDField.text;
    [[Hotline sharedInstance] setUser:user];
}

- (IBAction)editButtonPressed:(id)sender {
    UIActionSheet* inputOptions=[[UIActionSheet alloc] initWithTitle:nil delegate:nil cancelButtonTitle:@"Cancel"
                                              destructiveButtonTitle:nil otherButtonTitles:@"clear user data",nil];
    inputOptions.delegate = self;
    [inputOptions showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex{
    
    HotlineConfig *config = [[HotlineConfig alloc]initWithAppID:[Hotline sharedInstance].config.appID
                                                      andAppKey:[Hotline sharedInstance].config.appKey];
    config.domain = [Hotline sharedInstance].config.domain;

    switch (buttonIndex) {
        case 0:
            [[Hotline sharedInstance]resetUserWithCompletion:^{
                [[Hotline sharedInstance] setUser:[AppDelegate createHotlineUser]];
                [[Hotline sharedInstance]initWithConfig:config];
                [self updateFields];
            }];
            break;
    }
}

- (IBAction)closeButtonPressed:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void)updateFields{
    self.domainField.text = [Hotline sharedInstance].config.domain;
    self.appIDField.text = [Hotline sharedInstance].config.appID;
    self.appKeyField.text = [Hotline sharedInstance].config.appKey;
    
    self.userFirstNameField.text = [HotlineUser sharedInstance].firstName;
    self.userLastNameField.text = [HotlineUser sharedInstance].lastName;
    self.emailField.text = [HotlineUser sharedInstance].email;
    self.phoneNumField.text = [HotlineUser sharedInstance].phoneNumber;
    self.externalIDField.text = [HotlineUser sharedInstance].externalID;
}

-(void)testNotification:(id)sender{
    [[Hotline sharedInstance] handleRemoteNotification:@{
                                                                  @"channel_id" : @200,
                                                                      @"aps" : @{
                                                                          @"alert" :  @{ @"body" : @"Sample Test Message"
                                                                                        }
                                                                          },
                                                                  @"source" : @"freshchat_user"
                                                                  }
                                                    andAppstate:UIApplicationStateActive];
         }
@end
