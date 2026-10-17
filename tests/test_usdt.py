import boa
import pytest

INITIAL_SUPPLY = 1_000_000 * 10**6  # 1M USDT, 6 decimals


@pytest.fixture
def owner():
    return boa.env.eoa


@pytest.fixture
def alice():
    return boa.env.generate_address("alice")


@pytest.fixture
def bob():
    return boa.env.generate_address("bob")


@pytest.fixture
def usdt():
    return boa.load("contracts/usdt.vy", INITIAL_SUPPLY)


def test_metadata(usdt, owner):
    assert usdt.name() == "Tether USD"
    assert usdt.symbol() == "USDT"
    assert usdt.decimals() == 6
    assert usdt.totalSupply() == INITIAL_SUPPLY
    assert usdt.balanceOf(owner) == INITIAL_SUPPLY
    assert usdt.owner() == owner


def test_transfer(usdt, owner, alice):
    assert usdt.transfer(alice, 100) is True
    assert usdt.balanceOf(alice) == 100
    assert usdt.balanceOf(owner) == INITIAL_SUPPLY - 100


def test_transfer_insufficient_balance(usdt, alice, bob):
    with boa.env.prank(alice), boa.reverts():
        usdt.transfer(bob, 1)


def test_transfer_from(usdt, owner, alice, bob):
    usdt.approve(alice, 500)
    with boa.env.prank(alice):
        assert usdt.transferFrom(owner, bob, 200) is True
    assert usdt.balanceOf(bob) == 200
    assert usdt.allowance(owner, alice) == 300


def test_approve_must_reset_to_zero(usdt, alice):
    usdt.approve(alice, 500)
    with boa.reverts("usdt: reset allowance to zero first"):
        usdt.approve(alice, 100)
    usdt.approve(alice, 0)
    usdt.approve(alice, 100)
    assert usdt.allowance(boa.env.eoa, alice) == 100


def test_issue_and_redeem(usdt, owner, alice):
    usdt.issue(1_000)
    assert usdt.totalSupply() == INITIAL_SUPPLY + 1_000
    assert usdt.balanceOf(owner) == INITIAL_SUPPLY + 1_000

    usdt.redeem(1_000)
    assert usdt.totalSupply() == INITIAL_SUPPLY

    with boa.env.prank(alice), boa.reverts("ownable: caller is not the owner"):
        usdt.issue(1_000)


def test_pause(usdt, alice):
    usdt.pause()
    assert usdt.paused()
    with boa.reverts("pausable: paused"):
        usdt.transfer(alice, 1)

    usdt.unpause()
    usdt.transfer(alice, 1)
    assert usdt.balanceOf(alice) == 1


def test_only_owner_can_pause(usdt, alice):
    with boa.env.prank(alice), boa.reverts("ownable: caller is not the owner"):
        usdt.pause()


def test_blacklist(usdt, owner, alice, bob):
    usdt.transfer(alice, 100)
    usdt.addBlackList(alice)
    assert usdt.isBlackListed(alice)

    # Alice can't send...
    with boa.env.prank(alice), boa.reverts("blacklist: account is blacklisted"):
        usdt.transfer(bob, 1)

    # ...and nobody can move her funds with an allowance either.
    with boa.env.prank(alice):
        usdt.approve(bob, 100)
    with boa.env.prank(bob), boa.reverts("blacklist: account is blacklisted"):
        usdt.transferFrom(alice, bob, 1)

    usdt.removeBlackList(alice)
    with boa.env.prank(alice):
        usdt.transfer(bob, 1)
    assert usdt.balanceOf(bob) == 1


def test_destroy_black_funds(usdt, alice):
    usdt.transfer(alice, 100)

    with boa.reverts("blacklist: account not blacklisted"):
        usdt.destroyBlackFunds(alice)

    usdt.addBlackList(alice)
    usdt.destroyBlackFunds(alice)
    assert usdt.balanceOf(alice) == 0
    assert usdt.totalSupply() == INITIAL_SUPPLY - 100


def test_transfer_ownership(usdt, alice):
    usdt.transferOwnership(alice)
    assert usdt.owner() == alice
    with boa.reverts("ownable: caller is not the owner"):
        usdt.pause()
    with boa.env.prank(alice):
        usdt.pause()
