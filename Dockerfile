# ベースイメージとしてUbuntuを指定
FROM ubuntu:20.04

# タイムゾーンの設定を非対話的に行うための環境変数
ENV DEBIAN_FRONTEND=noninteractive

# システムのアップデートと必要なパッケージのインストール
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    curl \
    vim \
    && rm -rf /var/lib/apt/lists/*

# コンテナ起動時のコマンドを指定
CMD ["/bin/bash"]