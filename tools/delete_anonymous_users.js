const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// serviceAccountKey.json を探す
// 1. 環境変数 GOOGLE_APPLICATION_CREDENTIALS
// 2. tools/serviceAccountKey.json
// 3. functional/serviceAccountKey.json (念のため)

let keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
if (!keyPath) {
    const localKey = path.join(__dirname, 'serviceAccountKey.json');
    if (fs.existsSync(localKey)) {
        keyPath = localKey;
    }
}

if (!keyPath) {
    console.error('\n[エラー] 認証キーが見つかりません。');
    console.error('以下の手順で `serviceAccountKey.json` を取得して `tools` フォルダに置いてください：');
    console.error('1. Firebaseコンソールを開く (https://console.firebase.google.com/)');
    console.error('2. 左上の「プロジェクトの概要」の歯車アイコン -> 「プロジェクトの設定」');
    console.error('3. 「サービスアカウント」タブを選択');
    console.error('4. 「新しい秘密鍵の生成」をクリックしてダウンロード');
    console.error('5. ダウンロードしたファイルを `tools/serviceAccountKey.json` にリネームして配置\n');
    process.exit(1);
}

const serviceAccount = require(keyPath);

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

async function deleteAnonymousUsers() {
    console.log('検索を開始します...');
    let nextPageToken;
    let totalInternal = 0;
    let deletedCount = 0;

    try {
        do {
            // 1000件ずつ取得
            const listUsersResult = await admin.auth().listUsers(1000, nextPageToken);

            // providerDataが空のユーザー = 匿名ユーザー
            const anonymousUsers = listUsersResult.users.filter(user => user.providerData.length === 0);

            const uidsToDelete = anonymousUsers.map(user => user.uid);

            if (uidsToDelete.length > 0) {
                console.log(`\n${uidsToDelete.length} 件の匿名ユーザーが見つかりました。削除を実行します...`);

                // deleteUsers は最大1000件まで一度に消せる
                const deleteResult = await admin.auth().deleteUsers(uidsToDelete);

                deletedCount += deleteResult.successCount;
                console.log(`  成功: ${deleteResult.successCount} 件`);
                if (deleteResult.failureCount > 0) {
                    console.error(`  失敗: ${deleteResult.failureCount} 件`);
                    deleteResult.errors.forEach(err => {
                        console.error('   Error:', err.error.toJSON());
                    });
                }
            } else {
                process.stdout.write('.');
            }

            totalInternal += listUsersResult.users.length;
            nextPageToken = listUsersResult.nextPageToken;
        } while (nextPageToken);

        console.log(`\n\n処理完了:`);
        console.log(`- スキャンした総ユーザー数: ${totalInternal}`);
        console.log(`- 削除した匿名ユーザー数: ${deletedCount}`);

    } catch (error) {
        console.error('エラーが発生しました:', error);
    }
}

deleteAnonymousUsers();
