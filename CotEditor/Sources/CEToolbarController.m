/*
=================================================
CEToolbarController
(for CotEditor)

 Copyright (C) 2004-2007 nakamuxu.
 Copyright (C) 2014 CotEditor Project
 http://coteditor.github.io
=================================================

encoding="UTF-8"
Created:2005.01.07
 
-------------------------------------------------

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA. 


=================================================
*/

#import "CEToolbarController.h"
#import "CEDocumentController.h"
#import "constants.h"


@interface CEToolbarController ()

@property (nonatomic) NSToolbar *toolbar;

@property (nonatomic, unsafe_unretained) IBOutlet NSWindow *mainWindow;  // NSWindow は 10.7 では weak で持てないため
@property (nonatomic) IBOutlet NSPopUpButton *lineEndingPopupButton;// Outletだが、片付けられてしまうため strong
@property (nonatomic) IBOutlet NSPopUpButton *encodingPopupButton;// Outletだが、片付けられてしまうため strong
@property (nonatomic) IBOutlet NSPopUpButton *syntaxPopupButton;// Outletだが、片付けられてしまうため strong

@end




#pragma mark -

@implementation CEToolbarController

#pragma mark Public Method

//=======================================================
// Public method
//
//=======================================================

// ------------------------------------------------------
/// 後片付け
- (void)dealloc
// ------------------------------------------------------
{
    [[self toolbar] setDelegate:nil]; // デリゲート解除
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


// ------------------------------------------------------
/// ツールバーをセットアップ
- (void)setupToolbar
// ------------------------------------------------------
{
    [self setToolbar:[[NSToolbar alloc] initWithIdentifier:k_docWindowToolbarID]];
    
    // ユーザカスタマイズ可、コンフィグ内容を保存、アイコン+ラベルに設定
    [[self toolbar] setAllowsUserCustomization:YES];
    [[self toolbar] setAutosavesConfiguration:YES];
    [[self toolbar] setDisplayMode:NSToolbarDisplayModeIconAndLabel];
    // デリゲートを自身に指定
    [[self toolbar] setDelegate:self];
    // ウィンドウへ接続
    [[self mainWindow] setToolbar:[self toolbar]];
}


// ------------------------------------------------------
/// トグルアイテムの状態を更新
- (void)updateToggleItem:(NSString *)identifer setOn:(BOOL)setOn
// ------------------------------------------------------
{
    for (id item in [[self toolbar] items]) {
        if ([[item itemIdentifier] isEqualToString:identifer]) {
            [self doUpdateToggleItem:item setOn:setOn];
            break;
        }
    }
}


// ------------------------------------------------------
/// エンコーディングポップアップアイテムを生成
- (void)buildEncodingPopupButton
// ------------------------------------------------------
{
    NSArray *items = [[NSArray alloc] initWithArray:[[NSApp delegate] encodingMenuItems] copyItems:YES];
    
    [[self encodingPopupButton] removeAllItems];
    for (NSMenuItem *item in items) {
        [item setAction:@selector(setEncoding:)];
        [item setTarget:nil];
        [[[self encodingPopupButton] menu] addItem:item];
    }
}


// ------------------------------------------------------
/// エンコーディングポップアップの選択項目を設定
- (void)setSelectEncoding:(NSInteger)encoding
// ------------------------------------------------------
{
    for (NSMenuItem *menuItem in [[self encodingPopupButton] itemArray]) {
        if ([menuItem tag] == encoding) {
            [[self encodingPopupButton] selectItem:menuItem];
            break;
        }
    }
}


// ------------------------------------------------------
/// 改行コードポップアップの選択項目を設定
- (void)setSelectEndingItemIndex:(NSInteger)index
// ------------------------------------------------------
{
    NSInteger max = [[[self lineEndingPopupButton] itemArray] count];
    if ((index < 0) || (index >= max)) { return; }

    [[self lineEndingPopupButton] selectItemAtIndex:index];
}


// ------------------------------------------------------
/// シンタックスカラーリングポップアップアイテムを生成
- (void)buildSyntaxPopupButton
// ------------------------------------------------------
{
    NSArray *styleNames = [[CESyntaxManager sharedManager] styleNames];
    NSString *title = [[self syntaxPopupButton] titleOfSelectedItem];
    
    [[self syntaxPopupButton] removeAllItems];
    [[[self syntaxPopupButton] menu] addItemWithTitle:NSLocalizedString(@"None", nil)
                                               action:@selector(changeSyntaxStyle:)
                                        keyEquivalent:@""];
    [[[self syntaxPopupButton] menu] addItem:[NSMenuItem separatorItem]];
    for (NSString *styleName in styleNames) {
        [[[self syntaxPopupButton] menu] addItemWithTitle:styleName
                                                   action:@selector(changeSyntaxStyle:)
                                            keyEquivalent:@""];
    }
    
    [self selectSyntaxItemWithTitle:title];
}


// ------------------------------------------------------
/// シンタックスカラーリングポップアップの選択項目をタイトル名で設定
- (void)selectSyntaxItemWithTitle:(NSString *)title
// ------------------------------------------------------
{
    NSMenuItem *menuItem = [[self syntaxPopupButton] itemWithTitle:title];
    if (menuItem) {
        [[self syntaxPopupButton] selectItem:menuItem];
    } else {
        [[self syntaxPopupButton] selectItemAtIndex:0]; // "None" を選択
    }
}



#pragma mark Protocol

//=======================================================
// NSNibAwaking Protocol
//
//=======================================================

// ------------------------------------------------------
/// Nibファイル読み込み直後
- (void)awakeFromNib
// ------------------------------------------------------
{
    [self buildEncodingPopupButton];
    [self buildSyntaxPopupButton];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(buildSyntaxPopupButton)
                                                 name:CESyntaxListDidUpdateNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(buildEncodingPopupButton)
                                                 name:CEEncodingListDidUpdateNotification
                                               object:nil];
}



