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

@interface SPUISearchHeader : UIView 
@property (nonatomic,retain,readonly) UITextField * searchField;
@end

static BOOL hasCreatedSectionsOnce = NO;
static NSArray *sortedDisplayIdentifiers = nil;
static NSMutableArray *sectionIndexTitles = nil;
static NSMutableArray *sectionIndexes = nil;

static NSMutableArray* createSections() {
	HBLogDebug(@"Creating sections!");

	sectionIndexTitles = [[NSMutableArray array] retain];
	sectionIndexes = [[NSMutableArray array] retain];
	NSMutableArray *sortedDisplayNames = [NSMutableArray array];
	sectionIndexTitles = [[NSMutableArray array] retain];

	ALApplicationList *applications = [%c(ALApplicationList) sharedApplicationList];
	NSDictionary *appListResults = [applications applicationsFilteredUsingPredicate:nil onlyVisible:YES titleSortedIdentifiers:&sortedDisplayIdentifiers];
	[sortedDisplayIdentifiers retain];

	SPSearchResultSection *newSection = [[%c(SPSearchResultSection) alloc] init];
	[newSection setDisplayIdentifier:@"My Applications"];
	[newSection setCategory:@"My Applications"];
	[newSection setDomain:4];

	for(NSString *displayID in sortedDisplayIdentifiers) {
		//HBLogDebug(@"%@", displayID);
		NSString *displayName = [appListResults objectForKey:displayID];
		[sortedDisplayNames addObject:displayName];
		NSString * firstLetter = [[displayName substringWithRange:[displayName rangeOfComposedCharacterSequenceAtIndex:0]] uppercaseString];
  		NSCharacterSet *alphaSet = [NSCharacterSet letterCharacterSet];
		BOOL valid = [[firstLetter stringByTrimmingCharactersInSet:alphaSet] isEqualToString:@""];
		if(!valid) {
			firstLetter = @"#";
		}

  		if(![sectionIndexTitles containsObject:firstLetter]) {
  			[sectionIndexTitles addObject:firstLetter];
  			// now an index
  			[sectionIndexes addObject:[NSNumber numberWithInteger:[sortedDisplayNames indexOfObject:displayName]]];
  		}

		SPSearchResult *myOtherCustomThing = [[%c(SPSearchResult) alloc] init];
		[myOtherCustomThing setTitle:displayName];
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

	hasCreatedSectionsOnce = YES;

	HBLogDebug(@"has completed creation");
	return rar;
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
	HBLogDebug(@"adding sections");
	SPUISearchViewController *sharedvc = [%c(SPUISearchViewController) sharedInstance];
	if(![self shouldHideSection:arg1]) {
		sharedvc.isShowingListLauncher = NO;
		%orig;
	} else {
		sharedvc.isShowingListLauncher = YES;
		%orig(createSections());
	}
}

%end

%hook SPUISearchViewController
// -(id)init {
// 	%log;
// 	listLauncherSection = createSections();
// 	return %orig;
// }
- (BOOL)_hasResults {
	return YES;
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
		[headerView setMoreButtonVisible:NO];
		[headerView updateWithTitle:@"LISTLAUNCHER" section:0 isExpanded:YES];
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

	if(self.isShowingListLauncher && sortedDisplayIdentifiers && hasCreatedSectionsOnce) {
		HBLogDebug(@"sortedDisplayIdentifiers = %@", [sortedDisplayIdentifiers class]);
		return [sortedDisplayIdentifiers count];
	}
	
	return %orig;
}

%new
-(NSArray *)sectionIndexTitlesForTableView:(UITableView *)arg1 {
	%log;
	if(self.isShowingListLauncher && hasCreatedSectionsOnce && sectionIndexTitles) {
		//HBLogDebug(@"indexes = %@", sectionIndexTitles);
		HBLogDebug(@"sortedDisplayIdentifiers = %@", [sectionIndexTitles class]);

		return (NSArray *)[sectionIndexTitles copy];
	}
	return nil;
}

%new
-(int)tableView:(UITableView *)tableview sectionForSectionIndexTitle:(id)title atIndex:(int)index {
	%log;

	SPUISearchHeader *sheader = MSHookIvar<SPUISearchHeader *>(self, "_searchHeader");
	[sheader.searchField resignFirstResponder];

	if([title isEqualToString:@"#"]) return 0;
	[tableview scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:[[sectionIndexes objectAtIndex:index] integerValue] inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
	return 99999999; // this allows for scrolling without jumping to some random ass section
}


%end

%hook SPUISearchTableHeaderView
- (void)updateWithTitle:(id)arg1 section:(unsigned int)arg2 isExpanded:(BOOL)arg3 {
	%log;
	SPUISearchViewController *sharedvc = [%c(SPUISearchViewController) sharedInstance];
	if(sharedvc.isShowingListLauncher) {
		[self setMoreButtonVisible:NO];
		arg1 = @"LISTLAUNCHER";
		arg3 = YES;
	}
	%orig;
}
- (void)setMoreButtonVisible:(BOOL)arg1 {
		SPUISearchViewController *sharedvc = [%c(SPUISearchViewController) sharedInstance];

	if(sharedvc.isShowingListLauncher) {
		%orig(NO);
	} else {
		%orig;
	}
}
%end


%hook SPUISearchTableView
- (id)initWithFrame:(CGRect)frame style:(UITableViewStyle)style {
	%log;
	self = %orig;
	self.sectionIndexColor = [UIColor whiteColor]; // index text
	self.sectionIndexTrackingBackgroundColor = [UIColor clearColor]; //bg touched
	self.sectionIndexBackgroundColor = [UIColor clearColor]; //bg touched
	return self;
}
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

static id observer;
%ctor {
	dlopen("/Library/MobileSubstrate/DynamicLibraries/AppList.dylib", RTLD_NOW);
	dlopen("/Library/MobileSubstrate/DynamicLibraries/org.thebigboss.nearbynews.dylib", RTLD_NOW);
	// Wait to do UI stuff
	// http://iphonedevwiki.net/index.php/User:Uroboro#UI_usage
	observer = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
		object:nil queue:[NSOperationQueue mainQueue]
		usingBlock:^(NSNotification *notification) {
			if(!hasCreatedSectionsOnce) {
				HBLogDebug(@"Should be first create hopefully!");
				sortedDisplayIdentifiers = nil;
				sectionIndexTitles = [NSMutableArray array];
				sectionIndexes = [NSMutableArray array];
				createSections();
			}
		}
	];
}

%dtor {
	[[NSNotificationCenter defaultCenter] removeObserver:observer];
}