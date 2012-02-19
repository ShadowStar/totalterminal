#include "TotalTerminal+Commands.h"
#include "Updater.h"

@implementation TotalTerminal (Commands)
-(IBAction) showTransparencyHelpPanel:(id)sender {
    AUTO_LOGGERF(@"sender=%@", sender);
    [NSApp beginSheet:transparencyHelpPanel modalForWindow:[[NSClassFromString (@"TTAppPrefsController")
                                                             sharedPreferencesController] window] modalDelegate:self didEndSelector:NULL contextInfo:nil];
}

-(IBAction) closeTransparencyHelpPanel:(id)sender {
    AUTO_LOGGERF(@"sender=%@", sender);
    [transparencyHelpPanel orderOut:nil];
    [NSApp endSheet:transparencyHelpPanel];
}

-(IBAction) uninstallMe:(id)sender {
    AUTO_LOGGERF(@"sender=%@", sender);
    NSAlert* alert = [[[NSAlert alloc] init] autorelease];

    [alert setIcon:alternativeDockIcon];
    [alert addButtonWithTitle:(@"Uninstall")];
    [alert addButtonWithTitle:(@"Cancel")];
    [alert setMessageText:(@"Really want to uninstall TotalTerminal?")];
    [alert setInformativeText:(@"This will launch an uninstall script which will remove TotalTerminal from this computer and restore your original Terminal behavior.")];
    [alert setAlertStyle:NSWarningAlertStyle];
    NSInteger returnCode = [alert runModal];
    if (returnCode == NSAlertFirstButtonReturn) {
        NSString* uninstallerPath =
            [[[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"TotalTerminal Uninstaller.app"] stringByStandardizingPath];
        [[NSWorkspace sharedWorkspace] launchApplication:uninstallerPath];
    }
}

-(IBAction) updateMe:(id)sender {
    AUTO_LOGGERF(@"sender=%@", sender);
    TTUpdater* updater = [TTUpdater sharedUpdater];

    if (!updater) return;

    [self refreshFeedURLInUpdater];
    [updater resetUpdateCycle];
    [updater checkForUpdates:sender];
}

-(void) togglePinVisor:(id)sender {
    AUTO_LOGGERF(@"sender=%@", sender);
    if (!window_) return;

    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    BOOL val = [ud boolForKey:@"TotalTerminalVisorPinned"];
    [ud setBool:(val ? NO:YES) forKey:@"TotalTerminalVisorPinned"];
}

-(IBAction) toggleVisor:(id)sender {
    AUTO_LOGGERF(@"sender=%@ isHidden=%d", sender, isHidden);
    if (!window_) {
        isHidden = YES;
        [self openVisor];
    }
    if (isHidden) {
        [self showVisor:false];
    } else {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"TotalTerminalVisorPinned"]) {
            // @dr_win @binaryage when will the #TF #Visor get the ability to be brought to front when pinned, rather than hiding and coming back?
            if (![self isCurrentylyActive]) {
                [NSApp activateIgnoringOtherApps:YES];
            }
            // imagine visor window + one classic terminal window, when classic window has key status, we want our visor window to steal key status first time the toggle is executed
            bool isKey = [window_ isKeyWindow];
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"TotalTerminalVisorForceHide"]) {
                // some users didn't like it, here is a workaround
                // https://github.com/binaryage/totalterminal/issues/21
                isKey = true;
            }
            if (isKey) {
                [self hideVisor:false];
            } else {
                [window_ makeKeyWindow];
            }
        } else {
            [self hideVisor:false];
        }
    }
}

-(IBAction) fullScreenToggle:(id)sender {
    AUTO_LOGGERF(@"sender=%@", sender);
    if (!window_) return;
    
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    BOOL val = [ud boolForKey:@"TotalTerminalVisorFullScreen"];
    [ud setBool:(val ? NO:YES) forKey:@"TotalTerminalVisorFullScreen"];
}

-(IBAction) showPrefs:(id)sender {
    AUTO_LOGGERF(@"sender=%@", sender);
    [NSApp activateIgnoringOtherApps:YES];
    id terminalApp = [NSClassFromString (@"TTApplication")sharedApplication];
    [terminalApp showPreferencesWindow:nil];
    id prefsController = [NSClassFromString (@"TTAppPrefsController")sharedPreferencesController];
    [prefsController SMETHOD (TTAppPrefsController, selectVisorPane)];
}

-(IBAction) visitHomepage:(id)sender {
    AUTO_LOGGERF(@"sender=%@", sender);
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://totalterminal.binaryage.com"]];
}

-(IBAction) chooseBackgroundComposition:(id)sender {
    AUTO_LOGGERF(@"sender=%@", sender);
    NSOpenPanel* panel = [NSOpenPanel openPanel];

    [panel setTitle:@"Select a Quartz Composer (qtz) file"];
    if ([panel runModalForTypes:[NSArray arrayWithObject:@"qtz"]]) {
        NSString* path = [panel filename];
        path = [path stringByAbbreviatingWithTildeInPath];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"TotalTerminalVisorUseBackgroundAnimation"];
        [[NSUserDefaults standardUserDefaults] setObject:path forKey:@"TotalTerminalVisorBackgroundAnimationFile"];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"TotalTerminalVisorUseBackgroundAnimation"];
    }
}

-(IBAction) exitMe:(id)sender {
    AUTO_LOGGERF(@"sender=%@", sender);
    [NSApp terminate:self];
}

-(IBAction) crashMe:(id)sender {
    AUTO_LOGGERF(@"sender=%@", sender);
    *((char*)0) = 0;
}

-(IBAction) createVisorProfile:(id)sender {
    AUTO_LOGGERF(@"sender=%@", sender);
    id profileManager = [NSClassFromString (@"TTProfileManager")sharedProfileManager];
    id visorProfile = [profileManager profileWithName:@"Visor"];
    if (visorProfile) {
        INFO(@"Visor profile already exists.");
        return;
    }

    // create visor profile in case it does not exist yet, use startup profile as a template
    id startupProfile = [profileManager startupProfile];
    visorProfile = [startupProfile copyWithZone:nil];

    // apply Darwin's preferred Visor settings
    NSData* plistData;
    NSString* error;
    NSPropertyListFormat format;
    id plist;

    NSString* filename = @"Visor-SnowLeopard";
    if (terminalVersion() >= FIRST_LION_VERSION) {
        filename = @"Visor-Lion";
    }

    NSString* path = [[NSBundle bundleForClass:[TotalTerminal class]] pathForResource:filename ofType:@"terminal"];
    plistData = [NSData dataWithContentsOfFile:path];
    plist = [NSPropertyListSerialization propertyListFromData:plistData mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&error];
    if (!plist) {
        LOG(@"Error reading plist from file '%s', error = '%s'", [path UTF8String], [error UTF8String]);
        [error release];
        [visorProfile release];
        return;
    }
    [visorProfile setPropertyListRepresentation:plist];

    // set profile into manager
    [profileManager setProfile:visorProfile forName:@"Visor"];
    [visorProfile release];

    // apply visor profile to the opening window
    TotalTerminal* tt = [TotalTerminal sharedInstance];
    if ([tt window]) {
        [[[tt window] windowController] applyProfileToAllShellsInWindow:visorProfile];
        [tt updatePreferencesUI];
    }
}

@end
