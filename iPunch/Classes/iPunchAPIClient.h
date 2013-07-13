#import "AFIncrementalStore.h"
#import "AFRestClient.h"

@interface iPunchAPIClient : AFRESTClient <AFIncrementalStoreHTTPClient>

+ (iPunchAPIClient *)sharedClient;

@end
