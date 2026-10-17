# pragma version ==0.4.3
# pragma nonreentrancy on
"""
@title Tether USD (Vyper edition)
@notice An educational rebuild of the USDT Ethereum contract: an ERC20
        token that the owner can issue, redeem, pause and freeze.
"""

from ethereum.ercs import IERC20
implements: IERC20


from ethereum.ercs import IERC20Detailed
implements: IERC20Detailed


from ..modules import ownable
initializes: ownable


from ..modules import erc20
initializes: erc20


from ..modules import pausable
initializes: pausable[ownable := ownable]


from ..modules import blacklist
initializes: blacklist[ownable := ownable, erc20 := erc20]


exports: (
    erc20.balanceOf,
    erc20.allowance,
    erc20.totalSupply,
    ownable.owner,
    ownable.transferOwnership,
    pausable.paused,
    pausable.pause,
    pausable.unpause,
    blacklist.isBlackListed,
    blacklist.addBlackList,
    blacklist.removeBlackList,
    blacklist.destroyBlackFunds,
)


event Issue:
    amount: uint256


event Redeem:
    amount: uint256


@deploy
def __init__(initial_supply: uint256):
    ownable.__init__()
    erc20._mint(msg.sender, initial_supply)


@view
@external
def name() -> String[10]:
    return "Tether USD"


@view
@external
def symbol() -> String[4]:
    return "USDT"


@view
@external
def decimals() -> uint8:
    return 6


@external
def transfer(receiver: address, amount: uint256) -> bool:
    pausable._require_not_paused()
    blacklist._require_not_blacklisted(msg.sender)
    erc20._transfer(msg.sender, receiver, amount)
    return True


@external
def transferFrom(owner: address, receiver: address, amount: uint256) -> bool:
    pausable._require_not_paused()
    blacklist._require_not_blacklisted(owner)
    erc20._spend_allowance(owner, msg.sender, amount)
    erc20._transfer(owner, receiver, amount)
    return True


@external
def approve(spender: address, amount: uint256) -> bool:
    # Same rule as the original USDT: to change a non-zero allowance you
    # must first set it to zero. This mitigates the approve front-running
    # race, but it's also why `approve` on USDT trips up many integrations.
    assert amount == 0 or erc20._allowances[msg.sender][spender] == 0, "usdt: reset allowance to zero first"
    erc20._approve(msg.sender, spender, amount)
    return True


@external
def issue(amount: uint256):
    """
    @notice Mint new tokens to the owner. In practice this happens after an
            institution has wired dollars to Tether.
    """
    ownable._check_owner()
    erc20._mint(ownable.owner, amount)
    log Issue(amount=amount)


@external
def redeem(amount: uint256):
    """
    @notice Burn tokens from the owner's balance, e.g. after an institution
            has sent USDT back to Tether in exchange for dollars.
    """
    ownable._check_owner()
    erc20._burn(ownable.owner, amount)
    log Redeem(amount=amount)
