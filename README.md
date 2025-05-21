# YOYAKU-HUB

## 概要

フリーランス美容師の予約、会計、顧客の管理システムです。

### 特徴

YOYAKU HUBというサービスは、予約終了の30分後に予約が入ると、その30分は施術に使えない隙間時間になり、予約枠が効率的に埋まらない問題を解決したいフリーランス美容師向けの、 web予約です。<br>ユーザーは、予約の前後に隙間時間ができる場合は自動的に検出し、その時間の表示を変えて他の時間へ促すことで、予約枠を最適に管理することができます。 また、他のサービスとは違って予約の柔軟な管理機能が備わっていることが特徴です。

## URL
https://yoyakuhub.jp

## 使い方

### ログイン

美容師と予約を取る人（カスタマー）でログイン、新規登録が分かれています。<br>
それぞれ用途に合ったログイン、新規登録をします。

<img width="30%" alt="ログイン" src="https://github.com/user-attachments/assets/a30b7f88-6e70-4df0-9ac3-d5db7677a40b">


### 美容師側

#### ダッシュボード
シフト、メニューが未設定の場合に促すメッセージを出るようしています。<br>
今月の受付設定が未登録の場合と、来月の受付設定が今月の20日までにしていない場合にも設定を促すメッセージを出るようにしています。<br>

<img width="30%" alt="美容師ダッシュボード" src="https://github.com/user-attachments/assets/3c6fba9d-23e1-410f-95db-ea4b2401f40c">


#### メニュー管理

##### 新規登録
並び順はカスタマーのメニュー選択の順番を決めるものです。入力しない場合は少ない数字から順番に入るようになっています。<br>
掲載の有無はカスタマーのメニュー選択、美容師予約変更で予約の表示の有無を決めています。<br>

<img width="30%" alt="メニュ管理,新規登録" src="https://github.com/user-attachments/assets/6bb6753e-d598-4e43-870c-d943ce57f73e">


##### メニュー登録済み

<img width="30%" alt="メニュ管理" src="https://github.com/user-attachments/assets/f5e0606b-3b71-4cb2-a5ea-3b4bbd147d53">


#### シフト管理

##### 営業時間、休業日、受付可能数の基本情報を設定
毎月の受付設定の基本情報を決めるものです。<br>

<img width="30%" alt="シフト管理" src="https://github.com/user-attachments/assets/4ee2b8b7-2f43-40c5-9789-7ed764795b41">


##### 毎月の受付設定
シフトの基本情報で設定された営業時間、休業日、受付可能数が反映されおり、日ごとの細かな設定をこちらで行います。<br>
これを設定しないとカスタマーの予約表、美容師の予約表に反映されないようになっています。<br>
一度設定を行った場合、シフト管理でデフォルトを変更してもこちらの月には反映されないようになっています。

<img width="30%" alt="シフト管理,毎月の受付設定" src="https://github.com/user-attachments/assets/2cb13619-7edc-42c5-8453-96f0e5558d71">


#### 予約表
毎月の受付設定で設定した休業日、営業時間、受付可能数が反映されています。<br>
横スクロールすると営業終了時間まで見ることができます。<br>
受付可能数は`▲`、`▼`をクリックすると変更することができます。(上限2まで)<br>
`前の日へ`、`次の日へ`をクリックして日にちを移動します。<br>
予約が入るとカスタマーの名前、選択されたメニュー名、施術時間分のカードが表示され、施術時間分の予約数が1増えて、残り受付可能数が1減ります。<br>
カードをクリックすると予約詳細に遷移します。<br>

<img width="30%" alt="美容師予約表" src="https://github.com/user-attachments/assets/553d737e-1c9a-49eb-bdea-01111a7b1a5f">


##### 予約詳細
変更するをクリックすると予約変更画面に遷移します。

<img width="30%" alt="美容師予約表,予約詳細" src="https://github.com/user-attachments/assets/11ecb931-a8d4-45fa-b6fc-caaf3205e7ea">


##### 予約の変更
来店日を休業日にすると来店時刻が00:00のみになり、変更を確定をクリックしても「選択した日にちは休業日です」
と表示されるようにしています。<br>
変更した日時に既に予約が存在して受付可能数の上限を超えていると「この時間帯は既に受付上限を超えています。」と表示されます。<br>
シフトによって営業時間が違う場合があるので、来店時刻のセレクトは日別の営業時間に合わせています。<br>
メニューはメニュー管理によって設定している掲載中のメニューのみ表示されています。

<img width="30%" alt="美容師予約表,予約変更" src="https://github.com/user-attachments/assets/5b0d6819-58b8-4064-bb92-31fb32bc118f">

### カスタマー

#### 予約

##### スタイリスト選択

過去3年以内に担当してもらった美容師が表示されています。<br>
初めての予約をする場合は美容師にメニュー画面を教えてもらって予約をします。

<img width="30%" alt="スタイリスト選択" src="https://github.com/user-attachments/assets/aea6cbf3-4f65-4488-b3a5-872b535e8286">


##### メニュー選択

美容師側で登録したメニューを選択します。<br>
掲載のメニューのみ表示されています。

<img width="30%" alt="メニュー選択" src="https://github.com/user-attachments/assets/8b498594-9ba2-4cef-9e11-56381fd30649">


##### 予約表

予約する日時を選択します。<br>
美容師の毎月の受付設定で設定したものが反映されています。

<img width="30%" alt="カスタマー予約表" src="https://github.com/user-attachments/assets/6c031783-0dc4-4a9b-b13b-7205de5ebdb5">


##### 予約確認

予約確定をクリックすると予約が確定されます。

<img width="30%" alt="カスタマー予約確認" src="https://github.com/user-attachments/assets/835f424b-ee4d-4812-bebf-745f9d048441">



##### 予約履歴

現在の予約、過去の予約が分かれて表示されています。

<img width="30%" alt="カスタマー予約履歴" src="https://github.com/user-attachments/assets/87ea5ae2-1e4e-4de5-99af-2979dcc65fa5">


###### 予約詳細

現在予約のみキャンセルボタンが表示されるようになっており、キャンセルすることができます。

<img width="30%" alt="カスタマー予約詳細" src="https://github.com/user-attachments/assets/b0fa81dd-b071-4741-8752-afa9e24b9750">


## 開発環境

- Ruby 3.3.5
- Rails 7.2.1.1
- Hotwire
- Tailwind CSS

## 環境構築

#### セットアップ

```bash
$ git clone https://github.com/自分のアカウント名/yoyaku-hub.git
$ cd yoyaku-hub
$ ./bin/setup
```

### ローカルサーバーの起動

```bash
./bin/dev
```

ブラウザから http://localhost:3000/ にアクセスします。
