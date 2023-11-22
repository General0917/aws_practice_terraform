# aws cliでのログインする際の設定方法
以下のリンクを参考に、aws cliのログイン設定をする
https://qiita.com/Mayumi_Pythonista/items/324c16ca98435df7d78d

# aws ユーザー変更の手順

- 以下のコマンドを実行してawsユーザーリストを確認する

```
aws configure list
```

- 切り替えたいユーザーをexportさせる

```
vi ~/.bashrc

export AWS_DEFAULT_PROFILE=ユーザー名
```