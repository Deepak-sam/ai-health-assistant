import pytest

from app.security.auth import AllowlistError, AuthenticatedUser, check_allowlist


def test_allowlisted_user_passes():
    check_allowlist(AuthenticatedUser(uid="1", email="parent@example.com"))


def test_non_allowlisted_user_is_rejected():
    with pytest.raises(AllowlistError):
        check_allowlist(AuthenticatedUser(uid="2", email="stranger@example.com"))


def test_allowlist_check_is_case_insensitive():
    check_allowlist(AuthenticatedUser(uid="3", email="PARENT@EXAMPLE.COM".lower()))
