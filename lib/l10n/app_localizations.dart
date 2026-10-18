import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Karen-san'**
  String get appTitle;

  /// No description provided for @loginGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get loginGoogle;

  /// No description provided for @loginLine.
  ///
  /// In en, this message translates to:
  /// **'Log in with LINE'**
  String get loginLine;

  /// No description provided for @loginOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get loginOr;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address.'**
  String get emailRequired;

  /// No description provided for @passwordMin.
  ///
  /// In en, this message translates to:
  /// **'Use at least 6 characters'**
  String get passwordMin;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get logIn;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log in'**
  String get haveAccount;

  /// No description provided for @firstTime.
  ///
  /// In en, this message translates to:
  /// **'New here? Sign up'**
  String get firstTime;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get forgotPassword;

  /// No description provided for @passwordResetSent.
  ///
  /// In en, this message translates to:
  /// **'We sent you a password reset email.'**
  String get passwordResetSent;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign in ({detail}).'**
  String loginFailed(String detail);

  /// No description provided for @authInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'That email address doesn\'t look right.'**
  String get authInvalidEmail;

  /// No description provided for @authWrongCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong email address or password.'**
  String get authWrongCredentials;

  /// No description provided for @authEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'This email address is already registered.'**
  String get authEmailInUse;

  /// No description provided for @authWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Use a password of at least 6 characters.'**
  String get authWeakPassword;

  /// No description provided for @authCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sign-in was cancelled.'**
  String get authCancelled;

  /// No description provided for @authTooMany.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get authTooMany;

  /// No description provided for @authError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong ({code}).'**
  String authError(String code);

  /// No description provided for @lineCancelled.
  ///
  /// In en, this message translates to:
  /// **'LINE login was cancelled.'**
  String get lineCancelled;

  /// No description provided for @lineFailed.
  ///
  /// In en, this message translates to:
  /// **'LINE login failed ({code}).'**
  String lineFailed(String code);

  /// No description provided for @lineStateMismatch.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t verify the LINE login. Please try again.'**
  String get lineStateMismatch;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load: {error}'**
  String loadFailed(String error);

  /// No description provided for @eventsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load events: {error}'**
  String eventsLoadFailed(String error);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save: {error}'**
  String saveFailed(String error);

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete: {error}'**
  String deleteFailed(String error);

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {error}'**
  String errorGeneric(String error);

  /// No description provided for @setupTitle.
  ///
  /// In en, this message translates to:
  /// **'Getting started'**
  String get setupTitle;

  /// No description provided for @setupIntro.
  ///
  /// In en, this message translates to:
  /// **'Create a group to share your calendar, or join one with an invite code from your family.'**
  String get setupIntro;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your display name'**
  String get yourName;

  /// No description provided for @yourNameHelp.
  ///
  /// In en, this message translates to:
  /// **'Shown as \"added by\" on events'**
  String get yourNameHelp;

  /// No description provided for @yourNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your display name.'**
  String get yourNameRequired;

  /// No description provided for @createNew.
  ///
  /// In en, this message translates to:
  /// **'Create a new group'**
  String get createNew;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupName;

  /// No description provided for @groupNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a group name.'**
  String get groupNameRequired;

  /// No description provided for @defaultGroupName.
  ///
  /// In en, this message translates to:
  /// **'Our family'**
  String get defaultGroupName;

  /// No description provided for @createGroup.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get createGroup;

  /// No description provided for @joinWithCode.
  ///
  /// In en, this message translates to:
  /// **'Join with an invite code'**
  String get joinWithCode;

  /// No description provided for @inviteCodeField.
  ///
  /// In en, this message translates to:
  /// **'Invite code (8 characters)'**
  String get inviteCodeField;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @inviteNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find that invite code.'**
  String get inviteNotFound;

  /// No description provided for @addEvent.
  ///
  /// In en, this message translates to:
  /// **'Add event'**
  String get addEvent;

  /// No description provided for @editEvent.
  ///
  /// In en, this message translates to:
  /// **'Edit event'**
  String get editEvent;

  /// No description provided for @noEvents.
  ///
  /// In en, this message translates to:
  /// **'No events'**
  String get noEvents;

  /// No description provided for @xPostsOfDay.
  ///
  /// In en, this message translates to:
  /// **'𝕏 Posts on this day ({count})'**
  String xPostsOfDay(int count);

  /// No description provided for @oshiPostsOfDay.
  ///
  /// In en, this message translates to:
  /// **'Their posts on this day'**
  String get oshiPostsOfDay;

  /// No description provided for @viewOnX.
  ///
  /// In en, this message translates to:
  /// **'View on X'**
  String get viewOnX;

  /// No description provided for @hideXPosts.
  ///
  /// In en, this message translates to:
  /// **'Hide X posts'**
  String get hideXPosts;

  /// No description provided for @showXPosts.
  ///
  /// In en, this message translates to:
  /// **'Show X posts'**
  String get showXPosts;

  /// No description provided for @membersTooltip.
  ///
  /// In en, this message translates to:
  /// **'Members & people'**
  String get membersTooltip;

  /// No description provided for @allDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get allDay;

  /// No description provided for @noText.
  ///
  /// In en, this message translates to:
  /// **'(no text)'**
  String get noText;

  /// No description provided for @hasImage.
  ///
  /// In en, this message translates to:
  /// **'has image'**
  String get hasImage;

  /// No description provided for @xKindPost.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get xKindPost;

  /// No description provided for @xKindReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get xKindReply;

  /// No description provided for @xKindRepost.
  ///
  /// In en, this message translates to:
  /// **'Repost'**
  String get xKindRepost;

  /// No description provided for @xKindLike.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get xKindLike;

  /// No description provided for @titleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title.'**
  String get titleRequired;

  /// No description provided for @endBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'The end must be after the start.'**
  String get endBeforeStart;

  /// No description provided for @deleteEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this event?'**
  String get deleteEventTitle;

  /// No description provided for @deleteEventBody.
  ///
  /// In en, this message translates to:
  /// **'It will disappear from everyone\'s calendar in the group.'**
  String get deleteEventBody;

  /// No description provided for @eventTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get eventTitle;

  /// No description provided for @whoseEvent.
  ///
  /// In en, this message translates to:
  /// **'Whose event?'**
  String get whoseEvent;

  /// No description provided for @addPerson.
  ///
  /// In en, this message translates to:
  /// **'Add a person'**
  String get addPerson;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// No description provided for @memo.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get memo;

  /// No description provided for @addedBy.
  ///
  /// In en, this message translates to:
  /// **'Added by: {name}'**
  String addedBy(String name);

  /// No description provided for @everyone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get everyone;

  /// No description provided for @formerMember.
  ///
  /// In en, this message translates to:
  /// **'(no longer here)'**
  String get formerMember;

  /// No description provided for @defaultMemberName.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get defaultMemberName;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get nameRequired;

  /// No description provided for @editPerson.
  ///
  /// In en, this message translates to:
  /// **'Edit person'**
  String get editPerson;

  /// No description provided for @yourNameAndColor.
  ///
  /// In en, this message translates to:
  /// **'Your name and color'**
  String get yourNameAndColor;

  /// No description provided for @deletePersonTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deletePersonTitle(String name);

  /// No description provided for @deletePersonBody.
  ///
  /// In en, this message translates to:
  /// **'Their events stay and are shown as \"(no longer here)\".'**
  String get deletePersonBody;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get members;

  /// No description provided for @loggedInMembers.
  ///
  /// In en, this message translates to:
  /// **'Members who sign in'**
  String get loggedInMembers;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @peopleSection.
  ///
  /// In en, this message translates to:
  /// **'People (who don\'t sign in)'**
  String get peopleSection;

  /// No description provided for @peopleHelp.
  ///
  /// In en, this message translates to:
  /// **'Add events for people who don\'t use the app, like children, each with their own color. Anyone in the group can add or edit them.'**
  String get peopleHelp;

  /// No description provided for @xDiarySection.
  ///
  /// In en, this message translates to:
  /// **'Your X posts (diary)'**
  String get xDiarySection;

  /// No description provided for @xImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import your X posts'**
  String get xImportTitle;

  /// No description provided for @xImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap a day to read your posts and likes from that day. Only you can see them.'**
  String get xImportSubtitle;

  /// No description provided for @oshiRegister.
  ///
  /// In en, this message translates to:
  /// **'Add accounts to follow'**
  String get oshiRegister;

  /// No description provided for @oshiRegisterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap a day to open that day\'s posts by people you follow on X.'**
  String get oshiRegisterSubtitle;

  /// No description provided for @inviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get inviteCode;

  /// No description provided for @inviteHelp.
  ///
  /// In en, this message translates to:
  /// **'Share this code with your family so they can sign in and join this calendar.'**
  String get inviteHelp;

  /// No description provided for @inviteCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite code copied'**
  String get inviteCopied;

  /// No description provided for @accountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountSection;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your data and log out.'**
  String get deleteAccountSubtitle;

  /// No description provided for @deleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting…'**
  String get deleting;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'The following will be deleted and can\'t be restored:\n• Your account\n• Imported X posts and the accounts you follow\n• Your name and color in the group\'s member list\n\nIf other members remain in your group, events stay for your family and your name is removed from \"added by\". If you are the last member, the group and all of its events are deleted too.\n\nIf you signed in with LINE, you can also disconnect Karen-san in the LINE app under Settings → Account → Authorized apps.'**
  String get deleteAccountBody;

  /// No description provided for @deleteConfirmWord.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deleteConfirmWord;

  /// No description provided for @deleteConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Type \"DELETE\" to confirm'**
  String get deleteConfirmLabel;

  /// No description provided for @deleteAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAccountButton;

  /// No description provided for @xImportReading.
  ///
  /// In en, this message translates to:
  /// **'Reading the file…'**
  String get xImportReading;

  /// No description provided for @xImportNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find the posts in that file. Choose the ZIP you downloaded from X, or tweets.js and like.js from its data folder.'**
  String get xImportNotFound;

  /// No description provided for @xImportSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get xImportSaving;

  /// No description provided for @xImportSavingProgress.
  ///
  /// In en, this message translates to:
  /// **'Saving… ({done} / {total} days)'**
  String xImportSavingProgress(int done, int total);

  /// No description provided for @xImportDone.
  ///
  /// In en, this message translates to:
  /// **'Imported {tweets} posts and {likes} likes'**
  String xImportDone(int tweets, int likes);

  /// No description provided for @xImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t import: {error}'**
  String xImportFailed(String error);

  /// No description provided for @xDeleteAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all imported X posts?'**
  String get xDeleteAllTitle;

  /// No description provided for @xDeleteAllBody.
  ///
  /// In en, this message translates to:
  /// **'Only the copies saved in Karen-san are deleted. Your posts on X are not affected.'**
  String get xDeleteAllBody;

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deleted;

  /// No description provided for @xImportIntro.
  ///
  /// In en, this message translates to:
  /// **'Import your own posts and the posts you liked, then tap a day on the calendar to read that day\'s posts like a diary.'**
  String get xImportIntro;

  /// No description provided for @xImportNotes.
  ///
  /// In en, this message translates to:
  /// **'• Only you can see imported posts (your family can\'t).\n• Liked posts appear on the date they were originally posted, not the date you liked them.\n• Importing the same archive again won\'t create duplicates. To add newer posts, download a fresh archive from time to time.'**
  String get xImportNotes;

  /// No description provided for @xImportStep1.
  ///
  /// In en, this message translates to:
  /// **'1. Request your archive on X'**
  String get xImportStep1;

  /// No description provided for @xImportStep1Body.
  ///
  /// In en, this message translates to:
  /// **'In the X app or website, open Settings and privacy → Your account → Download an archive of your data, enter your password, and request it. It can take a day or more; X will notify you when it\'s ready.'**
  String get xImportStep1Body;

  /// No description provided for @xImportStep2.
  ///
  /// In en, this message translates to:
  /// **'2. Choose the downloaded ZIP'**
  String get xImportStep2;

  /// No description provided for @xImportStep2Body.
  ///
  /// In en, this message translates to:
  /// **'On iPhone you can pick the ZIP straight from the Files app. If that doesn\'t work, open the ZIP in Files to extract it and choose tweets.js and like.js from the data folder.'**
  String get xImportStep2Body;

  /// No description provided for @xImportPick.
  ///
  /// In en, this message translates to:
  /// **'Choose a file to import'**
  String get xImportPick;

  /// No description provided for @xImportedCounting.
  ///
  /// In en, this message translates to:
  /// **'Imported: checking…'**
  String get xImportedCounting;

  /// No description provided for @xImportedDays.
  ///
  /// In en, this message translates to:
  /// **'Imported: {days} days'**
  String xImportedDays(int days);

  /// No description provided for @deleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete all'**
  String get deleteAll;

  /// No description provided for @oshiTitle.
  ///
  /// In en, this message translates to:
  /// **'Accounts to follow on X'**
  String get oshiTitle;

  /// No description provided for @oshiAdd.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get oshiAdd;

  /// No description provided for @oshiEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit account'**
  String get oshiEdit;

  /// No description provided for @oshiIntro.
  ///
  /// In en, this message translates to:
  /// **'For each account here, tapping a day on the calendar shows a \"View on X\" button. It opens X with only the posts that account made on that day.\n• Only you can see this list.\n• You may need to be signed in to X to see search results.'**
  String get oshiIntro;

  /// No description provided for @oshiEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing added yet'**
  String get oshiEmpty;

  /// No description provided for @oshiHandleInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an X username (the letters after @) or a profile URL'**
  String get oshiHandleInvalid;

  /// No description provided for @oshiHandle.
  ///
  /// In en, this message translates to:
  /// **'X username'**
  String get oshiHandle;

  /// No description provided for @oshiHandleHint.
  ///
  /// In en, this message translates to:
  /// **'@username or URL'**
  String get oshiHandleHint;

  /// No description provided for @oshiDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name (optional)'**
  String get oshiDisplayName;

  /// No description provided for @rangeSeparator.
  ///
  /// In en, this message translates to:
  /// **' – '**
  String get rangeSeparator;

  /// No description provided for @customColor.
  ///
  /// In en, this message translates to:
  /// **'Custom color'**
  String get customColor;

  /// No description provided for @colorPreview.
  ///
  /// In en, this message translates to:
  /// **'Sample event'**
  String get colorPreview;

  /// No description provided for @hue.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get hue;

  /// No description provided for @brightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get brightness;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @unlockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock Karen-san'**
  String get unlockReason;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @appLock.
  ///
  /// In en, this message translates to:
  /// **'Lock with Face ID / Touch ID'**
  String get appLock;

  /// No description provided for @appLockHelp.
  ///
  /// In en, this message translates to:
  /// **'Ask for Face ID, Touch ID, or your passcode when opening the app.'**
  String get appLockHelp;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get viewAll;

  /// No description provided for @family.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get family;

  /// No description provided for @work.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get work;

  /// No description provided for @routineLabel.
  ///
  /// In en, this message translates to:
  /// **'Weekly routine'**
  String get routineLabel;

  /// No description provided for @skipThisDay.
  ///
  /// In en, this message translates to:
  /// **'Skip only on {date}'**
  String skipThisDay(String date);

  /// No description provided for @editRoutine.
  ///
  /// In en, this message translates to:
  /// **'Edit routine'**
  String get editRoutine;

  /// No description provided for @addRoutine.
  ///
  /// In en, this message translates to:
  /// **'Add routine'**
  String get addRoutine;

  /// No description provided for @routinesTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly routine'**
  String get routinesTitle;

  /// No description provided for @routinesHelp.
  ///
  /// In en, this message translates to:
  /// **'Add things that happen every week, like school or work hours. They appear on the calendar automatically, so you don\'t need to enter them each time.'**
  String get routinesHelp;

  /// No description provided for @skipHolidaysShort.
  ///
  /// In en, this message translates to:
  /// **'Off on holidays'**
  String get skipHolidaysShort;

  /// No description provided for @weekdaysRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one day of the week.'**
  String get weekdaysRequired;

  /// No description provided for @deleteRoutineTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this routine?'**
  String get deleteRoutineTitle;

  /// No description provided for @deleteRoutineBody.
  ///
  /// In en, this message translates to:
  /// **'It will disappear from every week on the calendar.'**
  String get deleteRoutineBody;

  /// No description provided for @repeatOn.
  ///
  /// In en, this message translates to:
  /// **'Repeat on'**
  String get repeatOn;

  /// No description provided for @weekdaysOnly.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get weekdaysOnly;

  /// No description provided for @skipHolidays.
  ///
  /// In en, this message translates to:
  /// **'Off on public holidays'**
  String get skipHolidays;

  /// No description provided for @skipHolidaysHelp.
  ///
  /// In en, this message translates to:
  /// **'Not shown on Japanese public holidays and substitute holidays (good for school).'**
  String get skipHolidaysHelp;

  /// No description provided for @skippedDays.
  ///
  /// In en, this message translates to:
  /// **'Skipped days (tap × to restore)'**
  String get skippedDays;

  /// No description provided for @workOnlyYou.
  ///
  /// In en, this message translates to:
  /// **'Work event — only you can see it'**
  String get workOnlyYou;

  /// No description provided for @todoTitle.
  ///
  /// In en, this message translates to:
  /// **'This week\'s to-dos'**
  String get todoTitle;

  /// No description provided for @todoHintWork.
  ///
  /// In en, this message translates to:
  /// **'Work to-do for this week'**
  String get todoHintWork;

  /// No description provided for @todoHintFamily.
  ///
  /// In en, this message translates to:
  /// **'Family to-do for this week'**
  String get todoHintFamily;

  /// No description provided for @todoEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to do yet. Add what you need to get done this week.'**
  String get todoEmpty;

  /// No description provided for @todoCarried.
  ///
  /// In en, this message translates to:
  /// **'From earlier weeks'**
  String get todoCarried;

  /// No description provided for @todoThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get todoThisWeek;

  /// No description provided for @todoFromWeek.
  ///
  /// In en, this message translates to:
  /// **'From the week of {week}'**
  String todoFromWeek(String week);

  /// No description provided for @tabCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get tabCalendar;

  /// No description provided for @tabRoutine.
  ///
  /// In en, this message translates to:
  /// **'Routine'**
  String get tabRoutine;

  /// No description provided for @tabTodo.
  ///
  /// In en, this message translates to:
  /// **'To-do'**
  String get tabTodo;

  /// No description provided for @tabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