#pragma mark Delegate and Notification

//=======================================================
// Delegate method (NSToolbar)
//  <== toolbar
//=======================================================

// ------------------------------------------------------
/// ツールバーアイテムを返す
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
// ------------------------------------------------------
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];

    // Get Info (target = FirstResponder)
    if ([itemIdentifier isEqualToString:k_getInfoItemID]) {
        [toolbarItem setLabel:NSLocalizedString(@"Get Info",@"")];
        [toolbarItem setPaletteLabel:NSLocalizedString(@"Get Info",@"")];
        [toolbarItem setToolTip:NSLocalizedString(@"Show document information",@"")];
        [toolbarItem setImage:[NSImage imageNamed:@"getInfo"]];
        [toolbarItem setAction:@selector(getInfo:)];

    // Show Incompatible Char (target = FirstResponder)
    } else if ([itemIdentifier isEqualToString:k_showIncompatibleCharItemID]) {
        [toolbarItem setLabel:NSLocalizedString(@"Incompatible Chars",@"")];
        [toolbarItem setPaletteLabel:NSLocalizedString(@"Show Incompatible Chars",@"")];
        [toolbarItem setToolTip:NSLocalizedString(@"Show incompatible chars for selected encoding",@"")];
        [toolbarItem setImage:[NSImage imageNamed:@"IncompatibleChar"]];
        [toolbarItem setAction:@selector(toggleIncompatibleCharList:)];

    // Bigger Font
    } else if ([itemIdentifier isEqualToString:k_biggerFontItemID]) {
        [toolbarItem setLabel:NSLocalizedString(@"Bigger",@"")];
        [toolbarItem setPaletteLabel:NSLocalizedString(@"Bigger Font",@"")];
        [toolbarItem setToolTip:NSLocalizedString(@"Increases font size",@"")];
        [toolbarItem setImage:[NSImage imageNamed:@"biggerFont"]];
        [toolbarItem setTarget:[NSFontManager sharedFontManager]];
        [toolbarItem setAction:@selector(modifyFont:)];
        [toolbarItem setTag:NSSizeUpFontAction];

    // Smaller Font
    } else if ([itemIdentifier isEqualToString:k_smallerFontItemID]) {
        [toolbarItem setLabel:NSLocalizedString(@"Smaller",@"")];
        [toolbarItem setPaletteLabel:NSLocalizedString(@"Smaller Font",@"")];
        [toolbarItem setToolTip:NSLocalizedString(@"Decreases font size",@"")];
        [toolbarItem setImage:[NSImage imageNamed:@"smallerFont"]];
        [toolbarItem setTarget:[NSFontManager sharedFontManager]];
        [toolbarItem setAction:@selector(modifyFont:)];
        [toolbarItem setTag:NSSizeDownFontAction];

    // Shift Left (target = FirstResponder)
    } else if ([itemIdentifier isEqualToString:k_shiftLeftItemID]) {
        [toolbarItem setLabel:NSLocalizedString(@"Shift Left",@"")];
        [toolbarItem setPaletteLabel:NSLocalizedString(@"Shift Left",@"")];
        [toolbarItem setToolTip:NSLocalizedString(@"Shift lines to left",@"")];
        [toolbarItem setImage:[NSImage imageNamed:@"Shift_Left"]];
        [toolbarItem setAction:@selector(shiftLeft:)];

    // Shift Right (target = FirstResponder)
    } else if ([itemIdentifier isEqualToString:k_shiftRightItemID]) {
        [toolbarItem setLabel:NSLocalizedString(@"Shift Right",@"")];
        [toolbarItem setPaletteLabel:NSLocalizedString(@"Shift Right",@"")];
        [toolbarItem setToolTip:NSLocalizedString(@"Shift lines to right",@"")];
        [toolbarItem setImage:[NSImage imageNamed:@"Shift_Right"]];
        [toolbarItem setAction:@selector(shiftRight:)];
        
        // Auto Tab Expand (target = FirstResponder)
    } else if ([itemIdentifier isEqualToString:k_autoTabExpandItemID]) {
        [toolbarItem setLabel:NSLocalizedString(@"Expand Tabs",@"")];
        [toolbarItem setPaletteLabel:NSLocalizedString(@"Toggle Auto Tab Expand",@"")];
        [toolbarItem setToolTip:NSLocalizedString(@"Toggle auto tab expand",@"")];
        [self doUpdateToggleItem:toolbarItem setOn:[defaults boolForKey:k_key_autoExpandTab]];
        [toolbarItem setAction:@selector(toggleAutoTabExpand:)];

    // Show Navigation Bar (target = FirstResponder)
    } else if ([itemIdentifier isEqualToString:k_showNavigationBarItemID]) {
        [toolbarItem setLabel:NSLocalizedString(@"Navigation Bar",@"")];
        [toolbarItem setPaletteLabel:NSLocalizedString(@"Show / Hide Navigation Bar",@"")];
        [toolbarItem setToolTip:NSLocalizedString(@"Show or hide navigation bar of window",@"")];
        [self doUpdateToggleItem:toolbarItem setOn:[defaults boolForKey:k_key_showNavigationBar]];
        [toolbarItem setAction:@selector(toggleShowNavigationBar:)];

    // Show Line Num (target = FirstResponder)
    } else if ([itemIdentifier isEqualToString:k_showLineNumItemID]) {
        [toolbarItem setLabel:NSLocalizedString(@"LineNum",@"")];
        [toolbarItem setPaletteLabel:NSLocalizedString(@"Show / Hide Line Number",@"")];
        [toolbarItem setToolTip:NSLocalizedString(@"Show or hide line number of text",@"")];
        [self doUpdateToggleItem:toolbarItem setOn:[defaults boolForKey:k_key_showLineNumbers]];
        [toolbarItem setAction:@selector(toggleShowLineNum:)];

    // Show Status Bar (target = FirstResponder)
    } else if ([itemIdentifier isEqualToString:k_showStatusBarItemID]) {
        [toolbarItem setLabel:NSLocalizedString(@"Status Bar",@"")];
        [toolbarItem setPaletteLabel:NSLocalizedString(@"Show / Hide Status Bar",@"")];
        [toolbarItem setToolTip:NSLocalizedString(@"Show or hide status bar of window",@"")];
        [self doUpdateToggleItem:toolbarItem setOn:[defaults boolForKey:k_key_showStatusBar]];
        [toolbarItem setAction:@selector(toggleShowStatusBar:)];

    // Show Invisible Characters (target = FirstResponder)
    } else if ([itemIdentifier isEqualToString:k_showInvisibleCharsItemID]) {
        BOOL canActivate = [[[[self mainWindow] windowController] document] canActivateShowInvisibleCharsItem];

        [toolbarItem setLabel:NSLocalizedString(@"Invisible Chars",@"")];
        [toolbarItem setPaletteLabel:NSLocalizedString(@"Show / Hide Invisible Chars",@"")];
        // ツールバーアイテムを有効化できなければツールチップを変更
        if (canActivate) {
            [toolbarItem setToolTip:NSLocalizedString(@"Show or hide invisible characters in text",@"")];
            [self doUpdateToggleItem:toolbarItem setOn:YES];
            [toolbarItem setAction:@selector(toggleShowInvisibleChars:)];
        } else {
            [toolbarItem setToolTip:NSLocalizedString(@"To display invisible characters, set in Preferences and re-open the document.",@"")];
            [self doUpdateToggleItem:toolbarItem setOn:NO];
            [toolbarItem setAction:nil];
        }

    // Show Page Guide (target = FirstResponder)
    } else if ([itemIdentifier isEqualToString:k_showPageGuideItemID]) {
        [toolbarItem setLabel:NSLocalizedString(@"Page Guide",@"")];
        [toolbarItem setPaletteLabel:NSLocalizedString(@"Show / Hide Page Guide",@"")];
        [toolbarItem setToolTip:NSLocalizedString(@"Show or hide page guide line",@"")];
        [self doUpdateToggleItem:toolbarItem setOn:[defaults boolForKey:k_key_showPageGuide]];
        [toolbarItem setAction:@selector(toggleShowPageGuide:)];

    // Wrap lines (target = FirstResponder)
    } else if ([itemIdentifier isEqualToString:k_wrapLinesItemID]) {
        [toolbarItem setLabel:NSLocalizedString(@"Wrap lines",@"")];
        [toolbarItem setPaletteLabel:NSLocalizedString(@"Toggle Wrap Lines",@"")];
        [toolbarItem setToolTip:NSLocalizedString(@"Toggle wrap lines",@"")];
        [self doUpdateToggleItem:toolbarItem setOn:[defaults boolForKey:k_key_wrapLines]];
        [toolbarItem setAction:@selector(toggleWrapLines:)];

    // Line Endings (target = FirstResponder)
    } else if ([itemIdentifier isEqualToString:k_lineEndingsItemID]) {
        [toolbarItem setLabel:NSLocalizedString(@"Line Endings",@"")];
        [toolbarItem setPaletteLabel:NSLocalizedString(@"Line Endings",@"")];
        [toolbarItem setToolTip:NSLocalizedString(@"Line Endings",@"")];
        [toolbarItem setView:[self lineEndingPopupButton]];
        [toolbarItem setMinSize:[[self lineEndingPopupButton] bounds].size];
        [toolbarItem setMaxSize:[[self lineEndingPopupButton] bounds].size];

    // File Encoding (target = FirstResponder)
    } else if ([itemIdentifier isEqualToString:k_fileEncodingsItemID]) {

        [toolbarItem setLabel:NSLocalizedString(@"File Encoding",@"")];
        [toolbarItem setPaletteLabel:NSLocalizedString(@"File Encoding",@"")];
        [toolbarItem setToolTip:NSLocalizedString(@"File Encoding",@"")];
        [toolbarItem setView:[self encodingPopupButton]];
        [toolbarItem setMinSize:[[self encodingPopupButton] bounds].size];
        [toolbarItem setMaxSize:[[self encodingPopupButton] bounds].size];

    // Syntax Style (target = FirstResponder)
    } else if ([itemIdentifier isEqualToString:k_syntaxItemID]) {

        [toolbarItem setLabel:NSLocalizedString(@"Syntax Style",@"")];
        [toolbarItem setPaletteLabel:NSLocalizedString(@"Syntax Style",@"")];
        [toolbarItem setToolTip:NSLocalizedString(@"Syntax Style",@"")];
        [toolbarItem setView:[self syntaxPopupButton]];
        [toolbarItem setMinSize:[[self syntaxPopupButton] bounds].size];
        [toolbarItem setMaxSize:[[self syntaxPopupButton] bounds].size];

    // Re-color All (target = FirstResponder)
    } else if ([itemIdentifier isEqualToString:k_syntaxReColorAllItemID]) {
        [toolbarItem setLabel:NSLocalizedString(@"Re-Color",@"")];
        [toolbarItem setPaletteLabel:NSLocalizedString(@"Re-Color All",@"")];
        [toolbarItem setToolTip:NSLocalizedString(@"Do re-color whole document",@"")];
        [toolbarItem setImage:[NSImage imageNamed:@"RecolorAll"]];
        [toolbarItem setAction:@selector(recoloringAllStringOfDocument:)];
        
        // Edit Color Code (target = FirstResponder)
    } else if ([itemIdentifier isEqualToString:k_editColorCodeItemID]) {
        [toolbarItem setLabel:NSLocalizedString(@"Color Code",@"")];
        [toolbarItem setPaletteLabel:NSLocalizedString(@"Edit Color Code",@"")];
        [toolbarItem setToolTip:NSLocalizedString(@"Open Color Code Editor and set selection as color code",@"")];
        [toolbarItem setImage:[NSImage imageNamed:@"EditColorCode"]];
        [toolbarItem setAction:@selector(editColorCode:)];

    } else {
        toolbarItem = nil;
    }
    return toolbarItem;
}


