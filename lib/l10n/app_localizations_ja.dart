// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'カレンさん';

  @override
  String get loginGoogle => 'Google でログイン';

  @override
  String get loginLine => 'LINEでログイン';

  @override
  String get loginOr => 'または';

  @override
  String get email => 'メールアドレス';

  @override
  String get password => 'パスワード';

  @override
  String get emailRequired => 'メールアドレスを入力してください。';

  @override
  String get passwordMin => '6 文字以上で入力してください';

  @override
  String get signUp => '新規登録';

  @override
  String get logIn => 'ログイン';

  @override
  String get haveAccount => 'アカウントをお持ちの方はこちら（ログイン）';

  @override
  String get firstTime => 'はじめての方はこちら（新規登録）';

  @override
  String get forgotPassword => 'パスワードを忘れた方';

  @override
  String get passwordResetSent => 'パスワード再設定メールを送信しました。';

  @override
  String loginFailed(String detail) {
    return 'ログインできませんでした（$detail）。';
  }

  @override
  String get authInvalidEmail => 'メールアドレスの形式が正しくありません。';

  @override
  String get authWrongCredentials => 'メールアドレスまたはパスワードが違います。';

  @override
  String get authEmailInUse => 'このメールアドレスはすでに登録されています。';

  @override
  String get authWeakPassword => 'パスワードは 6 文字以上にしてください。';

  @override
  String get authCancelled => 'ログインがキャンセルされました。';

  @override
  String get authTooMany => '試行回数が多すぎます。しばらくしてからお試しください。';

  @override
  String authError(String code) {
    return 'エラーが発生しました（$code）。';
  }

  @override
  String get lineCancelled => 'LINE ログインがキャンセルされました。';

  @override
  String lineFailed(String code) {
    return 'LINE ログインに失敗しました（$code）。';
  }

  @override
  String get lineStateMismatch => 'LINE ログインの確認に失敗しました（state）。もう一度お試しください。';

  @override
  String get logout => 'ログアウト';

  @override
  String loadFailed(String error) {
    return '読み込めませんでした：$error';
  }

  @override
  String eventsLoadFailed(String error) {
    return '予定を読み込めませんでした：$error';
  }

  @override
  String get cancel => 'キャンセル';

  @override
  String get save => '保存';

  @override
  String get add => '追加';

  @override
  String get delete => '削除';

  @override
  String get copy => 'コピー';

  @override
  String saveFailed(String error) {
    return '保存できませんでした：$error';
  }

  @override
  String deleteFailed(String error) {
    return '削除できませんでした：$error';
  }

  @override
  String errorGeneric(String error) {
    return 'エラーが発生しました：$error';
  }

  @override
  String get setupTitle => 'はじめに';

  @override
  String get setupIntro => '予定を共有するグループを作るか、家族から届いた招待コードで参加してください。';

  @override
  String get yourName => 'あなたの表示名';

  @override
  String get yourNameHelp => '予定に「誰が登録したか」として表示されます';

  @override
  String get yourNameRequired => 'あなたの表示名を入力してください。';

  @override
  String get createNew => '新しく作る';

  @override
  String get groupName => 'グループ名';

  @override
  String get groupNameRequired => 'グループ名を入力してください。';

  @override
  String get defaultGroupName => 'わが家';

  @override
  String get createGroup => 'グループを作る';

  @override
  String get joinWithCode => '招待コードで参加する';

  @override
  String get inviteCodeField => '招待コード（8 文字）';

  @override
  String get join => '参加する';

  @override
  String get inviteNotFound => '招待コードが見つかりません。';

  @override
  String get addEvent => '予定を追加';

  @override
  String get editEvent => '予定を編集';

  @override
  String get noEvents => '予定はありません';

  @override
  String xPostsOfDay(int count) {
    return '𝕏 この日の投稿（$count）';
  }

  @override
  String get oshiPostsOfDay => '推しのこの日の投稿';

  @override
  String get viewOnX => 'X で見る';

  @override
  String get hideXPosts => 'X の投稿を隠す';

  @override
  String get showXPosts => 'X の投稿を表示';

  @override
  String get membersTooltip => 'メンバー・予定者';

  @override
  String get allDay => '終日';

  @override
  String get noText => '（本文なし）';

  @override
  String get hasImage => '画像あり';

  @override
  String get xKindPost => '投稿';

  @override
  String get xKindReply => '返信';

  @override
  String get xKindRepost => 'リポスト';

  @override
  String get xKindLike => 'いいね';

  @override
  String get titleRequired => 'タイトルを入力してください。';

  @override
  String get endBeforeStart => '終了は開始より後にしてください。';

  @override
  String get deleteEventTitle => 'この予定を削除しますか？';

  @override
  String get deleteEventBody => '家族全員のカレンダーから消えます。';

  @override
  String get eventTitle => 'タイトル';

  @override
  String get whoseEvent => '誰の予定？';

  @override
  String get addPerson => '予定者を追加';

  @override
  String get start => '開始';

  @override
  String get end => '終了';

  @override
  String get memo => 'メモ';

  @override
  String addedBy(String name) {
    return '登録した人：$name';
  }

  @override
  String get everyone => 'みんな';

  @override
  String get formerMember => '（いなくなった人）';

  @override
  String get defaultMemberName => 'メンバー';

  @override
  String get name => '名前';

  @override
  String get color => '色';

  @override
  String get nameRequired => '名前を入力してください';

  @override
  String get editPerson => '予定者を編集';

  @override
  String get yourNameAndColor => 'あなたの名前と色';

  @override
  String deletePersonTitle(String name) {
    return '「$name」を削除しますか？';
  }

  @override
  String get deletePersonBody => 'この人の予定は消えずに残り、「（いなくなった人）」と表示されます。';

  @override
  String get members => 'メンバー';

  @override
  String get loggedInMembers => 'ログインしているメンバー';

  @override
  String get you => 'あなた';

  @override
  String get peopleSection => '予定者（ログインしない人）';

  @override
  String get peopleHelp => 'お子さんなど、アプリを使わない人の予定も色分けして登録できます。グループの誰でも追加・編集できます。';

  @override
  String get xDiarySection => 'あなたの X の投稿（日記）';

  @override
  String get xImportTitle => 'X の投稿を取り込む';

  @override
  String get xImportSubtitle => '日付を押すと、その日の投稿やいいねを読めます。あなただけが見られます。';

  @override
  String get oshiRegister => '推しの X を登録';

  @override
  String get oshiRegisterSubtitle => '日付を押すと、推しのその日の投稿を X で開けます。';

  @override
  String get inviteCode => '招待コード';

  @override
  String get inviteHelp => '家族にこのコードを伝えると、ログインして同じカレンダーに参加できます。';

  @override
  String get inviteCopied => '招待コードをコピーしました';

  @override
  String get accountSection => 'アカウント';

  @override
  String get deleteAccount => 'アカウントを削除';

  @override
  String get deleteAccountSubtitle => 'あなたのデータを削除して、ログアウトします。';

  @override
  String get deleting => '削除しています…';

  @override
  String get deleteAccountTitle => 'アカウントを削除しますか？';

  @override
  String get deleteAccountBody =>
      '次のものが削除され、元に戻せません。\n・あなたのアカウント\n・取り込んだ X の投稿と、推しの登録\n・グループのメンバーからあなたの名前と色\n\nグループにほかのメンバーがいる場合、予定は家族のために残り、「登録した人」からあなたの名前が消えます。あなたが最後の 1 人なら、グループと予定もすべて削除されます。\n\nLINE でログインしていた場合、LINE アプリの「設定 → アカウント → 連動アプリ」からカレンさんとの連動も解除できます。';

  @override
  String get deleteConfirmWord => '削除';

  @override
  String get deleteConfirmLabel => '確認のため「削除」と入力してください';

  @override
  String get deleteAccountButton => '削除する';

  @override
  String get xImportReading => 'ファイルを読んでいます…';

  @override
  String get xImportNotFound =>
      '投稿のファイルが見つかりませんでした。X からダウンロードした ZIP ファイル、または中の data フォルダにある tweets.js・like.js を選んでください。';

  @override
  String get xImportSaving => '保存しています…';

  @override
  String xImportSavingProgress(int done, int total) {
    return '保存しています…（$done / $total 日）';
  }

  @override
  String xImportDone(int tweets, int likes) {
    return '取り込みました：投稿 $tweets 件、いいね $likes 件';
  }

  @override
  String xImportFailed(String error) {
    return '取り込めませんでした：$error';
  }

  @override
  String get xDeleteAllTitle => '取り込んだ X の投稿をすべて削除しますか？';

  @override
  String get xDeleteAllBody => 'カレンさんに保存した分だけが消えます。X の投稿そのものは消えません。';

  @override
  String get deleted => '削除しました';

  @override
  String get xImportIntro =>
      '自分の投稿と「いいね」した投稿を取り込むと、カレンダーの日付を押したときにその日の投稿を日記のように読めます。';

  @override
  String get xImportNotes =>
      '・取り込んだ投稿は、あなただけが見られます（家族には見えません）。\n・「いいね」した投稿は、いいねした日ではなく元の投稿の日付に表示されます。\n・同じアーカイブを何度取り込んでも重複しません。新しい投稿は、ときどきアーカイブを取り直して取り込んでください。';

  @override
  String get xImportStep1 => '1. X でアーカイブを依頼する';

  @override
  String get xImportStep1Body =>
      'X のアプリかサイトで「設定とプライバシー」→「アカウント」→「データのアーカイブをダウンロード」を開き、パスワードを入れて依頼します。準備ができるまで 1 日以上かかることがあり、できたら X から通知が届きます。';

  @override
  String get xImportStep2 => '2. ダウンロードした ZIP を選ぶ';

  @override
  String get xImportStep2Body =>
      'iPhone では「ファイル」アプリに保存された ZIP をそのまま選べます。うまくいかないときは、ファイルアプリで ZIP を開いて展開し、中の data フォルダにある tweets.js と like.js を選んでください。';

  @override
  String get xImportPick => 'ファイルを選んで取り込む';

  @override
  String get xImportedCounting => '取り込み済み：確認中…';

  @override
  String xImportedDays(int days) {
    return '取り込み済み：$days 日分';
  }

  @override
  String get deleteAll => 'すべて削除';

  @override
  String get oshiTitle => '推しの X';

  @override
  String get oshiAdd => '推しを追加';

  @override
  String get oshiEdit => '推しを編集';

  @override
  String get oshiIntro =>
      '登録した人ごとに、カレンダーの日付を押したとき「この日の投稿を X で見る」ボタンが出ます。押すと X が開き、その人がその日に投稿したものだけが表示されます。\n・登録した内容はあなただけが見られます。\n・X にログインしていないと、検索結果が見られないことがあります。';

  @override
  String get oshiEmpty => 'まだ登録されていません';

  @override
  String get oshiHandleInvalid => 'X のユーザー名（@ のあとの英数字）か、プロフィールの URL を入れてください';

  @override
  String get oshiHandle => 'X のユーザー名';

  @override
  String get oshiHandleHint => '@username または URL';

  @override
  String get oshiDisplayName => '表示名（なくても OK）';

  @override
  String get rangeSeparator => '〜';
}
