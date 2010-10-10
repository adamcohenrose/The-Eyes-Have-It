//
//  iPhoneDriverViewController.h
//  iPhoneDriver
//
//  Created by Adam Cohen-Rose on 11/09/2010.
//  Copyright 2010 The Cloud. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <opencv/cv.h>
#import <CoreVideo/CoreVideo.h>

@interface iPhoneDriverViewController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate> {
	IBOutlet UIImageView* openCvView;
	IBOutlet UIView* cameraPreview;
	IBOutlet UIView* faceRectsView;
	IBOutlet UIView* legoControlView;
	
	AVCaptureSession* session;
	CvHaarClassifierCascade* cascade;
	CvMemStorage* storage;
}

@end

