# pytest 練習環境

このリポジトリは、Python のテストフレームワーク **pytest** の練習用です。  
シンプルな計算関数 (`add`, `divide`) を対象にテストを実装しています。

このリポジトリでやっていること

Python初心者のわたしが pytestの基本的な使い方 を学ぶための練習です。
2つの関数（足し算と割り算）を題材にして、以下のポイントを実践しています。

関数の正しい動作を 自動で確認するテスト を書く練習

・@pytest.mark.parametrize を使って 複数の入力パターン をまとめて検証

・pytest.raises で エラーが正しく発生するかの確認

・poetry を使った 仮想環境と依存パッケージの管理方法 の理解

テストを実行すると、「どの関数が正しく動くか」「どんな条件で失敗するか」が自動で確認できます。
学習目的：テストの書き方と自動化の流れを理解すること

---

## ファイル構成

├── calculator.py # 計算用の関数を定義

└── test_calculator.py # pytest で実行するテスト

## 導入手順

### 1. 仮想環境の作成（任意）
環境を分離したい場合は以下を実行してください。

```bash
python -m venv venv
source venv/bin/activate   # macOS/Linux
venv\Scripts\activate      # Windows
```

## pytestインストール
```bash
pip install pytest
```

## 実行
```bash
pytest
============================================================ test session starts =============================================================
platform linux -- Python 3.10.12, pytest-8.4.1, pluggy-1.6.0
rootdir: /home/okapy/cleaned-repo/pytest-practice
collected 6 items

test_calculator.py ......                                                                                                              [100%]

============================================================= 6 passed in 0.01s ==============================================================
```

---

## Poetry を使ったセットアップ

Python 3.13 + Poetry 環境で、このpytest練習 を管理する手順です。

### 事前準備（リポジトリをローカルにもってくる）

```bash
git clone https://github.com/okapy0922/pytest.git
cd pytest
```

### 1. Poetry プロジェクト作成

```bash
poetry init
```
・Package name: pytest-practice（デフォルトでもOK）
・Version / Description / Author / License: 任意で入力
・Compatible Python versions: >=3.13
・Main dependencies / Development dependencies: Enter でスキップ
・生成確認: yes
→ これで pyproject.toml が生成されます。

### 2. 仮想環境作成＆依存関係インストール

```bash
poetry install
```

### 3. pytest を開発依存として追加 する

```bash
poetry add --dev pytest

Creating virtualenv pytest-practice--EF3RZN2-py3.13 in /home/okapy/.cache/pypoetry/virtualenvs Using version ^8.4.2 for pytest Updating dependencies Resolving dependencies... (0.3s) Package operations: 5 installs, 0 updates, 0 removals - Installing iniconfig (2.1.0) - Installing packaging (25.0) - Installing pluggy (1.6.0) - Installing pygments (2.19.2) - Installing pytest (8.4.2) Writing lock file
```

### 4. pytest実行
```bash

 poetry run pytest
=============================================================================== test session starts ================================================================================
platform linux -- Python 3.13.7, pytest-8.4.2, pluggy-1.6.0
rootdir: /home/okapy/pytest
configfile: pyproject.toml
collected 6 items

pytest-practice/test_calculator.py ......                                                                                                                                    [100%]

================================================================================ 6 passed in 0.01s =================================================================================
```
### 5. 仮想環境の有効化（Poetry環境を使う）
#### プロジェクト用の仮想環境一覧を確認
poetry env list

#### 環境を指定して有効化（例: py3.13）
poetry env use python3.13

#### pytest実行
poetry run pytest

