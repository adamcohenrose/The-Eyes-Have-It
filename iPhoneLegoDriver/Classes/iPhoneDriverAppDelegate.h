//
//  iPhoneDriverAppDelegate.h
//  iPhoneDriver
//
//  Created by Adam Cohen-Rose on 11/09/2010.
//  Copyright 2010 The Cloud. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "iPhoneDriverViewController.h"

@interface iPhoneDriverAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
	iPhoneDriverViewController* avViewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;

@end

