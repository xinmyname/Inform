//
//  IFCompilerOptions.m
//  Inform
//
//  Created by Andrew Hunter on 10/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import "IFCompilerOptions.h"

#import "IFCompiler.h"
#import "IFUtility.h"
#import "IFCompilerSettings.h"

@implementation IFCompilerOptions {
    IBOutlet NSPopUpButton* compilerVersion;
    IBOutlet NSButton* naturalInform;
}

- (instancetype) init {
	return [self initWithNibName: @"CompilerSettings"];
}

// = Misc info =

- (NSString*) title {
	return [IFUtility localizedString: @"Compiler Settings"];
}

// = Setting up =

- (void) updateFromCompilerSettings {
    IFCompilerSettings* settings = [self compilerSettings];

	// Natural Inform
	[naturalInform setState: [settings usingNaturalInform]?NSOnState:NSOffState];
}

- (void) setSettings {
    IFCompilerSettings* settings = [self compilerSettings];

	// Whether or not to use Natural Inform
	[settings setUsingNaturalInform: [naturalInform state]==NSOnState];
}

- (BOOL) enableForCompiler: (NSString*) compiler {
	// These settings are unsafe to change while using Natural Inform
	if ([compiler isEqualToString: IFCompilerNaturalInform])
		return NO;
	else
		return YES;
}

@end
