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
NSLocalizedStringFromTableInBundle(key, @"FSMediaPicker", [NSBundle bundleWithPath:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"FSMediaPicker.bundle"]], nil)

#define kTakePhotoString LocalizedString(@"Take photo")
#define kSelectPhotoFromLibraryString LocalizedString(@"Select photo from photo library")
#define kRecordVideoString LocalizedString(@"Record video")
#define kSelectVideoFromLibraryString LocalizedString(@"Select video from photo library")
#define kCancelString LocalizedString(@"Cancel")

NSString const * UIImagePickerControllerCircularEditedImage = @" UIImagePickerControllerCircularEditedImage;";
NSString const * UIImagePickerControllerHexagonalEditedImage = @" UIImagePickerControllerHexagonalEditedImage;";

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

#pragma mark - UIImagePickerControllerDelegate

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

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if ([viewController isKindOfClass:NSClassFromString(@"PLUIImageViewController")] && self.editMode && [navigationController.viewControllers count] == 3) {
        
        CGFloat screenHeight = [[UIScreen mainScreen] bounds].size.height;
        
        UIView *plCropOverlay = [[viewController.view.subviews objectAtIndex:1] subviews][0];
        
        plCropOverlay.hidden = YES;
        
        int position = 0;
        
        if (screenHeight == 568){
            position = 124;
        } else {
            position = 80;
        }
        
        BOOL isIpad = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
        
        if (!isIpad) {
            UILabel *moveLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, 320, 50)];
            [moveLabel setText:@"Move and Scale"];
            [moveLabel setTextAlignment:NSTextAlignmentCenter];
            [moveLabel setTextColor:[UIColor whiteColor]];
            [viewController.view addSubview:moveLabel];
        }
        
        switch (self.editMode) {
            case FSEditModeNone: // No editing of image 
            case FSEditModeStandard: // 0 will never occur
                break;
            
            case FSEditModeHexagon: {
                CAShapeLayer *hexagonLayer = [CAShapeLayer layer];
                CGFloat diameter = isIpad ? MAX(plCropOverlay.frame.size.width, plCropOverlay.frame.size.height) : MIN(plCropOverlay.frame.size.width, plCropOverlay.frame.size.height);
                
                CGRect rect = CGRectMake(0.0f, position, diameter, diameter);
                CGFloat radius = MAX(CGRectGetWidth(rect)/2, CGRectGetHeight(rect)/2);
                
                CGPoint center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
                
                UIBezierPath *hexagonPath = [UIBezierPath bezierPath];
                
                [hexagonPath moveToPoint:CGPointMake(center.x + radius, center.y)];
                
                for (NSUInteger i = 0; i < 6; i++) {
                    CGFloat theta = 2 * M_PI / 6 * i;
                    CGFloat x = center.x + radius * cosf(theta);
                    CGFloat y = center.y + radius * sinf(theta);
                    [hexagonPath addLineToPoint:CGPointMake(x, y)];
                }
                
                [hexagonPath closePath];
                [hexagonPath setUsesEvenOddFillRule:YES];
                [hexagonLayer setPath:[hexagonPath CGPath]];
                [hexagonLayer setFillColor:[[UIColor clearColor] CGColor]]; //clearColor
                
                CGFloat bottomBarHeight = isIpad ? 51 : 72;
                
                UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, diameter, screenHeight - bottomBarHeight) cornerRadius:0];
                [path appendPath:hexagonPath];
                [path setUsesEvenOddFillRule:YES];
                
                CAShapeLayer *fillLayer = [CAShapeLayer layer];
                fillLayer.name = @"fillLayer";
                fillLayer.path = path.CGPath;
                fillLayer.fillRule = kCAFillRuleEvenOdd;
                fillLayer.fillColor = [UIColor blackColor].CGColor;
                fillLayer.opacity = 0.5;
                [viewController.view.layer addSublayer:fillLayer];
                break;
            }
                
            case FSEditModeCircular: {
                CAShapeLayer *circleLayer = [CAShapeLayer layer];
                
                CGFloat diameter = isIpad ? MAX(plCropOverlay.frame.size.width, plCropOverlay.frame.size.height) : MIN(plCropOverlay.frame.size.width, plCropOverlay.frame.size.height);
                
                UIBezierPath *circlePath = [UIBezierPath bezierPathWithOvalInRect: CGRectMake(0.0f, position, diameter, diameter)];
                [circlePath setUsesEvenOddFillRule:YES];
                [circleLayer setPath:[circlePath CGPath]];
                [circleLayer setFillColor:[[UIColor clearColor] CGColor]];
                
                CGFloat bottomBarHeight = isIpad ? 51 : 72;
                
                UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, diameter, screenHeight - bottomBarHeight) cornerRadius:0];
                [path appendPath:circlePath];
                [path setUsesEvenOddFillRule:YES];
                
                CAShapeLayer *fillLayer = [CAShapeLayer layer];
                fillLayer.name = @"fillLayer";
                fillLayer.path = path.CGPath;
                fillLayer.fillRule = kCAFillRuleEvenOdd;
                fillLayer.fillColor = [UIColor blackColor].CGColor;
                fillLayer.opacity = 0.5;
                [viewController.view.layer addSublayer:fillLayer];
                break;
            }
        }
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
        dic[UIImagePickerControllerHexagonalEditedImage] = [dic[UIImagePickerControllerEditedImage] hexagonalImage:_fillColor];

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
            NSString *title = kTakePhotoString;
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

