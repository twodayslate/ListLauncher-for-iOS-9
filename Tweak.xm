@interface ALApplicationList
+ (ALApplicationList *)sharedApplicationList;
- (NSDictionary *)applicationsFilteredUsingPredicate:(NSPredicate *)predicate onlyVisible:(BOOL)onlyVisible titleSortedIdentifiers:(NSArray **)outSortedByTitle;
- (id)valueForKey:(NSString *)key forDisplayIdentifier:(NSString *)displayIdentifier;
@end

@interface SPSearchResult : NSObject
@property (nonatomic,retain) NSString * fbr; 
@property (nonatomic,retain) NSString * templateName; 
@property (nonatomic,retain) NSString * card_title; 
@property (assign,nonatomic) int flags;                                                   //@synthesize flags=_flags - In the implementation block
-(void)setTitle:(NSString *)arg1 ;
-(void)setSearchResultDomain:(unsigned)arg1 ;
-(void)setBundleID:(NSString *)arg1 ;
-(void)setExternalIdentifier:(NSString *)arg1 ;
-(void)setHasAssociatedUserActivity:(BOOL)arg1 ;
-(void)setUserActivityEligibleForPublicIndexing:(BOOL)arg1 ;
-(void)setUrl:(NSString *)arg1 ;
@end

@interface SPSearchResultSection
@property (nonatomic, retain) NSString *displayIdentifier;
@property (nonatomic) unsigned int domain;
@property (nonatomic, retain) NSString *category;
- (void)addResults:(SPSearchResult *)arg1;
- (id)results;
- (id)resultsAtIndex:(unsigned int)arg1;
@end

@interface SPUISearchViewController : UIViewController
@property (assign, nonatomic) BOOL isShowingListLauncher;
@property (assign, nonatomic) BOOL isActuallyPullDown;
- (BOOL)_hasResults;
- (id)searchTableView;
+ (id)sharedInstance;
- (id)currentSearchModel;
- (void)_clearSearchResults;
- (void)_reloadTable;
- (BOOL)_isPullDownSpotlight;
- (BOOL)isZKWSearchMode;
- (BOOL)_hasNoQuery;
@end



@interface SPUISearchTableView : UITableView
- (BOOL)sectionIsExpanded:(int)arg1;
- (void)toggleExpansionForSection:(unsigned int)arg1;
@end

@class SPUISearchModel;
@interface SPUISearchModel 
+ (id)sharedFullZWKInstance;
+ (id)sharedGeneralInstance;
+ (id)sharedInstance;
+ (id)sharedPartialZKWInstance;
- (void)addSections:(NSMutableArray *)arg1;
- (void)handleHiddenResult:(id)arg1 shownResult:(id)arg2 inSection:(id)arg3;
- (void)clear;
- (void)clearInternal:(int)arg1;
- (void)clearParsecResultsIfStale;
- (void)searchDaemonQuery:(id)arg1 addedResults:(id)arg2;
- (BOOL)shouldHideSection:(NSMutableArray *)arg1;
@end

@interface SPUISearchTableHeaderView : UITableViewHeaderFooterView
@property (nonatomic, retain) UILabel *titleLabel;
- (void)setMoreButtonVisible:(BOOL)arg1;
- (void)setTitleLabel:(UILabel *)arg1;
- (void)updateWithTitle:(id)arg1 section:(unsigned int)arg2 isExpanded:(BOOL)arg3;
@end

static NSArray *sortedDisplayIdentifiers = nil;
static ALApplicationList *applications = nil;