// ------------------------------------------------------
/// 設定画面でのツールバーアイテム配列を返す
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
// ------------------------------------------------------
{
    return @[k_getInfoItemID, 
             k_showIncompatibleCharItemID,
             NSToolbarPrintItemIdentifier,  
             NSToolbarShowFontsItemIdentifier, 
             k_biggerFontItemID, 
             k_smallerFontItemID, 
             k_shiftLeftItemID, 
             k_shiftRightItemID,
             k_autoTabExpandItemID,
             k_showNavigationBarItemID, 
             k_showLineNumItemID, 
             k_showStatusBarItemID, 
             k_showInvisibleCharsItemID, 
             k_showPageGuideItemID, 
             k_wrapLinesItemID,
             k_lineEndingsItemID, 
             k_fileEncodingsItemID, 
             k_syntaxItemID, 
             k_syntaxReColorAllItemID,
             k_editColorCodeItemID,
             NSToolbarSeparatorItemIdentifier, 
             NSToolbarFlexibleSpaceItemIdentifier, 
             NSToolbarSpaceItemIdentifier, 
             NSToolbarCustomizeToolbarItemIdentifier];
}


// ------------------------------------------------------
/// ツールバーアイテムデフォルト配列を返す
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
// ------------------------------------------------------
{
    return @[k_lineEndingsItemID, 
             k_fileEncodingsItemID, 
             k_syntaxItemID, 
             NSToolbarFlexibleSpaceItemIdentifier, 
             k_getInfoItemID];
}



