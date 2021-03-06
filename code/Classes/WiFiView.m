// The BSD 2-Clause License (aka "FreeBSD License")
// 
// Copyright (c) 2012, Benjamin Thiel
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met: 
// 
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer. 
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution. 
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
// ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//
//  WiFiView.m
//  snsrlog
//
//  Created by Benjamin Thiel on 20.05.11.
//

#import "WiFiView.h"

#define NUMBER_OF_LINES_DISPLAYED 3

//private methods
@interface WiFiView()

-(void)scrollAgain;

@property (nonatomic, retain) NSTimer *autoScrollTimer;

@end



@implementation WiFiView

@synthesize autoScrollTimer;

+(CGSize) preferredSize {
    
    return CGSizeMake(320, 45);
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        
        // create the wifi icon
        UIImage *compassImage = [UIImage imageNamed:@"wifi.png"];
        CGFloat iconSize = 45; //we assume an icon in shape of a square size=height=width
        CGFloat centeredIconY = roundf((self.bounds.size.height / 2) - (iconSize / 2));
        CGRect compassImageFrame = CGRectMake(5, centeredIconY, iconSize, iconSize);
        wifiIcon = [[UIImageView alloc] initWithFrame:compassImageFrame];
        wifiIcon.image = compassImage;
        wifiIcon.alpha = 1;
        
        [self addSubview:wifiIcon];
        
        //although the other LiveSubViews's left margin for text is 65, this is a UITextView instead of a UILabel as the others
        CGFloat leftMargin = 57;
        CGRect textRect = CGRectMake(leftMargin, 0, self.bounds.size.width - leftMargin, self.bounds.size.height);
        textView = [[UITextView alloc] initWithFrame:textRect];
        textView.font = [UIFont systemFontOfSize:12];
        textView.textColor = [UIColor whiteColor];
        textView.editable = NO;
        textView.backgroundColor = [UIColor clearColor];
        
        self.autoScrollTimer = nil;
        entryRanges = [[NSMutableArray alloc] init];
        
        [self addSubview:textView];
        
        [self updateWifiList:nil];
    }
    return self;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

- (void)dealloc
{
    self.autoScrollTimer = nil;
    [entryRanges release];
    [textView release];
    [super dealloc];
}

-(void)updateWifiList:(NSArray *)list {
    
    //stop the timer
    [self.autoScrollTimer invalidate];
    self.autoScrollTimer = nil;
    
    if (list == nil || list.count == 0) {
        
        textView.text = @"No WiFi networks found.";
        
        //scroll the text into visibility
        NSRange range = {0, [textView.text length]};
        [textView scrollRangeToVisible:range];
        
        
    } else {
        
        NSMutableString *result = [[NSMutableString alloc] init];
        [entryRanges removeAllObjects];
        currentScrollPositon = 0;
        int offset = 0;
        int entryNumber = 1;
        
        for (NSDictionary *item in list) {
            
            NSString *bssid = [item objectForKey:@"BSSID"];
            NSString *ssid = [item objectForKey:@"SSID_STR"];
            NSString *oneLine = [NSString stringWithFormat:@"%d: %@ %@\n", entryNumber, bssid, ssid?ssid:@"(hidden)"];
            entryNumber++;
            
            //memorize the range of one line of the result for scrolling
            int lengthOfLine = [oneLine length];
            NSRange currentRange = NSMakeRange(offset, lengthOfLine);
            offset += lengthOfLine;
            [entryRanges addObject:NSStringFromRange(currentRange)];
            
            [result appendString:oneLine];
        }
        
        textView.text = [result autorelease];
        
        //scrolling necessary? schedule the timer
        if ([entryRanges count] > NUMBER_OF_LINES_DISPLAYED) {
            
            self.autoScrollTimer = [NSTimer scheduledTimerWithTimeInterval:1
                                                                    target:self 
                                                                  selector:@selector(scrollAgain) 
                                                                  userInfo:nil
                                                                   repeats:YES];
        }
    }
}


-(void)scrollAgain {
    
    if (currentScrollPositon < ([entryRanges count] - NUMBER_OF_LINES_DISPLAYED + 1)) {
        
        NSString *rangeString = [entryRanges objectAtIndex:currentScrollPositon];
        NSRange range = NSRangeFromString(rangeString);
        [textView scrollRangeToVisible:range];
    }
    
    currentScrollPositon++;
    
    if (currentScrollPositon >= [entryRanges count]) currentScrollPositon = 0;
}

@end
