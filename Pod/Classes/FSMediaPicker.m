//
//  FSMediaPicker.m
//  Pods
//
//  Created by Wenchao Ding on 2/3/15.
//  f33chobits@gmail.com
//

#import "FSMediaPicker.h"
#import <UIKit/UIKit.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <objc/runtime.h>

#define LocalizedString(key) \
NSLocalizedStringFromTableInBundle(key, @"FSMediaPicker", [NSBundle bundleWithPath:[[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"FSMediaPicker.bundle"]], nil)

#define kTakePhotoString LocalizedString(@"Take photo")
#define kSelectPhotoFromLibraryString LocalizedString(@"Select photo from photo library")
#define kRecordVideoString LocalizedString(@"Record video")
#define kSelectVideoFromLibraryString LocalizedString(@"Select video from photo library")
#define kCancelString LocalizedString(@"Cancel")

NSString const * UIImagePickerControllerCircularEditedImage = @" UIImagePickerControllerCircularEditedImage;";
NSString const * UIImagePickerControllerHexagonalEditedImage = @" FSImagePickerControllerHexagonalEditedImage;";

@interface FSMediaPicker ()<UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

- (UIWindow *)currentVisibleWindow;
- (UIViewController *)currentVisibleController;

- (void)delegatePerformFinishWithMediaInfo:(NSDictionary *)mediaInfo;
- (void)delegatePerformWillPresentImagePicker:(FSImagePickerController *)imagePicker;
- (void)delegatePerformCancel;

- (void)showAlertController:(UIView *)view;
- (void)showActionSheet:(UIView *)view;

- (void)takePhotoFromCamera;
- (void)takePhotoFromPhotoLibrary;
- (void)takeVideoFromCamera;
- (void)takeVideoFromPhotoLibrary;

@end

@implementation FSMediaPicker

#pragma mark - Life Cycle

- (instancetype)initWithDelegate:(id<FSMediaPickerDelegate>)delegate
{
    self = [super init];
    if (self) {
        self.delegate = delegate;
    }
    return self;
}

#pragma mark - Public

- (void)show
{
    [self showFromView:self.currentVisibleController.view];
}

- (void)showFromView:(UIView *)view
{

    if ([UIAlertController class]) {
        [self showAlertController:view];
    } else {
        [self showActionSheet:view];
    }
}

#pragma mark - UIActionSheet Delegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        return;
    }
    switch (buttonIndex) {
        case 0:
        {
            if (self.mediaType == FSMediaTypePhoto || self.mediaType == FSMediaTypeAll) {
                [self takePhotoFromCamera];
            } else if (self.mediaType == FSMediaTypeVideo) {
                [self takeVideoFromCamera];
            }
            break;
        }
        case 1:
        {
            if (self.mediaType == FSMediaTypePhoto || self.mediaType == FSMediaTypeAll) {
                [self takePhotoFromPhotoLibrary];
            } else if (self.mediaType == FSMediaTypeVideo) {
                [self takeVideoFromPhotoLibrary];
            }
            break;
        }
        case 2:
        {
            if (self.mediaType == FSMediaTypeAll) {
                [self takeVideoFromCamera];
            }
            break;
        }
        case 3:
        {
            if (self.mediaType == FSMediaTypeAll) {
                [self takeVideoFromPhotoLibrary];
            }
            break;
        }
        default:
            break;
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet willDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        [self delegatePerformCancel];
    }
}

#pragma mark - UIImagePickerController Delegate

