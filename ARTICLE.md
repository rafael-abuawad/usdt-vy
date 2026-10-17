# How USDT Actually Works: From Treasury Bills to Smart Contracts

USDT is one of the largest stablecoins in the world, and most people who use it every day have no idea how it works. In this article we'll look at it from both ends: the business model that keeps it pegged to the dollar, and the smart contract that makes it move onchain. By the end, you'll have built your own version of USDT in Vyper.

## Tether vs. USDT

First, the names. **Tether** is the company. **USDT** is the token it issues.

Tether manages the reserves that, in theory, back every USDT in existence across every chain it lives on: Ethereum, Tron, Solana, and many others. Each USDT is supposed to be redeemable for one US dollar, and Tether's reserves are what make that promise credible.

## Where the money actually goes

This is where it gets interesting. Tether doesn't keep a giant pile of dollars in a vault. Most of its reserves are held in **US Treasury bills**, which are short-term debt issued by the US government. The rest is a mix of cash equivalents, gold, Bitcoin, and secured loans.

The scale is huge. Tether is one of the largest holders of US government debt in the world, ranking alongside entire countries. It has said it was among the top buyers of US Treasuries, competing with nations like Germany and South Korea.

### What's a Treasury bill?

A Treasury bill (T-bill) is a short-term loan to the US government, maturing in one year or less. T-bills don't pay coupons. You buy them at a discount and receive the full face value at maturity, and the difference is your interest.

For example, you might pay $95,000 for a T-bill that pays you $100,000 a year later. That $5,000 is your return.

T-bills are considered about as close to risk-free as an investment gets, and they're highly liquid. That matters for a stablecoin: if many people want to redeem USDT at once, Tether needs to turn its reserves into cash quickly.

## The business model

Look at this from Tether's side. People hand Tether dollars to get USDT, and USDT pays them no interest. Tether takes those dollars, buys T-bills, and keeps the yield.

With over a hundred billion dollars in reserves, even a 4–5% yield adds up to billions per year. That's why Tether is one of the most profitable companies in the world per employee. It reported roughly $10 billion in net profit in 2025, and it has a relatively small team.

It's a brilliant model. You create a digital dollar that people around the world use to save and transact, and in return you slowly build one of the largest Treasury portfolios on the planet.

### What about fees?

If you've ever sent USDT, you've noticed that sending 1 USDT means the recipient gets 1 USDT. The gas fee goes to the blockchain's validators, not to Tether. So Tether doesn't earn anything from everyday transfers.

Where Tether *does* charge fees is at the edges of the system: **minting and redemption**. Regular users don't deal with Tether directly. Large, verified institutions such as exchanges, market makers, and payment companies deposit dollars to mint new USDT, or send USDT back to redeem dollars. Tether charges a small percentage fee on these operations and requires high minimums. It's a nice revenue stream, but the real money comes from the reserves.