static NSMutableArray* createSections() {
	applications = [%c(ALApplicationList) sharedApplicationList];
	[applications applicationsFilteredUsingPredicate:nil onlyVisible:YES titleSortedIdentifiers:&sortedDisplayIdentifiers];
	
	SPSearchResultSection *newSection = [[%c(SPSearchResultSection) alloc] init];
	[newSection setDisplayIdentifier:@"My Applications"];
	[newSection setCategory:@"My Applications"];
	[newSection setDomain:4];

	for(NSString *displayID in sortedDisplayIdentifiers) {
		//HBLogDebug(@"%@", displayID);
		SPSearchResult *myOtherCustomThing = [[%c(SPSearchResult) alloc] init];
		[myOtherCustomThing setTitle:[applications valueForKey:@"displayName" forDisplayIdentifier:displayID]];
		[myOtherCustomThing setSearchResultDomain:4];
		[myOtherCustomThing setBundleID:displayID];
		[myOtherCustomThing setExternalIdentifier:displayID];
		[myOtherCustomThing setUrl:displayID];
		myOtherCustomThing.templateName = @"generic";
		myOtherCustomThing.card_title = @"My Applications";
		[myOtherCustomThing setHasAssociatedUserActivity:NO];
		[myOtherCustomThing setUserActivityEligibleForPublicIndexing:NO];

		[newSection addResults:myOtherCustomThing];
	}

	NSMutableArray *rar = [NSMutableArray array];
	[rar addObject:newSection];

	return rar;
	// SPUISearchViewController *vc = [%c(SPUISearchViewController) sharedInstance];
	// SPUISearchModel *model = [vc currentSearchModel];
	// [vc _clearSearchResults];
	// [vc _reloadTable];
	// [model addSections:rar];

	//SPSearchResultSection *firstSection = [arg1 objectAtIndex:0];
	//[firstSection setDisplayIdentifier:@"My Apps"];
	//[arg1 replaceObjectAtIndex:0 withObject:firstSection];
}



//This works too but there are some annoying bugs that are too hard to fix correctly so I don't do this.
static BOOL canDeclare = NO;

%hook SPUISearchModel 

+ (id)sharedPartialZKWInstance {
	if(canDeclare) {
		return [self sharedFullZWKInstance];
	}
	canDeclare = YES;
	return %orig;	
}

%new 
-(BOOL)shouldHideSection:(NSMutableArray *)arg1 {
	SPUISearchViewController *sharedvc = [%c(SPUISearchViewController) sharedInstance];

	if([sharedvc _hasNoQuery]) {
		return YES;
	}

	if(![sharedvc _hasResults]) {
		SPSearchResultSection *firstSection = [arg1 objectAtIndex:0];
		if(firstSection.domain == 1) { // Web Search
			return YES;
		}
	}

	return NO;
}

- (void)addSections:(NSMutableArray *)arg1 {
	//%log;
	SPUISearchViewController *sharedvc = [%c(SPUISearchViewController) sharedInstance];
	if(![self shouldHideSection:arg1]) {
		sharedvc.isShowingListLauncher = NO;
		%orig;
	} else {
		NSMutableArray *newSections = createSections();
		sharedvc.isShowingListLauncher = YES;
		%orig(newSections);
	}
}

%end

%hook SPUISearchViewController

- (BOOL)_hasResults {
	return YES;
}
- (BOOL)_hasNoResultsForQuery {
	return NO;
}

%property (assign, nonatomic) BOOL isShowingListLauncher;
- (void)_didFinishPresenting {
	%log;
	%orig;

	if(self.isShowingListLauncher) {
		SPUISearchTableView *tableview = MSHookIvar<SPUISearchTableView *>(self, "_tableView");
		if(![tableview sectionIsExpanded:0]) {
			[tableview toggleExpansionForSection:0];
		}

		SPUISearchTableHeaderView *headerView = (SPUISearchTableHeaderView *) [tableview headerViewForSection:0];
		[headerView updateWithTitle:@"LISTLAUNCHER" section:0 isExpanded:YES];
		HBLogDebug(@"changed title here %@", headerView);
	}
}