- (void)imagePickerController:(FSImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [picker.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    [self delegatePerformFinishWithMediaInfo:info];
}

- (void)imagePickerControllerDidCancel:(FSImagePickerController *)picker
{
    [picker.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    [self delegatePerformCancel];
}

-(void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    
    if ([navigationController.viewControllers count] == 3 && self.editMode &&
        ([[[[navigationController.viewControllers objectAtIndex:2] class] description] isEqualToString:@"PUUIImageViewController"] || [[[[navigationController.viewControllers objectAtIndex:2] class] description] isEqualToString:@"PLUIImageViewController"]))
    {
        switch (self.editMode) {
            case FSEditModeCircular:
                [self addCircleOverlayToImagePicker:viewController];
                break;
            case FSEditModeHexagonal:
                [self addHexagonalOverlayToImagePicker:viewController];
                break;
            case FSEditModeNone:
            case FSEditModeStandard:
            default:
                break;
        }
    }
}

#pragma mark -  Overlays
// https://gist.github.com/andreacipriani/74ea67db8f17673f1b8b

-(void)addCircleOverlayToImagePicker:(UIViewController*)viewController
{
    UIColor *circleColor = [UIColor clearColor];
    UIColor *maskColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
    
    CGFloat screenHeight = [[UIScreen mainScreen] bounds].size.height;
    CGFloat screenWidth = [[UIScreen mainScreen] bounds].size.width;
    
    UIView *plCropOverlayCropView; //The default crop view, we wan't to hide it and show our circular one
    UIView *plCropOverlayBottomBar; //On iPhone is the bar with "cancel" and "choose" button, on Ipad is an Image View with a label saying "Scale and move"
    
    //Subviews hirearchy is different in iPad/iPhone:
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
        
        plCropOverlayCropView = [viewController.view.subviews objectAtIndex:1];
        plCropOverlayBottomBar = [[[[viewController.view subviews] objectAtIndex:1] subviews] objectAtIndex:1];
        
        //Protect against iOS changes...
        if (! [[[plCropOverlayCropView class] description] isEqualToString:@"PLCropOverlay"]){
            NSLog(@"Image Picker with circle overlay: PLCropOverlay not found");
            return;
        }
        if (! [[[plCropOverlayBottomBar class] description] isEqualToString:@"UIImageView"]){
            NSLog(@"Image Picker with circle overlay: PLCropOverlayBottomBar not found");
            return;
        }
    }
    else{
        plCropOverlayCropView = [[[viewController.view.subviews objectAtIndex:1] subviews] firstObject];
        plCropOverlayBottomBar = [[[[viewController.view subviews] objectAtIndex:1] subviews] objectAtIndex:1];
        
        //Protect against iOS changes...
        if (! [[[plCropOverlayCropView class] description] isEqualToString:@"PLCropOverlayCropView"]){
            NSLog(@"Image Picker with circle overlay: PLCropOverlayCropView not found");
            return;
        }
        if (! [[[plCropOverlayBottomBar class] description] isEqualToString:@"PLCropOverlayBottomBar"]){
            NSLog(@"Image Picker with circle overlay: PLCropOverlayBottomBar not found");
            return;
        }
    }
    
    //It seems that everything is ok, we found the CropOverlayCropView and the CropOverlayBottomBar
    
    plCropOverlayCropView.hidden = YES; //Hide default CropView
    
    CAShapeLayer *circleLayer = [CAShapeLayer layer];
    //Center the circleLayer frame:
    UIBezierPath *circlePath = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(0.0f, screenHeight/2 - screenWidth/2, screenWidth, screenWidth)];
    circlePath.usesEvenOddFillRule = YES;
    circleLayer.path = [circlePath CGPath];
    circleLayer.fillColor = circleColor.CGColor;
    //Mask layer frame: it begins on y=0 and ends on y = plCropOverlayBottomBar.origin.y
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, screenWidth, screenHeight- plCropOverlayBottomBar.frame.size.height) cornerRadius:0];
    [maskPath appendPath:circlePath];
    maskPath.usesEvenOddFillRule = YES;
    
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.path = maskPath.CGPath;
    maskLayer.fillRule = kCAFillRuleEvenOdd;
    maskLayer.fillColor = maskColor.CGColor;
    [viewController.view.layer addSublayer:maskLayer];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone){
        //On iPhone add an hint label on top saying "scale and move" or whatever you want
        UILabel *cropLabel = [[UILabel alloc]initWithFrame:CGRectMake(0, 10, screenWidth, 50)];
        [cropLabel setText:NSLocalizedString(@"Move & Scale", nil)];
        [cropLabel setTextAlignment:NSTextAlignmentCenter];
        [cropLabel setTextColor:[UIColor whiteColor]];
        [viewController.view addSubview:cropLabel];
    }
    else{ //On iPad re-add the overlayBottomBar with the label "scale and move" because we set its parent to hidden (it's a subview of PLCropOverlay)
        [viewController.view addSubview:plCropOverlayBottomBar];
    }
}

