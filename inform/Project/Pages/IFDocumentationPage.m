//
//  IFDocumentationPage.m
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFDocumentationPage.h"
#import "IFJSProject.h"
#import "IFPreferences.h"
#import "IFMaintenanceTask.h"
#import "IFAppDelegate.h"
#import "IFUtility.h"
#import "IFExtensionsManager.h"
#import "IFProjectController.h"
#import "IFPageBarCell.h"

@implementation IFDocumentationPage {
    // The documentation view
    WebView* wView;										// The web view that displays the documentation

    // Page cells
    IFPageBarCell* contentsCell;						// The 'table of contents' cell
    IFPageBarCell* examplesCell;						// The 'Examples' cell
    IFPageBarCell* generalIndexCell;					// The 'General Index' cell
    NSDictionary* tabDictionary;                        // Maps URL paths to cells

    bool reloadingBecauseCensusCompleted;
}

// = Initialisation =

- (instancetype) initWithProjectController: (IFProjectController*) controller {
	self = [super initWithNibName: @"Documentation"
				projectController: controller];
	
	if (self) {
        reloadingBecauseCensusCompleted = false;

		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(fontSizePreferenceChanged:)
													 name: IFPreferencesAppFontSizeDidChangeNotification
												   object: [IFPreferences sharedPreferences]];
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(censusCompleted:)
													 name: IFCensusFinishedNotification
												   object: nil];
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(censusCompleted:)
													 name: IFCensusFinishedButDontUpdateExtensionsWebPageNotification
												   object: nil];

        // Create the view for the documentation tab
        wView = [[WebView alloc] init];
        [wView setTextSizeMultiplier: [[IFPreferences sharedPreferences] appFontSizeMultiplier]];
        [wView setResourceLoadDelegate: self];
        [wView setFrameLoadDelegate: self];

        [wView setFrame: [self.view bounds]];
        [wView setAutoresizingMask: (NSUInteger) (NSViewWidthSizable|NSViewHeightSizable)];
        [self.view addSubview: wView];

        NSURL* url = [NSURL URLWithString: @"inform:/index.html"];
        NSURLRequest* urlRequest = [[NSURLRequest alloc] initWithURL: url];
        [[wView mainFrame] loadRequest: urlRequest];

        [wView setPolicyDelegate: (id<WebPolicyDelegate>) [self.parent generalPolicy]];
        [wView setUIDelegate: (id<WebUIDelegate>) self.parent];
        [wView setHostWindow: [self.parent window]];

		contentsCell = [[IFPageBarCell alloc] initImageCell:[NSImage imageNamed:NSImageNameHomeTemplate]];
		[contentsCell setTarget: self];
		[contentsCell setAction: @selector(showToc:)];

		examplesCell = [[IFPageBarCell alloc] initTextCell: [IFUtility localizedString: @"Example Docs" default: @"Examples"]];
		[examplesCell setTarget: self];
		[examplesCell setAction: @selector(showExamples:)];

		generalIndexCell = [[IFPageBarCell alloc] initTextCell: [IFUtility localizedString: @"General Index Docs"
                                                                                   default: @"General Index"]];
		[generalIndexCell setTarget: self];
		[generalIndexCell setAction: @selector(showGeneralIndex:)];

        // Static dictionary mapping tab names to cells
        tabDictionary = @{@"inform:/index.html": contentsCell,
                          @"inform:/examples_alphabetical.html": examplesCell,
                          @"inform:/general_index.html": generalIndexCell};
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

// = Details about this view =

- (NSString*) title {
	return [IFUtility localizedString: @"Documentation Page Title"
                              default: @"Documentation"];
}

// = Updating extensions =

- (void) censusCompleted: (NSNotification*) not {
    reloadingBecauseCensusCompleted = true;
	// Force the documentation view to reload (the 'installed extensions' page may be updated)
	[wView reload: self];
    reloadingBecauseCensusCompleted = false;
}

// = Preferences =

- (void) fontSizePreferenceChanged: (NSNotification*) not {
	[wView setTextSizeMultiplier: [[IFPreferences sharedPreferences] appFontSizeMultiplier]];
}

// = Documentation =

