// 管理者画面のフォーム確認ダイアログ

document.addEventListener('DOMContentLoaded', () => {
  // サブスクリプション免除チェックボックスの確認
  const subscriptionExemptCheckbox = document.querySelector('[data-confirm-toggle="モニター除外"]');
  if (subscriptionExemptCheckbox) {
    let originalValue = subscriptionExemptCheckbox.checked;

    subscriptionExemptCheckbox.addEventListener('change', (e) => {
      const isChecked = e.target.checked;
      const wasChecked = originalValue;

      // チェックを外す場合（モニター除外）のみ確認
      if (wasChecked && !isChecked) {
        const confirmed = confirm(
          'サブスクリプション免除を外しますか？\n\n' +
          'このユーザーは次回ログイン時にサブスクリプション登録が必要になります。\n' +
          'トライアル期間は付与されません。'
        );

        if (!confirmed) {
          e.target.checked = true; // 元に戻す
        } else {
          originalValue = false; // 確認したので更新
        }
      } else {
        originalValue = isChecked;
      }
    });
  }

  // ステータス変更の確認
  const statusSelect = document.querySelector('[data-confirm-change="ユーザー無効化"]');
  if (statusSelect) {
    let originalValue = statusSelect.value;

    statusSelect.addEventListener('change', (e) => {
      const newValue = e.target.value;

      // inactive に変更する場合のみ確認
      if (originalValue === 'active' && newValue === 'inactive') {
        const confirmed = confirm(
          'このユーザーを無効化しますか？\n\n' +
          'ユーザーはログインできなくなります。\n' +
          'サブスクリプションがある場合、別途解約が必要です。'
        );

        if (!confirmed) {
          e.target.value = originalValue; // 元に戻す
        } else {
          originalValue = newValue; // 確認したので更新
        }
      } else {
        originalValue = newValue;
      }
    });
  }
});