-(void)addHexagonalOverlayToImagePicker:(UIViewController*)viewController
{
    UIColor *hexColor = [UIColor clearColor];
    UIColor *maskColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
    
    CGFloat screenHeight = [[UIScreen mainScreen] bounds].size.height;
    CGFloat screenWidth = [[UIScreen mainScreen] bounds].size.width;
    
    UIView *plCropOverlayCropView; //The default crop view, we wan't to hide it and show our circular one
    UIView *plCropOverlayBottomBar; //On iPhone is the bar with "cancel" and "choose" button, on Ipad is an Image View with a label saying "Scale and move"
    
    //Subviews hirearchy is different in iPad/iPhone:
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
        
        plCropOverlayCropView = [viewController.view.subviews objectAtIndex:1];
        plCropOverlayBottomBar = [[[[viewController.view subviews] objectAtIndex:1] subviews] objectAtIndex:1];
        
        //Protect against iOS changes...
        if (! [[[plCropOverlayCropView class] description] isEqualToString:@"PLCropOverlay"]){
            NSLog(@"Image Picker with circle overlay: PLCropOverlay not found");
            return;
        }
        if (! [[[plCropOverlayBottomBar class] description] isEqualToString:@"UIImageView"]){
            NSLog(@"Image Picker with circle overlay: PLCropOverlayBottomBar not found");
            return;
        }
    }
    else{
        plCropOverlayCropView = [[[viewController.view.subviews objectAtIndex:1] subviews] firstObject];
        plCropOverlayBottomBar = [[[[viewController.view subviews] objectAtIndex:1] subviews] objectAtIndex:1];
        
        //Protect against iOS changes...
        if (! [[[plCropOverlayCropView class] description] isEqualToString:@"PLCropOverlayCropView"]){
            NSLog(@"Image Picker with circle overlay: PLCropOverlayCropView not found");
            return;
        }
        if (! [[[plCropOverlayBottomBar class] description] isEqualToString:@"PLCropOverlayBottomBar"]){
            NSLog(@"Image Picker with circle overlay: PLCropOverlayBottomBar not found");
            return;
        }
    }
    
    //It seems that everything is ok, we found the CropOverlayCropView and the CropOverlayBottomBar
    
    plCropOverlayCropView.hidden = YES; //Hide default CropView
    
    CAShapeLayer *hexLayer = [CAShapeLayer layer];
    CGFloat radius = screenWidth/2.f;
    CGRect rect = CGRectMake(0.f, screenHeight/2-screenWidth/2, screenWidth, screenWidth);
    CGPoint center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
    UIBezierPath *hexPath = [UIBezierPath bezierPath];
    [hexPath moveToPoint:CGPointMake(center.x + radius, center.y)];

    for(NSUInteger i=0;i<6;i++){
        CGFloat theta = 2 * M_PI / 6 * i;
        CGFloat x = center.x + radius * cosf(theta);
        CGFloat y = center.y + radius * sinf(theta);
        [hexPath addLineToPoint:CGPointMake(x, y)];
    }
    [hexPath closePath];
    hexPath.usesEvenOddFillRule = YES;
    hexLayer.path = [hexPath CGPath];
    hexLayer.fillColor = hexColor.CGColor;
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, screenWidth, screenHeight- plCropOverlayBottomBar.frame.size.height) cornerRadius:0];
    [maskPath appendPath:hexPath];
    maskPath.usesEvenOddFillRule = YES;
    
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.path = maskPath.CGPath;
    maskLayer.fillRule = kCAFillRuleEvenOdd;
    maskLayer.fillColor = maskColor.CGColor;
    [viewController.view.layer addSublayer:maskLayer];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone){
        //On iPhone add an hint label on top saying "scale and move" or whatever you want
        UILabel *cropLabel = [[UILabel alloc]initWithFrame:CGRectMake(0, 10, screenWidth, 50)];
        [cropLabel setText:NSLocalizedString(@"Move & Scale", nil)];
        [cropLabel setTextAlignment:NSTextAlignmentCenter];
        [cropLabel setTextColor:[UIColor whiteColor]];
        [viewController.view addSubview:cropLabel];
    }
    else{ //On iPad re-add the overlayBottomBar with the label "scale and move" because we set its parent to hidden (it's a subview of PLCropOverlay)
        [viewController.view addSubview:plCropOverlayBottomBar];
    }
}


