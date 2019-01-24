#import "EditFunnel.h"
#import <WMF/SessionSingleton.h>

static NSString *const kAppInstallIdKey = @"app_install_id";
static NSString *const kAnonKey = @"anon";
static NSString *const kTimestampKey = @"client_dt";
static NSString *const kWikidataDescriptionEdit = @"wikidataDescriptionEdit";
static NSString *const kActionKey = @"action";

@implementation EditFunnel

- (id)init {
    // https://meta.wikimedia.org/wiki/Schema:MobileWikiAppEdit
    self = [super initWithSchema:@"MobileWikiAppEdit" version:18115551];
    return self;
}

- (NSDictionary *)preprocessData:(NSDictionary *)eventData {
    NSMutableDictionary *dict = [eventData mutableCopy];
    // session token should be regenerated at every 'start' event
    if ([eventData[kActionKey] isEqualToString:@"start"]) {
        self.editSessionToken = [self singleUseUUID];
    }
    dict[@"session_token"] = self.editSessionToken;
    dict[kAnonKey] = self.isAnon;
    dict[kAppInstallIdKey] = self.appInstallID;
    dict[kTimestampKey] = self.timestamp;
    //dict[@"pageNS"] = @0; // @todo actually get the namespace...
    return [NSDictionary dictionaryWithDictionary:dict];
}

#pragma mark - EditFunnel methods

- (void)logStart {
    [self log:@{kActionKey: @"start"}];
}

- (void)logPreview {
    [self log:@{kActionKey: @"preview"}];
}

- (void)logEditSummaryTap:(NSString *)editSummaryTapped {
    [self log:@{kActionKey: @"editSummaryTap",
                @"editSummaryTapped": editSummaryTapped ? editSummaryTapped : @""}];
}

- (void)logSavedRevision:(int)revID {
    NSNumber *revIDNumber = [NSNumber numberWithInt:revID];
    [self log:@{kActionKey: @"saved",
                @"revID": (revIDNumber ? revIDNumber : @"")}];
}

- (void)logCaptchaShown {
    [self log:@{kActionKey: @"captchaShown"}];
}

- (void)logCaptchaFailure {
    [self log:@{kActionKey: @"captchaFailure"}];
}

- (void)logAbuseFilterWarning:(NSString *)name {
    [self log:@{kActionKey: @"abuseFilterWarning",
                @"abuseFilterName": (name ? name : @"")}];
}

- (void)logAbuseFilterError:(NSString *)name {
    [self log:@{kActionKey: @"abuseFilterError",
                @"abuseFilterName": (name ? name : @"")}];
}

- (void)logAbuseFilterWarningIgnore:(NSString *)name {
    [self log:@{kActionKey: @"abuseFilterWarningIgnore",
                @"abuseFilterName": (name ? name : @"")}];
}

- (void)logAbuseFilterWarningBack:(NSString *)name {
    [self log:@{kActionKey: @"abuseFilterWarningBack",
                @"abuseFilterName": (name ? name : @"")}];
}

- (void)logSaveAttempt {
    [self log:@{kActionKey: @"saveAttempt"}];
}

- (void)logError:(NSString *)code {
    [self log:@{kActionKey: @"error",
                @"errorText": (code ? code : @"")}];
}

- (void)logWikidataDescriptionEditStart:(BOOL)isEditingExistingDescription {
    [self log:@{kActionKey: @"start",
                kWikidataDescriptionEdit: [self wikidataDescriptionType:isEditingExistingDescription]}];
}

- (void)logWikidataDescriptionEditReady:(BOOL)isEditingExistingDescription {
    [self log:@{kActionKey: @"ready",
                kWikidataDescriptionEdit: [self wikidataDescriptionType:isEditingExistingDescription]}];
}

- (void)logWikidataDescriptionEditSaveAttempt:(BOOL)isEditingExistingDescription {
    [self log:@{kActionKey: @"saveAttempt",
                kWikidataDescriptionEdit: [self wikidataDescriptionType:isEditingExistingDescription]}];
}

- (void)logWikidataDescriptionEditSaved:(BOOL)isEditingExistingDescription {
    [self log:@{kActionKey: @"saved",
                kWikidataDescriptionEdit: [self wikidataDescriptionType:isEditingExistingDescription]}];
}

- (void)logWikidataDescriptionEditError:(BOOL)isEditingExistingDescription {
    [self log:@{kActionKey: @"error",
                kWikidataDescriptionEdit: [self wikidataDescriptionType:isEditingExistingDescription]}];
}

- (NSString *)wikidataDescriptionType:(BOOL)isEditingExistingWikidataDescription {
    return isEditingExistingWikidataDescription ? @"existing" : @"new";
}

@end
