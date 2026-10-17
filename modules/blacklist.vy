# pragma version ==0.4.3
# pragma nonreentrancy on
"""
@title BlackList
@notice Lets the owner freeze addresses and destroy the funds they hold.
"""

from . import ownable
uses: ownable


from . import erc20
uses: erc20


event AddedBlackList:
    account: indexed(address)


event RemovedBlackList:
    account: indexed(address)


event DestroyedBlackFunds:
    account: indexed(address)
    amount: uint256


is_black_listed: HashMap[address, bool]


@view
@external
def isBlackListed(account: address) -> bool:
    return self.is_black_listed[account]


@external
def addBlackList(account: address):
    ownable._check_owner()
    self.is_black_listed[account] = True
    log AddedBlackList(account=account)


@external
def removeBlackList(account: address):
    ownable._check_owner()
    self.is_black_listed[account] = False
    log RemovedBlackList(account=account)


@external
def destroyBlackFunds(account: address):
    ownable._check_owner()
    assert self.is_black_listed[account], "blacklist: account not blacklisted"
    amount: uint256 = erc20._balances[account]
    erc20._burn(account, amount)
    log DestroyedBlackFunds(account=account, amount=amount)


@internal
def _require_not_blacklisted(account: address):
    assert not self.is_black_listed[account], "blacklist: account is blacklisted"
