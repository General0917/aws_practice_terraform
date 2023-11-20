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