Tether has other products and investments that we won't cover here. If you're curious, check out [tether.to](https://tether.to/).

## The catch: it's centralized

Everything above depends on trusting Tether. The peg holds because the market believes Tether actually has the reserves and will honor redemptions. Tether publishes quarterly **attestations** of its reserves, prepared by an accounting firm. But an attestation is a snapshot of holdings on a given date, not a full audit, and Tether has faced criticism over the years about transparency.

The smart contract reflects this centralization too. As we'll see, Tether can mint tokens, burn them, pause the contract, and freeze specific addresses.

## Going to the source code

Now for the fun part. We'll look at USDT's [Ethereum implementation](https://etherscan.io/address/0xdac17f958d2ee523a2206206994597c13d831ec7#code) and rebuild it ourselves in [Vyper](https://vyperlang.org/), a Pythonic language for writing Ethereum smart contracts.

If you're new to programming or Ethereum, don't worry. We'll go step by step.

### USDT is (mostly) an ERC20

**ERC20** is the Ethereum standard for fungible tokens. It's a small interface: six core functions (`totalSupply`, `balanceOf`, `transfer`, `transferFrom`, `approve`, `allowance`), three optional metadata functions (`name`, `symbol`, `decimals`), and two events (`Transfer`, `Approval`). Any contract that implements this interface can be held in wallets, traded on exchanges, and shown on block explorers as a token.

Here's a fun detail: the USDT contract on Ethereum **isn't fully ERC20-compliant**. It was written in 2017 in an old version of Solidity, and its `transfer` and `transferFrom` functions don't return a `bool` as the standard requires. This has broken many DeFi integrations over the years, and it's the reason libraries like OpenZeppelin's `SafeERC20` exist. We'll come back to this when we write our own version.

### Setting up the project

We'll keep the setup minimal. We'll use [uv](https://docs.astral.sh/uv/getting-started/installation/) to manage dependencies and [Titanoboa](https://titanoboa.readthedocs.io/en/latest/) to compile and test our Vyper code.

1. Install uv.
2. Create the project: `uv init <project_name>`, move into it with `cd <project_name>`, then delete the generated `main.py`.
3. Create a virtual environment: `uv venv`
4. Activate it:
   - Linux/macOS: `source .venv/bin/activate`
   - Windows: `.venv\Scripts\activate`
5. Install Titanoboa: `uv add titanoboa`
6. Install pytest for testing: `uv add --dev pytest`

Titanoboa installs the Vyper compiler as a dependency. This article uses **Vyper 0.4.3**, and every file starts with `# pragma version ==0.4.3` to pin it.

### Project structure

```
<project_name>/
├── modules/          # reusable modules
│   ├── erc20.vy
│   ├── ownable.vy
│   ├── pausable.vy
│   └── blacklist.vy
├── contracts/        # smart contracts
│   └── usdt.vy
├── tests/            # tests
│   └── test_usdt.py
└── pyproject.toml
```

### A quick word on modules

Solidity reuses code through **inheritance**. The original USDT is a tower of contracts: `TetherToken` inherits from `Pausable`, `StandardToken` and `BlackList`, which in turn inherit from `Ownable` and `BasicToken`.

Vyper takes a different approach: **modules**. A module is a regular `.vy` file with state and functions that a contract can import and reuse. There are no `virtual` or `override` keywords. Instead, a contract chooses which of a module's external functions to **export** into its own ABI. If it needs different behavior, it skips the export and writes its own version on top of the module's internal helpers.

We'll build four modules, one for each piece of the original contract, and then assemble them into the token.

### ERC20

The first module holds the token's books: who owns how much (`_balances`), who may spend whose tokens (`_allowances`), and how many tokens exist (`_total_supply`).

It has two layers. The standard ERC20 functions are external, so any contract can export them as they are. The real logic lives in internal functions (`_transfer`, `_approve`, `_spend_allowance`, `_mint`, `_burn`) that other contracts can build on. That split will matter when USDT adds its own rules to `transfer`.

```python
# modules/erc20.vy
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
```

A few things worth noticing:

- **No `SafeMath`.** The 2017 USDT contract needed a `SafeMath` library to guard against overflows. Vyper checks all arithmetic by default, so `self._balances[sender] -= amount` simply reverts if the sender doesn't have enough.
- **`implements: IERC20`** makes the compiler check that we match the standard, including returning `bool` from `transfer` and `transferFrom`. With this line, the compiler would have caught the original USDT's missing return value.
- **Minting is a transfer from the zero address, and burning is a transfer to it.** This is the standard way to log supply changes, and block explorers rely on these `Transfer` events.
- **`# pragma nonreentrancy on`** puts a reentrancy lock on every external function. Our token never calls other contracts, but it's a sensible default that costs us nothing to turn on.

### Ownable

USDT is centralized, and this is the module that makes it so. `Ownable` stores one address, the `owner`, and gives other code a way to say "only the owner can do this."

```python
# modules/ownable.vy
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
```

`@deploy` marks the constructor. It runs once, when the contract is deployed, and makes the deployer the owner. `public(address)` tells Vyper to generate an `owner()` getter for us.

Solidity uses an `onlyOwner` modifier here. Vyper has no modifiers, so we call `_check_owner()` on the first line of each restricted function. It's more explicit, and you can see every check when you read the code.

### Pausable

Pausable is an emergency brake. If something goes wrong, such as a hack or a bug, the owner can freeze all transfers at once.

```python
# modules/pausable.vy
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
```

The key line is **`uses: ownable`**. Pausable needs to read the owner, but it shouldn't *own* the `Ownable` state. If it did, our final contract could end up with two owners. `uses` means "I depend on a module that someone else will initialize." When we assemble the token, we'll tell the compiler which `ownable` to plug in.

`_require_not_paused()` is the hook the token will call at the start of `transfer` and `transferFrom`.

### BlackList

This is the feature people talk about most. Tether can **freeze** any address, and it does so regularly, often at the request of law enforcement. The original contract can also **destroy** the funds of a blacklisted address, which removes those tokens from circulation. Tether can then reissue them elsewhere, for example to the victim of a hack.

```python
# modules/blacklist.vy
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
```

This module `uses` two modules. It needs `ownable` for access control and `erc20` so that `destroyBlackFunds` can read a balance and burn it.

Notice the two naming styles. Inside the module, the storage variable is `is_black_listed`, in Python-style snake_case. But the external functions and events (`isBlackListed`, `addBlackList`, `destroyBlackFunds`, and so on) keep the camelCase names of the original contract. The explicit `isBlackListed` getter is the bridge between the two.

Note that `destroyBlackFunds` only works on an address that is already blacklisted. Tether has to freeze the funds before it can destroy them.

### USDT Token

Now we bring all the modules together.

```python
# contracts/usdt.vy
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
```

Let's go through it piece by piece.

**`initializes`** says this contract owns the state of each module and is responsible for setting it up. This is where the `uses` dependencies get wired together. `pausable[ownable := ownable]` means "the `ownable` that Pausable depends on is *this* `ownable`." As a result, the whole contract shares a single owner and a single set of balances. The compiler checks this wiring for you. If you forget to initialize a module, or initialize one twice, the contract won't compile.

**`exports`** picks which module functions become part of the token's public ABI. The getters and admin functions are exported as they are. Notice that `erc20.transfer`, `erc20.transferFrom` and `erc20.approve` are *not* exported.

**We write our own `transfer`, `transferFrom` and `approve`** because USDT needs extra rules before a transfer goes through:

1. The contract must not be paused.
2. The sender (or, for `transferFrom`, the token owner) must not be blacklisted.

After those checks, we hand off to the ERC20 module's internal `_transfer`. Checking the *token owner* in `transferFrom` matters. Otherwise a frozen address could approve a friend, and the friend could move the funds out.

**The `approve` quirk.** The real USDT refuses to change an allowance from one non-zero value to another. You must set it to `0` first. This is meant to block a front-running attack on `approve`, and it's another famous source of broken integrations. We kept it so our token behaves like the real one.

**`issue` and `redeem`** are the onchain side of the business model. When an institution wires dollars to Tether, Tether calls `issue` to mint fresh USDT to its own treasury and then sends the tokens to the customer. When the customer sends USDT back for dollars, Tether calls `redeem` to burn them.

**What we left out.** The real contract has two more features that we skipped:

- **Transfer fee:** `basisPointsRate` and `maximumFee` allow a fee on every transfer. It has always been set to zero, which is why, as we saw earlier, Tether earns nothing from transfers.
- **Upgrade:** `deprecate` and `upgradedAddress` let Tether point all calls to a new contract.

**What we did differently.** Our `transfer` and `transferFrom` return `bool`, as ERC20 requires, so our token works with any DeFi protocol without special wrappers. Our `issue` also emits a standard `Transfer` event, which the 2017 contract doesn't.

## Testing our USDT

Titanoboa lets us deploy the contract to a local EVM from Python and call it like a regular object. Create `tests/test_usdt.py`:

```python
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
```

A few Titanoboa tools do most of the work here:

- `boa.load` compiles the contract and deploys it, passing `INITIAL_SUPPLY` to the constructor.
- `boa.env.eoa` is the default account that sends our transactions, so it's also the deployer and owner.
- `boa.env.prank(alice)` sends the calls inside the `with` block as Alice.
- `boa.reverts("...")` checks that a call fails with the expected error message.

Run the suite from the project root:

```
$ pytest
...........                                                              [100%]
11 passed
```

## Wrapping up

Strip away the billions of dollars, and USDT is a surprisingly small program. It's an ERC20 token with four admin powers: **issue**, **redeem**, **pause** and **blacklist**. Every one of them belongs to a single owner.

That's the whole story in code. The token is only worth a dollar because Tether holds T-bills offchain and honors redemptions, and the contract gives Tether complete control over who can hold and move it. Decentralized it is not, but it's one of the most successful products crypto has produced.

You now have a working version of it. Some ideas to take it further:

- Add the transfer fee (`basisPointsRate` and `maximumFee`) from the original contract.
- Replace the single owner with multiple roles, for example separate minter, pauser and blacklister addresses, the way newer stablecoins do.
- Deploy it to a testnet and add it to your wallet.

Just don't expect it to hold its peg without a hundred billion dollars in Treasury bills behind it.
