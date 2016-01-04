//
//  FSMediaPicker.h
//  Pods
//
//  Created by Wenchao Ding on 2/3/15.
//  f33chobits@gmail.com
//
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "FSImagePickerController.h"

#ifndef LocalizedStrings
#define LocalizedStrings(key) \
NSLocalizedStringFromTableInBundle(key, @"FSMediaPicker", [NSBundle bundleWithPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"FSMediaPicker.bundle"]], nil)
#endif

@class FSMediaPicker;

typedef enum {
    FSMediaTypePhoto = 0,
    FSMediaTypeVideo = 1,
    FSMediaTypeAll   = 2
} FSMediaType;

typedef enum {
    FSEditModeStandard = 0,
    FSEditModeCircular = 1,
    FSEditModeHexagon  = 2,
    FSEditModeNone     = 3
} FSEditMode;

UIKIT_EXTERN NSString const * UIImagePickerControllerCircularEditedImage;
UIKIT_EXTERN NSString const * UIImagePickerControllerHexagonalEditedImage;

@protocol FSMediaPickerDelegate <NSObject>

@required
- (void)mediaPicker:(FSMediaPicker *)mediaPicker didFinishWithMediaInfo:(NSDictionary *)mediaInfo;
@optional
- (void)mediaPicker:(FSMediaPicker *)mediaPicker willPresentImagePickerController:(FSImagePickerController *)imagePicker;
- (void)mediaPickerDidCancel:(FSMediaPicker *)mediaPicker;

@end

@interface FSMediaPicker : NSObject

@property (assign, nonatomic) FSMediaType mediaType;
@property (assign, nonatomic) FSEditMode  editMode;

@property (assign, nonatomic) id<FSMediaPickerDelegate> delegate;

@property (copy, nonatomic) void(^willPresentImagePickerBlock)(FSMediaPicker *mediaPicker, FSImagePickerController *imagePicker);
@property (copy, nonatomic) void(^finishBlock)(FSMediaPicker *mediaPicker, NSDictionary *mediaInfo);
@property (copy, nonatomic) void(^cancelBlock)(FSMediaPicker *mediaPicker);

- (instancetype)initWithDelegate:(id<FSMediaPickerDelegate>)delegate;

- (void)showFromView:(UIView *)view;
-(void)show;

@end

@interface NSDictionary (FSMediaPicker)

@property (readonly, nonatomic) UIImage      *originalImage;
@property (readonly, nonatomic) UIImage      *editedImage;
@property (readonly, nonatomic) NSURL        *mediaURL;
@property (readonly, nonatomic) NSDictionary *mediaMetadata;
@property (readonly, nonatomic) FSMediaType  mediaType;
@property (readonly, nonatomic) UIImage      *circularEditedImage;
@property (readonly, nonatomic) UIImage      *hexagonalEditedImage;

@end

@interface UIImage (FSMediaPicker)

- (UIImage *)circularImage;
- (UIImage *)hexagonalImage;

@end


/** 
 * @Purpose:
 *  Bind the life cylce of FSMediaPicker with UIActionSheet, UIAlertController and UIImagePickerControllr
 * @How
 *  Without these three categories, FSMediaPicker would release immediately, for example://
 *
 *  - (IBAction)buttonClicked:(id)sender
 *  {
 *      FSMediaPicker *mediaPicker = [[FSMediaPicker alloc] init];
 *      mediaPicker.delegate = self;
 *      [mediaPicker show];
 *  } <-- the mediaPicker will automatically release here
 *
 *  But with these categories
 *  1. UIActionSheet hold the mediaPicker, when UIActionSheet release the retain count decrease
 *  2. When UIActionSheet release, the mediaPicker should release, but the UIImagePickerController's appearing increase the retain count to 1
 *  3. When UIImagePickerController release, the retain count of mediaPicker would be zero if the viewController does not have a strong refrence to it
 *  This pattern breaks the original delegate a bit, because the traditional way is 'some class keep a weak reference to the delegate'. But this one keeps a strong. I write it in this way simply because it leads a simple usage. Any one has better idea ?
 */
 @interface UIActionSheet (FSMediaPicker)

@property (strong, nonatomic) FSMediaPicker *mediaPicker;

@end

@interface UIAlertController (FSMediaPicker)

@property (strong, nonatomic) FSMediaPicker *mediaPicker;

@end

@interface FSImagePickerController (FSMediaPicker)

@property (strong, nonatomic) FSMediaPicker *mediaPicker;

@end




