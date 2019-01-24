#import "WMFOnThisDayEventsFetcher.h"
#import "WMFFeedOnThisDayEvent.h"
#import <WMF/WMF-Swift.h>
#import <WMF/WMFLegacySerializer.h>

@interface WMFOnThisDayEventsFetcher ()

@property (nonatomic, strong) WMFSession *session;

@end

@implementation WMFOnThisDayEventsFetcher

- (instancetype)init {
    self = [super init];
    if (self) {
        self.session = [WMFSession shared];
    }
    return self;
}

+ (NSSet<NSString *> *)supportedLanguages {
    static dispatch_once_t onceToken;
    static NSSet<NSString *> *supportedLanguages;
    dispatch_once(&onceToken, ^{
        supportedLanguages = [NSSet setWithObjects:@"en", @"de", @"sv", @"fr", @"es", @"ru", @"pt", @"ar", nil];
    });
    return supportedLanguages;
}

- (void)fetchOnThisDayEventsForURL:(NSURL *)siteURL month:(NSUInteger)month day:(NSUInteger)day failure:(WMFErrorHandler)failure success:(void (^)(NSArray<WMFFeedOnThisDayEvent *> *announcements))success {
    NSParameterAssert(siteURL);
    if (siteURL == nil || siteURL.wmf_language == nil || ![[WMFOnThisDayEventsFetcher supportedLanguages] containsObject:siteURL.wmf_language] || month < 1 || day < 1) {
        NSError *error = [NSError wmf_errorWithType:WMFErrorTypeInvalidRequestParameters
                                           userInfo:nil];
        failure(error);
        return;
    }

    NSString *monthString = [NSString stringWithFormat:@"%lu", (unsigned long)month];
    NSString *dayString = [NSString stringWithFormat:@"%lu", (unsigned long)day];
    NSArray<NSString *> *path = @[@"feed", @"onthisday", @"events", monthString, dayString];
    NSURLComponents *components = [WMFConfiguration.current mobileAppsServicesAPIURLComponentsForHost:siteURL.host appendingPathComponents:path];
    [self.session getJSONDictionaryFromURL:components.URL ignoreCache:YES completionHandler:^(NSDictionary<NSString *,id> * _Nullable result, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            failure(error);
            return;
        }
        
        if (response.statusCode == 304) {
            failure([NSError wmf_errorWithType:WMFErrorTypeNoNewData userInfo:nil]);
            return;
        }
        
        NSError *serializerError = nil;
        NSArray *events = [WMFLegacySerializer modelsOfClass:[WMFFeedOnThisDayEvent class] fromArrayForKeyPath:@"events" inJSONDictionary:result error:&serializerError];
        if (serializerError) {
            failure(serializerError);
            return;
        }
        
        success(events);
    }];
}

@end
