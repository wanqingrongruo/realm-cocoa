////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

#import "RLMUnitTestHelper.h"
#import "RLMRealm_Private.h"
#import "RLMRealmConfiguration_Private.h"

@interface RLMUnitTestHelper ()

@property (nonatomic) BOOL usingInMemoryRealms;
@property (nonnull, nonatomic, copy) RLMRealmConfiguration *testConfig;
@property (nonatomic) dispatch_queue_t queue;

@end

@implementation RLMUnitTestHelper

- (instancetype)init {
    return [self initUsingInMemoryRealms:NO];
}

- (instancetype)initUsingInMemoryRealms:(BOOL)useInMemoryRealms {
    if (self = [super init]) {
        NSURL *url = nil;
        if (!useInMemoryRealms) {
            NSFileManager *manager = [NSFileManager defaultManager];
            NSError *error = nil;
            url = [manager URLForDirectory:NSCachesDirectory
                                         inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error];
            if (error) {
                NSLog(@"Cannot use on-disk Realms; switching to in-memory Realms (error: %@)", error);
                useInMemoryRealms = YES;
            }
        }

        // Create Realm configuration
        NSString *thisName = [NSString stringWithFormat:@"RLMUnitTestHelper-%@", [[NSUUID UUID] UUIDString]];
        RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
        if (useInMemoryRealms) {
            config.fileURL = [url URLByAppendingPathComponent:thisName];
        } else {
            config.inMemoryIdentifier = thisName;
        }
        self.testConfig = config;
        self.usingInMemoryRealms = useInMemoryRealms;
    }
    return self;
}

- (void)invokeTestWithBlock:(void (^)(void))invokeBlock {
    if (!invokeBlock) {
        NSAssert(NO, @"invokeTestWithBlock: cannot be called with a nil block");
    }
    @autoreleasepool {
        [RLMRealmConfiguration setDefaultConfiguration:self.testConfig];
    }
    @autoreleasepool {
        invokeBlock();
    }
    @autoreleasepool {
        if (self.queue) {
            dispatch_sync(self.queue, ^{});
            self.queue = nil;
        }
        [self _cleanup];
    }
}

// MARK: Dispatch

- (void)dispatch:(dispatch_block_t)block {
    if (!self.queue) {
        self.queue = dispatch_queue_create("test background queue", 0);
    }
    dispatch_async(self.queue, ^{
        @autoreleasepool {
            block();
        }
    });
}

- (void)dispatchAndWait:(dispatch_block_t)block {
    [self dispatch:block];
    dispatch_sync(self.queue, ^{});
}


// MARK: Private

- (void)_cleanup {
    [RLMRealm resetRealmState];
    if (!self.usingInMemoryRealms) {
        NSURL *fileURL = self.testConfig.fileURL;
        NSFileManager *manager = [NSFileManager defaultManager];
        [manager removeItemAtURL:fileURL error:nil];
        [manager removeItemAtURL:[fileURL URLByAppendingPathExtension:@".lock"] error:nil];
        // TODO: update this if we move the lock file into the .management dir
        [manager removeItemAtURL:[fileURL URLByAppendingPathExtension:@".note"] error:nil];
    }
}

@end
