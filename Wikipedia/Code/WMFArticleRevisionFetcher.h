@import Foundation;
@import WMF.WMFBlockDefinitions;
@import WMF.WMFLegacyFetcher;

@interface WMFArticleRevisionFetcher : WMFLegacyFetcher

- (NSURLSessionTask *)fetchLatestRevisionsForArticleURL:(NSURL *)articleURL
                                            resultLimit:(NSUInteger)numberOfResults
                                     endingWithRevision:(NSUInteger)revisionId
                                                failure:(WMFErrorHandler)failure
                                                success:(WMFSuccessIdHandler)success;

@end