#pragma mark Private Methods

//=======================================================
// Private method
//
//=======================================================

// ------------------------------------------------------
/// トグルアイテムの状態を更新
- (void)doUpdateToggleItem:(NSToolbarItem *)item setOn:(BOOL)setOn
// ------------------------------------------------------
{
    NSString *identifer = [item itemIdentifier];
    NSString *imageName;
    if ([identifer isEqualToString:k_showNavigationBarItemID]) {
        imageName = setOn ? @"NaviBar_Show" : @"NaviBar_Hide";
        
    } else if ([identifer isEqualToString:k_showLineNumItemID]) {
        imageName = setOn ? @"LineNumber_Show" : @"LineNumber_Hide";
        
    } else if ([identifer isEqualToString:k_showStatusBarItemID]) {
        imageName = setOn ? @"StatusArea_Show" : @"StatusArea_Hide";
        
    } else if ([identifer isEqualToString:k_showInvisibleCharsItemID]) {
        imageName = setOn ? @"InvisibleChar_Show" : @"InvisibleChar_Hide";
        
    } else if ([identifer isEqualToString:k_showPageGuideItemID]) {
        imageName = setOn ? @"PageGuide_Show" : @"PageGuide_Hide";
        
    } else if ([identifer isEqualToString:k_wrapLinesItemID]) {
        imageName = setOn ? @"WrapLines_On" : @"WrapLines_Off";
        
    } else if ([identifer isEqualToString:k_autoTabExpandItemID]) {
        imageName = setOn ? @"AutoTabExpand_On" : @"AutoTabExpand_Off";
    }
    
    if (imageName) {
        [item setImage:[NSImage imageNamed:imageName]];
    }
}

@end
