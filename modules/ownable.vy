# pragma version ==0.4.3
# pragma nonreentrancy on
"""
@title Ownable
@notice Single-owner access control. Other modules call `_check_owner()`
        to restrict functions to the owner.
"""

event OwnershipTransferred:
    previous_owner: indexed(address)
    new_owner: indexed(address)


owner: public(address)


@deploy
def __init__():
    self._transfer_ownership(msg.sender)


@external
def transferOwnership(new_owner: address):
    self._check_owner()
    assert new_owner != empty(address), "ownable: new owner is zero address"
    self._transfer_ownership(new_owner)


@internal
def _check_owner():
    assert msg.sender == self.owner, "ownable: caller is not the owner"


@internal
def _transfer_ownership(new_owner: address):
    previous_owner: address = self.owner
    self.owner = new_owner
    log OwnershipTransferred(previous_owner=previous_owner, new_owner=new_owner)