#pragma mark - Setter & Getter

- (UIWindow *)currentVisibleWindow
{
    NSEnumerator *frontToBackWindows = [UIApplication.sharedApplication.windows reverseObjectEnumerator];
    for (UIWindow *window in frontToBackWindows){
        BOOL windowOnMainScreen = window.screen == UIScreen.mainScreen;
        BOOL windowIsVisible = !window.hidden && window.alpha > 0;
        BOOL windowLevelNormal = window.windowLevel == UIWindowLevelNormal;
        if (windowOnMainScreen && windowIsVisible && windowLevelNormal) {
            return window;
        }
    }
    return [[[UIApplication sharedApplication] delegate] window];
}

- (UIViewController *)currentVisibleController
{
    UIViewController *topController = self.currentVisibleWindow.rootViewController;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    return topController;
}

#pragma mark - Private

- (void)delegatePerformFinishWithMediaInfo:(NSDictionary *)mediaInfo
{
    if ([[mediaInfo allKeys] containsObject:UIImagePickerControllerEditedImage]) {
        NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithDictionary:mediaInfo];
        dic[UIImagePickerControllerCircularEditedImage] = [dic[UIImagePickerControllerEditedImage] circularImage];
        dic[UIImagePickerControllerHexagonalEditedImage] = [dic[UIImagePickerControllerEditedImage] hexagonalImage];
        mediaInfo = [NSDictionary dictionaryWithDictionary:dic];
    }
    if (_finishBlock) {
        _finishBlock(self,mediaInfo);
    } else if (_delegate && [_delegate respondsToSelector:@selector(mediaPicker:didFinishWithMediaInfo:)]) {
        [_delegate mediaPicker:self didFinishWithMediaInfo:mediaInfo];
    }
}

- (void)delegatePerformWillPresentImagePicker:(FSImagePickerController *)imagePicker
{
    if (_willPresentImagePickerBlock) {
        _willPresentImagePickerBlock(self,imagePicker);
    } else if (_delegate && [_delegate respondsToSelector:@selector(mediaPicker:willPresentImagePickerController:)]) {
        [_delegate mediaPicker:self willPresentImagePickerController:imagePicker];
    }
}

- (void)delegatePerformCancel
{
    if (_cancelBlock) {
        _cancelBlock(self);
    } else if (_delegate && [_delegate respondsToSelector:@selector(mediaPickerDidCancel:)]) {
        [_delegate mediaPickerDidCancel:self];
    }
}

