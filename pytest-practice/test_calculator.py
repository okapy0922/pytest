from calculator import add, divide
import pytest

# 足し算のパラメータ化テスト
@pytest.mark.parametrize("a,b,expected", [
    (2, 3, 5),
    (-1, 1, 0),
    (0, 0, 0),
])
def test_add(a, b, expected):
    assert add(a, b) == expected

# 割り算のパラメータ化テスト
@pytest.mark.parametrize("a,b,expected", [
    (10, 2, 5),
    (9, 3, 3),
])
def test_divide(a, b, expected):
    assert divide(a, b) == expected

# 0割りのエラー確認
def test_divide_zero():
    with pytest.raises(ValueError):
        divide(10, 0)
