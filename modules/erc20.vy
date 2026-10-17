# pragma version ==0.4.3
# pragma nonreentrancy on
"""
@title ERC20
@notice Minimal ERC20 accounting module. Holds balances, allowances
        and total supply, and exposes the standard ERC20 functions.
"""

from ethereum.ercs import IERC20
implements: IERC20


_balances: HashMap[address, uint256]
_allowances: HashMap[address, HashMap[address, uint256]]
_total_supply: uint256


@view
@external
def balanceOf(owner: address) -> uint256:
    return self._balances[owner]


@view
@external
def allowance(owner: address, spender: address) -> uint256:
    return self._allowances[owner][spender]


@view
@external
def totalSupply() -> uint256:
    return self._total_supply


@external
def approve(spender: address, amount: uint256) -> bool:
    self._approve(msg.sender, spender, amount)
    return True


@external
def transfer(receiver: address, amount: uint256) -> bool:
    self._transfer(msg.sender, receiver, amount)
    return True


@external
def transferFrom(owner: address, receiver: address, amount: uint256) -> bool:
    self._spend_allowance(owner, msg.sender, amount)
    self._transfer(owner, receiver, amount)
    return True


@internal
def _approve(owner: address, spender: address, amount: uint256):
    self._allowances[owner][spender] = amount
    log IERC20.Approval(owner=owner, spender=spender, value=amount)


@internal
def _transfer(sender: address, receiver: address, amount: uint256):
    assert receiver != empty(address), "erc20: transfer to zero address"
    # Vyper arithmetic is checked: this reverts if the balance is too low.
    self._balances[sender] -= amount
    self._balances[receiver] += amount
    log IERC20.Transfer(sender=sender, receiver=receiver, value=amount)


@internal
def _spend_allowance(owner: address, spender: address, amount: uint256):
    allowed: uint256 = self._allowances[owner][spender]
    # An allowance of max_value(uint256) is treated as infinite.
    if allowed != max_value(uint256):
        self._allowances[owner][spender] = allowed - amount


@internal
def _mint(receiver: address, amount: uint256):
    assert receiver != empty(address), "erc20: mint to zero address"
    self._balances[receiver] += amount
    self._total_supply += amount
    log IERC20.Transfer(sender=empty(address), receiver=receiver, value=amount)


@internal
def _burn(owner: address, amount: uint256):
    self._balances[owner] -= amount
    self._total_supply -= amount
    log IERC20.Transfer(sender=owner, receiver=empty(address), value=amount)