- (void)showActionSheet:(UIView *)view
{
    UIActionSheet *actionSheet = [[UIActionSheet alloc] init];
    actionSheet.mediaPicker = self;
    switch (self.mediaType) {
        case FSMediaTypePhoto:
        {
            [actionSheet addButtonWithTitle:kTakePhotoString];
            [actionSheet addButtonWithTitle:kSelectPhotoFromLibraryString];
            [actionSheet addButtonWithTitle:kCancelString];
            actionSheet.cancelButtonIndex = 2;
            break;
        }
        case FSMediaTypeVideo:
        {
            [actionSheet addButtonWithTitle:kRecordVideoString];
            [actionSheet addButtonWithTitle:kSelectVideoFromLibraryString];
            [actionSheet addButtonWithTitle:kCancelString];
            actionSheet.cancelButtonIndex = 2;
            break;
        }
        case FSMediaTypeAll:
        {
            [actionSheet addButtonWithTitle:kTakePhotoString];
            [actionSheet addButtonWithTitle:kSelectPhotoFromLibraryString];
            [actionSheet addButtonWithTitle:kRecordVideoString];
            [actionSheet addButtonWithTitle:kSelectVideoFromLibraryString];
            [actionSheet addButtonWithTitle:kCancelString];
            actionSheet.cancelButtonIndex = 4;
            break;
        }
        default:
            break;
    }
    actionSheet.delegate = self;
    [actionSheet showFromRect:view.bounds inView:view animated:YES];
}

- (void)showAlertController:(UIView *)view
{
    UIAlertController *alertController = [[UIAlertController alloc] init];
    alertController.mediaPicker = self;
    switch (self.mediaType) {
        case FSMediaTypePhoto:
        {
            [alertController addAction:[UIAlertAction actionWithTitle:kTakePhotoString style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [self takePhotoFromCamera];
            }]];
            [alertController addAction:[UIAlertAction actionWithTitle:kSelectPhotoFromLibraryString style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [self takePhotoFromPhotoLibrary];
            }]];
            break;
        }
        case FSMediaTypeVideo:
        {
            [alertController addAction:[UIAlertAction actionWithTitle:kRecordVideoString style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [self takeVideoFromCamera];
            }]];
            [alertController addAction:[UIAlertAction actionWithTitle:kSelectVideoFromLibraryString style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [self takeVideoFromPhotoLibrary];
            }]];
            break;
        }
        case FSMediaTypeAll:
        {
            [alertController addAction:[UIAlertAction actionWithTitle:kTakePhotoString style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [self takePhotoFromCamera];
            }]];
            [alertController addAction:[UIAlertAction actionWithTitle:kSelectPhotoFromLibraryString style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [self takePhotoFromPhotoLibrary];
            }]];
            [alertController addAction:[UIAlertAction actionWithTitle:kRecordVideoString style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [self takeVideoFromCamera];
            }]];
            [alertController addAction:[UIAlertAction actionWithTitle:kSelectVideoFromLibraryString style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [self takeVideoFromPhotoLibrary];
            }]];
            break;
        }
        default:
            break;
    }
    [alertController addAction:[UIAlertAction actionWithTitle:kCancelString style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [self delegatePerformCancel];
    }]];
    alertController.popoverPresentationController.sourceView = view;
    alertController.popoverPresentationController.sourceRect = view.bounds;
    [self.currentVisibleController presentViewController:alertController animated:YES completion:nil];
}