- (BOOL)_showKeyboardOnPresentation {
	%log;
	if(self.isShowingListLauncher) {
		return NO;
	}
	return %orig;
}
- (int)numberOfPossibleRowsInSection:(int)arg1 {
	%log;
	if(self.isShowingListLauncher) {
		applications = [%c(ALApplicationList) sharedApplicationList];
		[applications applicationsFilteredUsingPredicate:nil onlyVisible:YES titleSortedIdentifiers:&sortedDisplayIdentifiers];
		HBLogDebug(@"number of possible rows = %d", (int)[sortedDisplayIdentifiers count]);
		return [sortedDisplayIdentifiers count];
	}
	return %orig;
	
}
%end

%hook SPUISearchTableHeaderView
- (void)updateWithTitle:(id)arg1 section:(unsigned int)arg2 isExpanded:(BOOL)arg3 {
	%log;
	SPUISearchViewController *sharedvc = [%c(SPUISearchViewController) sharedInstance];
	if(sharedvc.isShowingListLauncher) {
		arg1 = @"LISTLAUNCHER";
	}
	%orig;
}
%end


%hook SPUISearchTableView
- (void)clearExpansionState {
	%log;
	SPUISearchViewController *sharedvc = [%c(SPUISearchViewController) sharedInstance];
	if(!sharedvc.isShowingListLauncher) {
		%orig;
	}
}
- (void)setExpandedSections:(id)arg1 {
	%log;
	%orig;
}
- (void)toggleExpansionForSection:(unsigned int)arg1 {
	%log;
	%orig;
}
%end

// %hook SPUISearchViewController
// // - (BOOL)_hasNoQuery {
// // 	%log;
// // 	BOOL orig = %orig;
// // 	if(orig) {
// // 		setTheModel();
// // 	}
// // 	return %orig;
// // }

// - (id)countOfVisibleResultsInSection:(int)arg1 {
// 	%log;
// 	id origValue = %orig;
// 	HBLogDebug(@"original return value = %@", origValue);
// 	return %orig;
// }
// - (int)maxUnexpandedRowsInSection:(int)arg1 {
// 	%log;
// 	int origValue = %orig;
// 	HBLogDebug(@"original return value = %d", origValue);
// 	return %orig;
// }
// - (int)numberOfPossibleRowsInSection:(int)arg1 {
// 	%log;
// 	int origValue = %orig;
// 	HBLogDebug(@"original return value = %d", origValue);
// 	HBLogDebug(@"has results = %d", [self _hasResults]);
// 	applications = [%c(ALApplicationList) sharedApplicationList];
// 	[applications applicationsFilteredUsingPredicate:[NSPredicate predicateWithFormat:@"isSystemApplication = TRUE"] onlyVisible:YES titleSortedIdentifiers:&sortedDisplayIdentifiers];
// 	return [sortedDisplayIdentifiers count];
// }
// - (int)tableView:(id)arg1 numberOfRowsInSection:(int)arg2 {
// 	%log;
// 	int origValue = %orig;
// 	logTheThings();
// 	HBLogDebug(@"original return value = %d", origValue);
// 	return %orig;
// }
// - (BOOL)shouldShowMoreButtonForSection:(unsigned int)arg1 {
// 	return %orig;
// }
// %end

// %hook UITableViewCell
// %new
// -(void)updateClippingHeight:(id)arg1 {
// 	return;
// }
// %end

// %hook SpringBoard
// -(id)init {
// 	%log;
// 	if(applications && applications != nil) {
// 		applications = [%c(ALApplicationList) sharedApplicationList];
// 		[applications applicationsFilteredUsingPredicate:[NSPredicate predicateWithFormat:@"isSystemApplication = TRUE"] onlyVisible:YES titleSortedIdentifiers:&sortedDisplayIdentifiers];
// 	}
// 	return %orig;
// }
// %end

%ctor {
	dlopen("/Library/MobileSubstrate/DynamicLibraries/AppList.dylib", RTLD_NOW);
	dlopen("/Library/MobileSubstrate/DynamicLibraries/org.thebigboss.nearbynews.dylib", RTLD_NOW);
}