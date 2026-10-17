# pragma version ==0.4.3
# pragma nonreentrancy on
"""
@title Pausable
@notice Emergency stop switch controlled by the owner.
"""

from . import ownable
uses: ownable


event Pause:
    account: address


event Unpause:
    account: address


paused: public(bool)


@external
def pause():
    ownable._check_owner()
    assert not self.paused, "pausable: already paused"
    self.paused = True
    log Pause(account=msg.sender)


@external
def unpause():
    ownable._check_owner()
    assert self.paused, "pausable: not paused"
    self.paused = False
    log Unpause(account=msg.sender)


@internal
def _require_not_paused():
    assert not self.paused, "pausable: paused"
