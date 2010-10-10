//
//  iPhoneDriverViewController.m
//  iPhoneDriver
//
//  Created by Adam Cohen-Rose on 11/09/2010.
//  Copyright 2010 The Cloud. All rights reserved.
//

#import "iPhoneDriverViewController.h"
#import <math.h>

@interface iPhoneDriverViewController()
- (void)setupCaptureSession;
- (void)captureOutput:(AVCaptureOutput *)captureOutput 
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer 
	   fromConnection:(AVCaptureConnection *)connection;
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer;
- (IplImage *)CreateIplImageFromUIImage:(UIImage *)image;
- (UIImage *)UIImageFromIplImage:(IplImage *)image;

@property (nonatomic,retain) AVCaptureSession* session;
@end



@implementation iPhoneDriverViewController

@synthesize session;

- (id)init {
    if ((self = [super initWithNibName:@"iPhoneDriverViewController" bundle:nil])) {
        // Custom initialization
    }
    return self;
}

- (void)dealloc {
    [super dealloc];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
//	[openCvView setTransform:CGAffineTransformMakeRotation(M_PI_2)];
	
	NSString *path = [[NSBundle mainBundle] pathForResource:@"haarcascade_frontalface_default" ofType:@"xml"];
	NSLog(@"loading cascade from %@", path);
	cascade = (CvHaarClassifierCascade*)cvLoad([path cStringUsingEncoding:NSASCIIStringEncoding], NULL, NULL, NULL);
	storage = cvCreateMemStorage(0);
	cvSetErrMode(CV_ErrModeParent);
	
	[self setupCaptureSession];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
	cvReleaseHaarClassifierCascade(&cascade);
	cvReleaseMemStorage(&storage);
}


#pragma mark -
#pragma mark video processing

// Create and configure a capture session and start it running
- (void)setupCaptureSession {
    NSError *error = nil;
	
    // Create the session
    AVCaptureSession *newSession = [[AVCaptureSession alloc] init];
	
    // Configure the session to produce lower resolution video frames, if your 
    // processing algorithm can cope. We'll specify medium quality for the
    // chosen device.
	newSession.sessionPreset = AVCaptureSessionPreset640x480;
	
    // Find the front camera
    AVCaptureDevice *device = [AVCaptureDevice deviceWithUniqueID:
							   @"com.apple.avfoundation.avcapturedevice.built-in_video:1"];
	
    // Create a device input with the device and add it to the session.
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device 
																		error:&error];
    if (!input) {
        // Handling the error appropriately.
		NSLog(@"could not load input: %@", error);
		return;
    }
    [newSession addInput:input];
	
    // Create a VideoDataOutput and add it to the session
    AVCaptureVideoDataOutput *output = [[[AVCaptureVideoDataOutput alloc] init] autorelease];
    [newSession addOutput:output];
	
    // Configure your output.
    dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
    [output setSampleBufferDelegate:self queue:queue];
    dispatch_release(queue);
	
    // Specify the pixel format
    output.videoSettings = 
	[NSDictionary dictionaryWithObject:
	 [NSNumber numberWithInt:kCVPixelFormatType_32BGRA] 
								forKey:(id)kCVPixelBufferPixelFormatTypeKey];
	output.alwaysDiscardsLateVideoFrames = YES;
	
	
    // If you wish to cap the frame rate to a known value, such as 15 fps, set 
    // minFrameDuration.
    output.minFrameDuration = CMTimeMake(1, 15);
	
	AVCaptureVideoPreviewLayer *previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:newSession];
	previewLayer.frame = cameraPreview.bounds; // Assume you want the preview layer to fill the view.
	[cameraPreview.layer addSublayer:previewLayer];
	
    // Start the session running to start the flow of data
    [newSession startRunning];
	
    // Assign session to an ivar.
    [self setSession:newSession];
}

