// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Karen-san';

  @override
  String get loginGoogle => 'Sign in with Google';

  @override
  String get loginLine => 'Log in with LINE';

  @override
  String get loginOr => 'or';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get emailRequired => 'Please enter your email address.';

  @override
  String get passwordMin => 'Use at least 6 characters';

  @override
  String get signUp => 'Sign up';

  @override
  String get logIn => 'Log in';

  @override
  String get haveAccount => 'Already have an account? Log in';

  @override
  String get firstTime => 'New here? Sign up';

  @override
  String get forgotPassword => 'Forgot your password?';

  @override
  String get passwordResetSent => 'We sent you a password reset email.';

  @override
  String loginFailed(String detail) {
    return 'Couldn\'t sign in ($detail).';
  }

  @override
  String get authInvalidEmail => 'That email address doesn\'t look right.';

  @override
  String get authWrongCredentials => 'Wrong email address or password.';

  @override
  String get authEmailInUse => 'This email address is already registered.';

  @override
  String get authWeakPassword => 'Use a password of at least 6 characters.';

  @override
  String get authCancelled => 'Sign-in was cancelled.';

  @override
  String get authTooMany => 'Too many attempts. Please try again later.';

  @override
  String authError(String code) {
    return 'Something went wrong ($code).';
  }

  @override
  String get lineCancelled => 'LINE login was cancelled.';

  @override
  String lineFailed(String code) {
    return 'LINE login failed ($code).';
  }

  @override
  String get lineStateMismatch =>
      'We couldn\'t verify the LINE login. Please try again.';

  @override
  String get logout => 'Log out';

  @override
  String loadFailed(String error) {
    return 'Couldn\'t load: $error';
  }

  @override
  String eventsLoadFailed(String error) {
    return 'Couldn\'t load events: $error';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get add => 'Add';

  @override
  String get delete => 'Delete';

  @override
  String get copy => 'Copy';

  @override
  String saveFailed(String error) {
    return 'Couldn\'t save: $error';
  }

  @override
  String deleteFailed(String error) {
    return 'Couldn\'t delete: $error';
  }

  @override
  String errorGeneric(String error) {
    return 'Something went wrong: $error';
  }

  @override
  String get setupTitle => 'Getting started';

  @override
  String get setupIntro =>
      'Create a group to share your calendar, or join one with an invite code from your family.';

  @override
  String get yourName => 'Your display name';

  @override
  String get yourNameHelp => 'Shown as \"added by\" on events';

  @override
  String get yourNameRequired => 'Please enter your display name.';

  @override
  String get createNew => 'Create a new group';

  @override
  String get groupName => 'Group name';

  @override
  String get groupNameRequired => 'Please enter a group name.';

  @override
  String get defaultGroupName => 'Our family';

  @override
  String get createGroup => 'Create group';

  @override
  String get joinWithCode => 'Join with an invite code';

  @override
  String get inviteCodeField => 'Invite code (8 characters)';

  @override
  String get join => 'Join';

  @override
  String get inviteNotFound => 'We couldn\'t find that invite code.';

  @override
  String get addEvent => 'Add event';

  @override
  String get editEvent => 'Edit event';

  @override
  String get noEvents => 'No events';

  @override
  String xPostsOfDay(int count) {
    return '𝕏 Posts on this day ($count)';
  }

  @override
  String get oshiPostsOfDay => 'Their posts on this day';

  @override
  String get viewOnX => 'View on X';

  @override
  String get hideXPosts => 'Hide X posts';

  @override
  String get showXPosts => 'Show X posts';

  @override
  String get membersTooltip => 'Members & people';

  @override
  String get allDay => 'All day';

  @override
  String get noText => '(no text)';

  @override
  String get hasImage => 'has image';

  @override
  String get xKindPost => 'Post';

  @override
  String get xKindReply => 'Reply';

  @override
  String get xKindRepost => 'Repost';

  @override
  String get xKindLike => 'Like';

  @override
  String get titleRequired => 'Please enter a title.';

  @override
  String get endBeforeStart => 'The end must be after the start.';

  @override
  String get deleteEventTitle => 'Delete this event?';

  @override
  String get deleteEventBody =>
      'It will disappear from everyone\'s calendar in the group.';

  @override
  String get eventTitle => 'Title';

  @override
  String get whoseEvent => 'Whose event?';

  @override
  String get addPerson => 'Add a person';

  @override
  String get start => 'Start';

  @override
  String get end => 'End';

  @override
  String get memo => 'Notes';

  @override
  String addedBy(String name) {
    return 'Added by: $name';
  }

  @override
  String get everyone => 'Everyone';

  @override
  String get formerMember => '(no longer here)';

  @override
  String get defaultMemberName => 'Member';

  @override
  String get name => 'Name';

  @override
  String get color => 'Color';

  @override
  String get nameRequired => 'Please enter a name';

  @override
  String get editPerson => 'Edit person';

  @override
  String get yourNameAndColor => 'Your name and color';

  @override
  String deletePersonTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get deletePersonBody =>
      'Their events stay and are shown as \"(no longer here)\".';

  @override
  String get members => 'Members';

  @override
  String get loggedInMembers => 'Members who sign in';

  @override
  String get you => 'You';

  @override
  String get peopleSection => 'People (who don\'t sign in)';

  @override
  String get peopleHelp =>
      'Add events for people who don\'t use the app, like children, each with their own color. Anyone in the group can add or edit them.';

  @override
  String get xDiarySection => 'Your X posts (diary)';

  @override
  String get xImportTitle => 'Import your X posts';

  @override
  String get xImportSubtitle =>
      'Tap a day to read your posts and likes from that day. Only you can see them.';

  @override
  String get oshiRegister => 'Add accounts to follow';

  @override
  String get oshiRegisterSubtitle =>
      'Tap a day to open that day\'s posts by people you follow on X.';

  @override
  String get inviteCode => 'Invite code';

  @override
  String get inviteHelp =>
      'Share this code with your family so they can sign in and join this calendar.';

  @override
  String get inviteCopied => 'Invite code copied';

  @override
  String get accountSection => 'Account';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountSubtitle => 'Delete your data and log out.';

  @override
  String get deleting => 'Deleting…';

  @override
  String get deleteAccountTitle => 'Delete your account?';

  @override
  String get deleteAccountBody =>
      'The following will be deleted and can\'t be restored:\n• Your account\n• Imported X posts and the accounts you follow\n• Your name and color in the group\'s member list\n\nIf other members remain in your group, events stay for your family and your name is removed from \"added by\". If you are the last member, the group and all of its events are deleted too.\n\nIf you signed in with LINE, you can also disconnect Karen-san in the LINE app under Settings → Account → Authorized apps.';

  @override
  String get deleteConfirmWord => 'DELETE';

  @override
  String get deleteConfirmLabel => 'Type \"DELETE\" to confirm';

  @override
  String get deleteAccountButton => 'Delete';

  @override
  String get xImportReading => 'Reading the file…';

  @override
  String get xImportNotFound =>
      'We couldn\'t find the posts in that file. Choose the ZIP you downloaded from X, or tweets.js and like.js from its data folder.';

  @override
  String get xImportSaving => 'Saving…';

  @override
  String xImportSavingProgress(int done, int total) {
    return 'Saving… ($done / $total days)';
  }

  @override
  String xImportDone(int tweets, int likes) {
    return 'Imported $tweets posts and $likes likes';
  }

  @override
  String xImportFailed(String error) {
    return 'Couldn\'t import: $error';
  }

  @override
  String get xDeleteAllTitle => 'Delete all imported X posts?';

  @override
  String get xDeleteAllBody =>
      'Only the copies saved in Karen-san are deleted. Your posts on X are not affected.';

  @override
  String get deleted => 'Deleted';

  @override
  String get xImportIntro =>
      'Import your own posts and the posts you liked, then tap a day on the calendar to read that day\'s posts like a diary.';

  @override
  String get xImportNotes =>
      '• Only you can see imported posts (your family can\'t).\n• Liked posts appear on the date they were originally posted, not the date you liked them.\n• Importing the same archive again won\'t create duplicates. To add newer posts, download a fresh archive from time to time.';

  @override
  String get xImportStep1 => '1. Request your archive on X';

  @override
  String get xImportStep1Body =>
      'In the X app or website, open Settings and privacy → Your account → Download an archive of your data, enter your password, and request it. It can take a day or more; X will notify you when it\'s ready.';

  @override
  String get xImportStep2 => '2. Choose the downloaded ZIP';

  @override
  String get xImportStep2Body =>
      'On iPhone you can pick the ZIP straight from the Files app. If that doesn\'t work, open the ZIP in Files to extract it and choose tweets.js and like.js from the data folder.';

  @override
  String get xImportPick => 'Choose a file to import';

  @override
  String get xImportedCounting => 'Imported: checking…';

  @override
  String xImportedDays(int days) {
    return 'Imported: $days days';
  }

  @override
  String get deleteAll => 'Delete all';

  @override
  String get oshiTitle => 'Accounts to follow on X';

  @override
  String get oshiAdd => 'Add account';

  @override
  String get oshiEdit => 'Edit account';

  @override
  String get oshiIntro =>
      'For each account here, tapping a day on the calendar shows a \"View on X\" button. It opens X with only the posts that account made on that day.\n• Only you can see this list.\n• You may need to be signed in to X to see search results.';

  @override
  String get oshiEmpty => 'Nothing added yet';

  @override
  String get oshiHandleInvalid =>
      'Enter an X username (the letters after @) or a profile URL';

  @override
  String get oshiHandle => 'X username';

  @override
  String get oshiHandleHint => '@username or URL';

  @override
  String get oshiDisplayName => 'Display name (optional)';

  @override
  String get rangeSeparator => ' – ';
}