- (void) openURL: (NSURL*) url  {
	[self switchToPage];
	
	[[wView mainFrame] loadRequest: [[NSURLRequest alloc] initWithURL: url]];
}

- (void) openURLWithString: (NSString*) urlString {
	if (urlString == nil) return;
	[self openURL: [NSURL URLWithString: urlString]];
}

- (void) highlightTabForURL:(NSString*) urlString {
    for (NSString*key in tabDictionary) {
        if( [key caseInsensitiveCompare:urlString] == NSOrderedSame ) {
            [(IFPageBarCell*) tabDictionary[key] setState:NSOnState];
        }
        else {
            [(IFPageBarCell*) tabDictionary[key] setState:NSOffState];
        }
    }
}

// = WebResourceLoadDelegate methods =

- (void)			webView:(WebView *)sender 
				   resource:(id)identifier 
	didFailLoadingWithError:(NSError *)error 
			 fromDataSource:(WebDataSource *)dataSource {
    NSString *urlString = (error.userInfo)[@"NSErrorFailingURLStringKey"];

    if (error.code == NSURLErrorCancelled) {
        //NSLog(@"IFDocumentationPage: load of URL %@ was cancelled", urlString);
        return;
    }
	NSLog(@"IFDocumentationPage: failed to load URL %@ with error: %@", urlString, [error localizedDescription]);
}

// = WebFrameLoadDelegate methods =

- (void)					webView:(WebView *)sender 
	didStartProvisionalLoadForFrame:(WebFrame *)frame {
    // When opening a new URL in the main frame, record it as part of the history for this page
    NSURL* url;
    if ([frame provisionalDataSource]) {
        url = [[[frame provisionalDataSource] request] URL];
    } else {
        url = [[[frame dataSource] request] URL];
    }
    
    url = [url copy];

    // Highlight appropriate tab
    [self highlightTabForURL:[url absoluteString]];

	if (frame == [wView mainFrame] && [self pageIsVisible]) {
        if( !reloadingBecauseCensusCompleted )
        {
            LogHistory(@"HISTORY: Documentation Page: (didStartProvisionalLoadForFrame) URL %@", [url absoluteString]);
            [[self history] switchToPage];
            [(IFDocumentationPage*)[self history] openURLWithString: [url absoluteString]];
        }
	}
}

- (void)        webView: (WebView *) sender
   didClearWindowObject: (WebScriptObject *) windowObject
               forFrame: (WebFrame *) frame {
	if (self.otherPane) {
		// Attach the JavaScript object to the opposing view
		IFJSProject* js = [[IFJSProject alloc] initWithPane: self.otherPane];
		
		// Attach it to the script object
		[[sender windowScriptObject] setValue: js
									   forKey: @"Project"];
	}
}

// = History =

- (void) didSwitchToPage {
	//[(IFDocumentationPage*)[self history] openURL: [[[[[[wView mainFrame] dataSource] request] URL] copy] autorelease]];
	WebFrame* frame = [wView mainFrame];
	NSURL* url;
	if ([frame provisionalDataSource]) {
		url = [[[frame provisionalDataSource] request] URL];
	} else {
		url = [[[frame dataSource] request] URL];
	}
	NSString* urlString = [url absoluteString];
	
    LogHistory(@"HISTORY: Documentation Page: (didSwitchToPage) URL %@", urlString);
	[[self history] openURLWithString: urlString];
}

// = Page bar cells =

- (NSArray*) toolbarCells {
	return @[generalIndexCell, examplesCell, contentsCell];
}

-(NSString*) urlStringForCell:(IFPageBarCell*) cell {
    for (NSString* key in tabDictionary) {
        if( tabDictionary[key] == cell ) {
            return key;
        }
    }
    return nil;
}

- (void) showToc: (id) sender {
	[self openURL: [NSURL URLWithString: [self urlStringForCell:contentsCell]]];
}

- (void) showExamples: (id) sender {
	[self openURL: [NSURL URLWithString: [self urlStringForCell:examplesCell]]];
}

- (void) showGeneralIndex: (id) sender {
	[self openURL: [NSURL URLWithString: [self urlStringForCell:generalIndexCell]]];
}

- (void) willClose {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

@end