- (void)takePhotoFromCamera
{
    if ([FSImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        FSImagePickerController *imagePicker = [FSImagePickerController new];
        imagePicker.allowsEditing = _editMode != FSEditModeNone;
        imagePicker.delegate = self;
        imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
        imagePicker.mediaTypes = @[(NSString *)kUTTypeImage];
        imagePicker.mediaPicker = self;
        [self delegatePerformWillPresentImagePicker:imagePicker];
        [self.currentVisibleController presentViewController:imagePicker animated:YES completion:nil];
    }
}

- (void)takePhotoFromPhotoLibrary
{
    if ([FSImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        FSImagePickerController *imagePicker = [FSImagePickerController new];
        imagePicker.allowsEditing = _editMode != FSEditModeNone;
        imagePicker.delegate = self;
        imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        imagePicker.mediaTypes = @[(NSString *)kUTTypeImage];
        imagePicker.mediaPicker = self;
        [self delegatePerformWillPresentImagePicker:imagePicker];
        [self.currentVisibleController presentViewController:imagePicker animated:YES completion:nil];
    }
}

- (void)takeVideoFromCamera
{
    if ([FSImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        FSImagePickerController *imagePicker = [FSImagePickerController new];
        imagePicker.allowsEditing = _editMode != FSEditModeNone;
        imagePicker.delegate = self;
        imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
        imagePicker.mediaTypes = @[(NSString *)kUTTypeMovie];
        imagePicker.mediaPicker = self;
        [self delegatePerformWillPresentImagePicker:imagePicker];
        [self.currentVisibleController presentViewController:imagePicker animated:YES completion:nil];
    }
}

- (void)takeVideoFromPhotoLibrary
{
    if ([FSImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        FSImagePickerController *imagePicker = [FSImagePickerController new];
        imagePicker.allowsEditing = _editMode != FSEditModeNone;
        imagePicker.delegate = self;
        imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        imagePicker.mediaTypes = @[(NSString *)kUTTypeMovie];
        imagePicker.mediaPicker = self;
        [self delegatePerformWillPresentImagePicker:imagePicker];
        [self.currentVisibleController presentViewController:imagePicker animated:YES completion:nil];
    }
}

@end

@implementation NSDictionary (FSMediaPicker)

- (UIImage *)originalImage
{
    if ([self.allKeys containsObject:UIImagePickerControllerOriginalImage]) {
        return self[UIImagePickerControllerOriginalImage];
    }
    return nil;
}

- (UIImage *)editedImage
{
    if ([self.allKeys containsObject:UIImagePickerControllerEditedImage]) {
        return self[UIImagePickerControllerEditedImage];
    }
    return nil;
}

- (UIImage *)circularEditedImage
{
    if ([self.allKeys containsObject:UIImagePickerControllerCircularEditedImage]) {
        return self[UIImagePickerControllerCircularEditedImage];
    }
    return nil;
}

- (UIImage *)hexagonalEditedImage
{
    if ([self.allKeys containsObject:UIImagePickerControllerHexagonalEditedImage]) {
        return self[UIImagePickerControllerHexagonalEditedImage];
    }
    return nil;
}

- (NSURL *)mediaURL
{
    if ([self.allKeys containsObject:UIImagePickerControllerMediaURL]) {
        return self[UIImagePickerControllerMediaURL];
    }
    return nil;
}

- (NSDictionary *)mediaMetadata
{
    if ([self.allKeys containsObject:UIImagePickerControllerMediaMetadata]) {
        return self[UIImagePickerControllerMediaMetadata];
    }
    return nil;
}

- (FSMediaType)mediaType
{
    if ([self.allKeys containsObject:UIImagePickerControllerMediaType]) {
        NSString *type = self[UIImagePickerControllerMediaType];
        if ([type isEqualToString:(NSString *)kUTTypeImage]) {
            return FSMediaTypePhoto;
        } else if ([type isEqualToString:(NSString *)kUTTypeMovie]) {
            return FSMediaTypeVideo;
        }
    }
    return FSMediaTypePhoto;
}

@end


@implementation UIImage (FSMediaPicker)

- (UIImage *)circularImage
{
    // This function returns a newImage, based on image, that has been:
    // - scaled to fit in (CGRect) rect
    // - and cropped within a circle of radius: rectWidth/2
    
    //Create the bitmap graphics context
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(self.size.width, self.size.height), NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //Get the width and heights
    CGFloat imageWidth = self.size.width;
    CGFloat imageHeight = self.size.height;
    CGFloat rectWidth = self.size.width;
    CGFloat rectHeight = self.size.height;
    
    //Calculate the scale factor
    CGFloat scaleFactorX = rectWidth/imageWidth;
    CGFloat scaleFactorY = rectHeight/imageHeight;
    
    //Calculate the centre of the circle
    CGFloat imageCentreX = rectWidth/2;
    CGFloat imageCentreY = rectHeight/2;
    
    // Create and CLIP to a CIRCULAR Path
    // (This could be replaced with any closed path if you want a different shaped clip)
    CGFloat radius = rectWidth/2;
    CGContextBeginPath (context);
    CGContextAddArc (context, imageCentreX, imageCentreY, radius, 0, 2*M_PI, 0);
    CGContextClosePath (context);
    CGContextClip (context);
    
    //Set the SCALE factor for the graphics context
    //All future draw calls will be scaled by this factor
    CGContextScaleCTM (context, scaleFactorX, scaleFactorY);
    
    // Draw the IMAGE
    CGRect myRect = CGRectMake(0, 0, imageWidth, imageHeight);
    [self drawInRect:myRect];
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

- (UIImage *)hexagonalImage {
    
    return [self hexagonalImage:[UIColor blackColor]];
}

- (UIImage *)hexagonalImage:(UIColor *)fillColor
{
    
    CGFloat imageWidth = self.size.width;
    CGFloat imageHeight = self.size.height;
    
    CGFloat hexRadius = MAX(imageWidth/2, imageHeight/2);
    
    CGSize newImageSize = CGSizeMake(hexRadius*2.f, hexRadius*2.f);
    
    CGPoint imageCenter = CGPointMake(hexRadius, hexRadius); //Calculate the center of the hexagon
    
    UIBezierPath *hexagonPath = [UIBezierPath bezierPath]; // Create the hexagon path
    [hexagonPath moveToPoint:CGPointMake(imageCenter.x + hexRadius, imageCenter.y + 0)];
    for (NSUInteger i = 0; i < 6; i++) {
        CGFloat theta = 2 * M_PI / 6 * i;
        CGFloat x = imageCenter.x + hexRadius * cosf(theta);
        CGFloat y = imageCenter.y + hexRadius * sinf(theta);
        [hexagonPath addLineToPoint:CGPointMake(x, y)];
    }
    [hexagonPath closePath];
    
    //Create the bitmap graphics context
    UIGraphicsBeginImageContextWithOptions(newImageSize, NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    
    // Create and CLIP to a HEXAGONAL Path
    CGContextBeginPath(context);
    CGContextAddPath(context, [hexagonPath CGPath]);
    CGContextClosePath(context);
    CGContextClip(context);
    
    
    // Fill the background
    CGContextSetFillColorWithColor(context, fillColor ? [fillColor CGColor] : [[UIColor blackColor] CGColor]);
    CGContextFillRect(context, CGRectMake(0.f, 0.f, newImageSize.width, newImageSize.height));
    
    //Set the SCALE factor for the graphics context
    //All future draw calls will be scaled by this factor
    CGContextScaleCTM (context, 1.f, 1.f);
    
    // Draw the IMAGE centered in the clipping path
    CGPoint origin = CGPointMake((2.f*hexRadius-imageWidth)/2.f, (2.f*hexRadius-imageHeight)/2.f);
    CGRect myRect = CGRectMake(origin.x, origin.y, imageWidth, imageHeight);
    [self drawInRect:myRect];
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

@end

const char * mediaPickerKey;

@implementation UIActionSheet (FSMediaPicker)

- (void)setMediaPicker:(FSMediaPicker *)mediaPicker
{
    objc_setAssociatedObject(self, &mediaPickerKey, mediaPicker, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (FSMediaPicker *)mediaPicker
{
    return objc_getAssociatedObject(self, &mediaPickerKey);
}

@end

@implementation UIAlertController (FSMediaPicker)

- (void)setMediaPicker:(FSMediaPicker *)mediaPicker
{
    objc_setAssociatedObject(self, &mediaPickerKey, mediaPicker, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (FSMediaPicker *)mediaPicker
{
    return objc_getAssociatedObject(self, &mediaPickerKey);
}


@end

@implementation FSImagePickerController (FSMediaPicker)

- (void)setMediaPicker:(FSMediaPicker *)mediaPicker
{
    objc_setAssociatedObject(self, &mediaPickerKey, mediaPicker, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (FSMediaPicker *)mediaPicker
{
    return objc_getAssociatedObject(self, &mediaPickerKey);
}


@end

@implementation FSImagePickerController

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

@end


