//
//  Created by Alex (alex@itlekt.com)
//  Copyright (c) 2015 ITlekt Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>

//
// OSMNode
//
@interface OSMNode : NSObject

@property(nonatomic, readonly) uint64_t osmid;					// unique identifier
@property(nonatomic, readonly) double latitude;					// node's latitude
@property(nonatomic, readonly) double longitude;				// node's longitude
@property(nonatomic, readonly) NSDictionary *tags;				// associated tags

- (instancetype)initWithID:(uint64_t)osmid latitude:(double)latitude longitude:(double)longitude tags:(NSDictionary *)tags;
+ (instancetype)nodeWithID:(uint64_t)osmid latitude:(double)latitude longitude:(double)longitude tags:(NSDictionary *)tags;

@end