// Delegate routine that is called when a sample buffer was written
- (void)captureOutput:(AVCaptureOutput *)captureOutput 
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer 
	   fromConnection:(AVCaptureConnection *)connection { 
	
    // Create a UIImage from the sample buffer data
    UIImage *uiImage = [self imageFromSampleBuffer:sampleBuffer];
	if (!uiImage) {
		return;
	}

	IplImage *image = [self CreateIplImageFromUIImage:uiImage];
	
	// Scaling down
	int scale = 2;
	IplImage *smallImage = cvCreateImage(cvSize(image->width/scale, image->height/scale), IPL_DEPTH_8U, 3);
	cvPyrDown(image, smallImage, CV_GAUSSIAN_5x5);
	cvReleaseImage(&image);
	
	// transpose (as video is landscape...)
	IplImage *portraitImage = cvCreateImage(cvSize(smallImage->height, smallImage->width), IPL_DEPTH_8U, 3);
	cvTranspose(smallImage, portraitImage);
	cvReleaseImage(&smallImage);
	
	// Detect faces
    cvClearMemStorage(storage);
	CvSeq* faces = cvHaarDetectObjects(portraitImage, cascade, storage, 1.2f, 2,
									   CV_HAAR_FIND_BIGGEST_OBJECT | CV_HAAR_DO_ROUGH_SEARCH,
									   cvSize(30, 30));
	cvReleaseImage(&portraitImage);
	NSLog(@"found %d faces in image", faces->total);
	
	UIColor* legoControlColor = [UIColor grayColor];
	
	NSArray* subviews = [faceRectsView subviews];
	for (UIView* subview in subviews) {
		[subview performSelectorOnMainThread:@selector(removeFromSuperview)
								  withObject:nil waitUntilDone:YES];
	}
	CGRect containerFrame = cameraPreview.frame;
	float containerScale = 320.0 / containerFrame.size.width;
	NSLog(@"container: %@, scale: %.2f", NSStringFromCGRect(containerFrame), containerScale);
	for (int i = 0; i < faces->total; i++) {
		CvRect cvrect = *(CvRect*)cvGetSeqElem(faces, i);
		NSLog(@"cvrect: {{%d,%d},{%d,%d}}", cvrect.x, cvrect.y, cvrect.width, cvrect.height);
		CGRect faceRect = CGRectMake(cvrect.x * containerScale, cvrect.y * containerScale,
									 cvrect.width * containerScale, cvrect.height * containerScale);
		NSLog(@"faceRect: %@", NSStringFromCGRect(faceRect));
		UIView* faceRectView = [[UIView alloc] initWithFrame:faceRect];
		[faceRectView setOpaque:NO];
		[faceRectView setAlpha:0.4];
		[faceRectView setBackgroundColor:[UIColor whiteColor]];
		[[faceRectView layer] setBorderColor:[[UIColor redColor] CGColor]];
		[[faceRectView layer] setBorderWidth:1.0f];
		[faceRectsView performSelectorOnMainThread:@selector(addSubview:) withObject:faceRectView waitUntilDone:YES];
		[faceRectView release];
		
		if (i == 0) {
			// dark is left
			CGFloat faceXPos = faceRect.origin.x + faceRect.size.width / 2;
			CGFloat whiteValue = faceXPos / containerFrame.size.width;
			legoControlColor = [UIColor colorWithWhite:whiteValue alpha:1.0];
		}
	}
	[legoControlView performSelectorOnMainThread:@selector(setBackgroundColor:)
									  withObject:legoControlColor waitUntilDone:YES];
	
//	[openCvView performSelectorOnMainThread:@selector(setImage:) withObject:uiImage waitUntilDone:YES];
}

// Create a UIImage from sample buffer data
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer,0);
	
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer); 
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer); 
    size_t height = CVPixelBufferGetHeight(imageBuffer); 
	
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB(); 
    if (!colorSpace) {
        NSLog(@"CGColorSpaceCreateDeviceRGB failure");
        return nil;
    }
	
    // Get the base address of the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    // Get the data size for contiguous planes of the pixel buffer.
    size_t bufferSize = CVPixelBufferGetDataSize(imageBuffer); 
	
    // Create a Quartz direct-access data provider that uses data we supply
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, baseAddress, bufferSize, 
															  NULL);
    // Create a bitmap image from data supplied by our data provider
    CGImageRef cgImage = 
	CGImageCreate(width,
				  height,
				  8,
				  32,
				  bytesPerRow,
				  colorSpace,
				  kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little,
				  provider,
				  NULL,
				  true,
				  kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
	
    // Create and return an image object representing the specified Quartz image
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
	
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
	
    return image;
}

// NOTE you SHOULD cvReleaseImage() for the return value when end of the code.
- (IplImage *)CreateIplImageFromUIImage:(UIImage *)image {
	// Getting CGImage from UIImage
	CGImageRef imageRef = image.CGImage;
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	// Creating temporal IplImage for drawing
	IplImage *iplimage = cvCreateImage(
									   cvSize(image.size.width,image.size.height), IPL_DEPTH_8U, 4
									   );
	// Creating CGContext for temporal IplImage
	CGContextRef contextRef = CGBitmapContextCreate(
													iplimage->imageData, iplimage->width, iplimage->height,
													iplimage->depth, iplimage->widthStep,
													colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault
													);
	// Drawing CGImage to CGContext
	CGContextDrawImage(
					   contextRef,
					   CGRectMake(0, 0, image.size.width, image.size.height),
					   imageRef
					   );
	CGContextRelease(contextRef);
	CGColorSpaceRelease(colorSpace);
	
	// Creating result IplImage
	IplImage *ret = cvCreateImage(cvGetSize(iplimage), IPL_DEPTH_8U, 3);
	cvCvtColor(iplimage, ret, CV_RGBA2BGR);
	cvReleaseImage(&iplimage);
	
	return ret;
}

// NOTE You should convert color mode as RGB before passing to this function
- (UIImage *)UIImageFromIplImage:(IplImage *)image {
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	// Allocating the buffer for CGImage
	NSData *data =
    [NSData dataWithBytes:image->imageData length:image->imageSize];
	CGDataProviderRef provider =
    CGDataProviderCreateWithCFData((CFDataRef)data);
	// Creating CGImage from chunk of IplImage
	CGImageRef imageRef = CGImageCreate(
										image->width, image->height,
										image->depth, image->depth * image->nChannels, image->widthStep,
										colorSpace, kCGImageAlphaNone|kCGBitmapByteOrderDefault,
										provider, NULL, false, kCGRenderingIntentDefault
										);
	// Getting UIImage from CGImage
	UIImage *ret = [UIImage imageWithCGImage:imageRef];
	CGImageRelease(imageRef);
	CGDataProviderRelease(provider);
	CGColorSpaceRelease(colorSpace);
	return ret;
}

@end
