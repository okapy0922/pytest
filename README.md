# pytest 練習環境

このリポジトリは、Python のテストフレームワーク **pytest** の練習用です。  
シンプルな計算関数 (`add`, `divide`) を対象にテストを実装しています。

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
