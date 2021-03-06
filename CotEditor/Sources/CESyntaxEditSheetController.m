/*
 =================================================
 CESyntaxEditSheetController
 (for CotEditor)
 
 Copyright (C) 2004-2007 nakamuxu.
 Copyright (C) 2014 CotEditor Project
 http://coteditor.github.io
 =================================================
 
 encoding="UTF-8"
 Created:2014.04.03 by 1024jp
 
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

#import "CESyntaxEditSheetController.h"
#import "CESyntaxManager.h"
#import "CEMenuItemCell.h"
#import "constants.h"


@interface CESyntaxEditSheetController ()

@property (nonatomic) NSMutableDictionary *style;  // スタイル定義（NSArrayControllerを通じて操作）
@property (nonatomic) CESyntaxEditSheetMode mode;
@property (nonatomic, copy) NSString *originalStyleName;   // シートを生成した際に指定したスタイル名
@property (nonatomic) BOOL isStyleNameValid;

@property (nonatomic, weak) IBOutlet NSTableView *menuTableView;
@property (nonatomic, weak) IBOutlet NSTextField *styleNameField;
@property (nonatomic, weak) IBOutlet NSTextField *messageField;
@property (nonatomic, weak) IBOutlet NSButton *factoryDefaultsButton;
@property (nonatomic, strong) IBOutlet NSTextView *validationTextView;  // on 10.8 NSTextView cannot be weak

@property (nonatomic) NSUInteger selectedDetailTag; // Elementsタブでのポップアップメニュー選択用バインディング変数(#削除不可)

@end




#pragma mark -

@implementation CESyntaxEditSheetController

#pragma mark Superclass Methods

//=======================================================
// Superclass method
//
//=======================================================

// ------------------------------------------------------
/// 初期化
- (instancetype)initWithStyle:(NSString *)styleName mode:(CESyntaxEditSheetMode)mode
// ------------------------------------------------------
{
    self = [super initWithWindowNibName:@"SyntaxEditSheet"];
    if (self) {
        NSMutableDictionary *style;
        NSString *name;
        
        switch (mode) {
            case CECopySyntaxEdit:
                style = [[[CESyntaxManager sharedManager] styleWithStyleName:styleName] mutableCopy];
                name = [[CESyntaxManager sharedManager] copiedStyleName:style[k_SCKey_styleName]];
                style[k_SCKey_styleName] = name;
                break;
                
            case CENewSyntaxEdit:
                style = [[[CESyntaxManager sharedManager] emptyStyle] mutableCopy];
                name = @"";
                break;
                
            case CESyntaxEdit:
                style = [[[CESyntaxManager sharedManager] styleWithStyleName:styleName] mutableCopy];
                name = style[k_SCKey_styleName];
                break;
        }
        if (!name) { return nil; }
        
        [self setMode:mode];
        [self setOriginalStyleName:name];
        [self setStyle:style];
        [self setIsStyleNameValid:YES];
    }
    
    return self;
}

// ------------------------------------------------------
/// ウインドウロード直後
- (void)windowDidLoad
// ------------------------------------------------------
{
    [super windowDidLoad];
    
    NSString *styleName = [self originalStyleName];
    BOOL isDefaultSyntax = [[CESyntaxManager sharedManager] isBundledStyle:styleName];
    
    [[self styleNameField] setStringValue:styleName];
    [[self styleNameField] setDrawsBackground:!isDefaultSyntax];
    [[self styleNameField] setBezeled:!isDefaultSyntax];
    [[self styleNameField] setSelectable:!isDefaultSyntax];
    [[self styleNameField] setEditable:!isDefaultSyntax];
    
    if (isDefaultSyntax) {
        BOOL isEqual = [[CESyntaxManager sharedManager] isEqualToBundledStyle:[self style] name:styleName];
        [[self styleNameField] setBordered:YES];
        [[self messageField] setStringValue:NSLocalizedString(@"Name of the bundled style cannot be changed.", nil)];
        [[self factoryDefaultsButton] setEnabled:!isEqual];
    } else {
        [[self messageField] setStringValue:@""];
        [[self factoryDefaultsButton] setEnabled:NO];
    }
}



#pragma mark Delegate and Notification

//=======================================================
// Delegate method (NSTextField)
//  <== styleNameField
//=======================================================

// ------------------------------------------------------
/// スタイル名が変更された
- (void)controlTextDidChange:(NSNotification *)aNotification
// ------------------------------------------------------
{
    // 入力されたスタイル名の検証
    if ([aNotification object] == [self styleNameField]) {
        NSString *styleName = [[self styleNameField] stringValue];
        styleName = [styleName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        [self validateStyleName:styleName];
    }
}


//=======================================================
// Delegate method (NSTableView)
//  <== tableViews
//=======================================================

// ------------------------------------------------------
/// tableView の選択が変更された
- (void)tableViewSelectionDidChange:(NSNotification *)notification
// ------------------------------------------------------
{
    NSTableView *tableView = [notification object];
    NSInteger row = [tableView selectedRow];
    
    // タブを切り替える
    if (tableView == [self menuTableView]) {
        [self setSelectedDetailTag:row];
        return;
    }
    
    // 最下行が選択されたのなら、編集開始のメソッドを呼び出す
    //（ここですぐに開始しないのは、選択行のセルが持つ文字列をこの段階では取得できないため）
    if ((row + 1) == [tableView numberOfRows]) {
        [tableView scrollRowToVisible:row];
        [self performSelectorOnMainThread:@selector(editNewAddedRowOfTableView:)
                               withObject:tableView
                            waitUntilDone:NO];
    }
}


//=======================================================
// Delegate method (NSTableView)
//  <== menuTableView
//=======================================================

// ------------------------------------------------------
/// 行を選択するべきかを返す
- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
// ------------------------------------------------------
{
    // セパレータは選択不可
    if (tableView == [self menuTableView]) {
        return ![[self menuTitles][row] isEqualToString:CESeparatorString];
    }
    
    return YES;
}



#pragma mark Action Messages

//=======================================================
// Action messages
//
//=======================================================

// ------------------------------------------------------
/// スタイルの内容を出荷時設定に戻す
- (IBAction)setToFactoryDefaults:(id)sender
// ------------------------------------------------------
{
    NSMutableDictionary *style = [[[CESyntaxManager sharedManager] bundledStyleWithStyleName:[self originalStyleName]] mutableCopy];
    
    if (!style) { return; }
    
    // フォーカスを移しておく
    [[sender window] makeFirstResponder:[sender window]];
    // 内容をセット
    [self setStyle:style];
    // デフォルト設定に戻すボタンを無効化
    [[self factoryDefaultsButton] setEnabled:NO];
}


// ------------------------------------------------------
/// カラーシンタックス編集シートの OK ボタンが押された
- (IBAction)saveEdit:(id)sender
// ------------------------------------------------------
{
    // フォーカスを移して入力中の値を確定
    [[sender window] makeFirstResponder:sender];
    
    // style名から先頭または末尾のスペース／タブ／改行を排除
    NSString *styleName = [[[self styleNameField] stringValue]
                           stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    [[self styleNameField] setStringValue:styleName];
    
    // style名のチェック
    NSString *errorMessage = [self validateStyleName:styleName];
    if (errorMessage) {
        NSBeep();
        [[[self styleNameField] window] makeFirstResponder:[self styleNameField]];
        return;
    }
    
    // エラー未チェックかつエラーがあれば、表示（エラーを表示していてOKボタンを押下したら、そのまま確定）
    if ([[[self validationTextView] string] isEqualToString:@""] && ([self validate] > 0)) {
        // 「構文要素チェック」を選択
        // （selectItemAtIndex: だとバインディングが実行されないので、メニューを取得して選択している）
        NSBeep();
        [[self menuTableView] selectRowIndexes:[NSIndexSet indexSetWithIndex:12] byExtendingSelection:NO];
        return;
    }
    [self setSavedNewStyleName:styleName];
    
    [[CESyntaxManager sharedManager] saveStyle:[self style] name:styleName oldName:[self originalStyleName]];
    
    [NSApp stopModal];
}


// ------------------------------------------------------
/// カラーシンタックス編集シートの Cancel ボタンが押された
- (IBAction)cancelEdit:(id)sender
// ------------------------------------------------------
{
    [NSApp stopModal];
}


// ------------------------------------------------------
/// 構文チェックを開始
- (IBAction)startValidation:(id)sender
// ------------------------------------------------------
{
    [self validate];
}



#pragma mark Private Mthods

//=======================================================
// Private method
//
//=======================================================

// ------------------------------------------------------
/// メニュー項目を返す
- (NSArray *)menuTitles
// ------------------------------------------------------
{
    return @[NSLocalizedString(@"Keywords", nil),
             NSLocalizedString(@"Commands", nil),
             NSLocalizedString(@"Values", nil),
             NSLocalizedString(@"Numbers", nil),
             NSLocalizedString(@"Strings", nil),
             NSLocalizedString(@"Characters", nil),
             NSLocalizedString(@"Comments", nil),
             CESeparatorString,
             NSLocalizedString(@"Outline Menu", nil),
             NSLocalizedString(@"Completion List", nil),
             NSLocalizedString(@"Extensions", nil),
             CESeparatorString,
             NSLocalizedString(@"Syntax Validation", nil)];
}


//------------------------------------------------------
/// 最下行が選択され、一番左のコラムが入力されていなければ自動的に編集を開始する
- (void)editNewAddedRowOfTableView:(NSTableView *)tableView
//------------------------------------------------------
{
    NSTableColumn *column = [tableView tableColumns][0];
    NSInteger row = [tableView selectedRow];
    id cell = [column dataCellForRow:row];
    if (cell == nil) { return; }
    NSString *string = [cell stringValue];
    
    if ([string isEqualToString:@""]) {
        if ([[tableView window] makeFirstResponder:tableView]) {
            [tableView editColumn:0 row:row withEvent:nil select:YES];
        }
    }
}


// ------------------------------------------------------
// 有効なスタイル名かチェックしてエラーメッセージを返す
- (NSString *)validateStyleName:(NSString *)styleName;
// ------------------------------------------------------
{
    if (([self mode] == CESyntaxEdit) && [[CESyntaxManager sharedManager] isBundledStyle:[self originalStyleName]]) {
        return nil;
    }
    
    NSString *message = nil;
    
    if (([self mode] == CECopySyntaxEdit) || ([self mode] == CENewSyntaxEdit) ||
        (([self mode] == CESyntaxEdit) && ([styleName caseInsensitiveCompare:[self originalStyleName]] != NSOrderedSame)))
    {
        // NSArray を case insensitive に検索するブロック
        __block NSString *duplicatedStyleName;
        BOOL (^caseInsensitiveContains)() = ^(id obj, NSUInteger idx, BOOL *stop){
            BOOL found = (BOOL)([obj caseInsensitiveCompare:styleName] == NSOrderedSame);
            if (found) { duplicatedStyleName = obj; }
            return found;
        };
        
        if ([styleName length] < 1) {  // 空は不可
            message = NSLocalizedString(@"Input style name.", nil);
        } else if ([styleName rangeOfString:@"/"].location != NSNotFound) {  // ファイル名としても使われるので、"/" が含まれる名前は不可
            message = NSLocalizedString(@"Style name cannot contain “/”. Input another name.", nil);
        } else if ([styleName hasPrefix:@"."]) {  // ファイル名としても使われるので、"." から始まる名前は不可
            message = NSLocalizedString(@"Style name cannot begin with “.”. Input another name.", nil);
        } else if ([[[CESyntaxManager sharedManager] styleNames] indexOfObjectPassingTest:caseInsensitiveContains] != NSNotFound) {  // 既にある名前は不可
            message = [NSString stringWithFormat:NSLocalizedString(@"“%@” is already exist. Input another name.", nil), duplicatedStyleName];
        }
    }
    
    [self setIsStyleNameValid:(!message)];
    [[self messageField] setStringValue:message ? : @""];
    
    return message;
}


// ------------------------------------------------------
/// 構文チェックを実行しその結果をテキストビューに挿入（戻り値はエラー数）
- (NSInteger)validate
// ------------------------------------------------------
{
    NSArray *errorMessages = [[CESyntaxManager sharedManager] validateSyntax:[self style]];
    
    NSMutableString *resultMessage = [NSMutableString string];
    if ([errorMessages count] == 0) {
        [resultMessage setString:NSLocalizedString(@"No error was found.", nil)];
        
    } else {
        if ([errorMessages count] == 1) {
            [resultMessage appendString:NSLocalizedString(@"One error was found!\n\n", nil)];
        } else {
            [resultMessage appendFormat:NSLocalizedString(@"%i errors were found!\n\n", nil), [errorMessages count]];
        }
        
        NSUInteger lineCount = 1;
        for (NSString *message in errorMessages) {
            [resultMessage appendFormat:@"%tu.  %@\n\n", lineCount, message];
            lineCount++;
        }
    }
    [[self validationTextView] setString:resultMessage];
    
    return [errorMessages count];
}

@end
