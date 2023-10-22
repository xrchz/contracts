#pragma version ^0.3.0

# ERC20 Pledging System
#
# Create a matching pledge to buy (on Balancer) a token at a particular price
# (or better) by a deadline, using a particular sell token, as long as a target
# buy amount is reached. Either everyone buys the token together, or everyone
# is refunded their sell token.

interface ERC20:
  def balanceOf(_who: address) -> uint256: view
  def approve(_who: address, _amount: uint256) -> bool: nonpayable
  def transfer(_to: address, _amount: uint256) -> bool: nonpayable
  def transferFrom(_from: address, _to: address, _amount: uint256) -> bool: nonpayable

enum SwapKind:
  GIVEN_IN
  GIVEN_OUT

struct SingleSwap:
  poolId: bytes32
  kind: SwapKind
  assetIn: address
  assetOut: address
  amount: uint256
  userData: Bytes[1]

struct FundManagement:
  sender: address
  fromInternalBalance: bool
  recipient: address
  toInternalBalance: bool

enum UserBalanceOpKind:
    DEPOSIT_INTERNAL
    WITHDRAW_INTERNAL
    TRANSFER_INTERNAL
    TRANSFER_EXTERNAL

struct UserBalanceOp:
    kind: UserBalanceOpKind
    asset: address
    amount: uint256
    sender: address
    recipient: address

selfFunds: immutable(FundManagement)

MAX_TOKENS_PER_POOL: constant(uint256) = 4

interface BalancerVault:
  def swap(singleSwap: SingleSwap, funds: FundManagement, limit: uint256, deadline: uint256) -> uint256: payable
  def getPoolTokens(poolId: bytes32) -> (
    DynArray[ERC20, MAX_TOKENS_PER_POOL],
    DynArray[uint256, MAX_TOKENS_PER_POOL],
    uint256): view
  def manageUserBalance(ops: DynArray[UserBalanceOp, 1]): nonpayable


vault: immutable(BalancerVault)

struct Pledge:
  poolId: bytes32
  deadline: uint256 # timestamp by which the pledge must be executed, else it will be refunded
  buyToken: ERC20   # pledging to buy this token
  minBuy: uint256   # pledge succeeds only if at least this amount will be bought in total
  sellToken: ERC20  # pledge succeeds only if the price for buying minBuy
  maxSellForMin: uint256 # of buyToken is no more than maxSellForMin of sellToken

# Pledges with a numeric ID (ever-increasing nonce)
pledges: HashMap[uint256, Pledge]
numPledges: uint256

# whether the pledge has been executed (i.e. sellToken sold for buyToken)
executed: HashMap[uint256, bool]

# total amount pledged (including refunded or sold) per pledge
# total amount of sellToken pledged for which buy token has been paid out
totalPledged: HashMap[uint256, uint256]
totalPaidFor: HashMap[uint256, uint256]

# amount pledged (and not refunded) per user, per pledge id
pledged: HashMap[address, HashMap[uint256, uint256]]

@external
def __init__():
  vault = BalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8)
  selfFunds = FundManagement({
    sender: self,
    fromInternalBalance: True,
    recipient: self,
    toInternalBalance: True
  })

@external
def create(pledge: Pledge, buyTokenIndex: uint256, sellTokenIndex: uint256):
  assert block.timestamp < pledge.deadline, "deadline must be in future"
  tokens: DynArray[ERC20, MAX_TOKENS_PER_POOL] = vault.getPoolTokens(pledge.poolId)[0]
  assert tokens[buyTokenIndex] == pledge.buyToken, "buyToken"
  assert tokens[sellTokenIndex] == pledge.sellToken, "sellToken"
  self.pledges[self.numPledges] = pledge
  self.numPledges += 1
  # TODO: emit log

@external
def pledge(id: uint256, amount: uint256):
  pledge: Pledge = self.pledges[id]
  assert block.timestamp < pledge.deadline, "expired"
  assert not self.executed[id], "executed"
  assert pledge.sellToken.transferFrom(msg.sender, self, amount), "transferFrom"
  assert pledge.sellToken.approve(vault.address, amount), "approve"
  vault.manageUserBalance([UserBalanceOp({
    kind: UserBalanceOpKind.DEPOSIT_INTERNAL,
    asset: pledge.sellToken.address,
    amount: amount,
    sender: self,
    recipient: self
  })])
  self.pledged[msg.sender][id] += amount
  self.totalPledged[id] += amount
  # TODO: emit log

@external
def execute(id: uint256):
  assert id < self.numPledges, "id"
  pledge: Pledge = self.pledges[id]
  assert block.timestamp < pledge.deadline, "expired"
  assert not self.executed[id], "executed"
  sellAmount: uint256 = self.totalPledged[id]
  swap: SingleSwap = SingleSwap({
    poolId: pledge.poolId,
    kind: SwapKind.GIVEN_IN,
    assetIn: pledge.sellToken.address,
    assetOut: pledge.buyToken.address,
    amount: sellAmount,
    userData: b''})
  limit: uint256 = sellAmount / pledge.maxSellForMin * pledge.minBuy
  amountOut: uint256 = vault.swap(swap, selfFunds, limit, block.timestamp)
  assert amountOut > pledge.minBuy, "minBuy"
  assert amountOut / pledge.minBuy * pledge.maxSellForMin <= sellAmount, "price"
  self.executed[id] = True
  # TODO: emit log

@external
def claim(id: uint256):
  assert id < self.numPledges, "id"
  pledge: Pledge = self.pledges[id]
  assert self.executed[id], "pending"
  # TODO: transfer buy token to sender
  # TODO: increment total paid for
  # TODO: emit log

# TODO: add claimer for rounding dust

@external
def refund(id: uint256):
  assert id < self.numPledges, "id"
  pledge: Pledge = self.pledges[id]
  assert pledge.deadline < block.timestamp, "active"
  assert not self.executed[id], "executed"
  amount: uint256 = self.pledged[msg.sender][id]
  assert 0 < amount, "empty"
  vault.manageUserBalance([UserBalanceOp({
    kind: UserBalanceOpKind.WITHDRAW_INTERNAL,
    asset: pledge.sellToken.address,
    amount: amount,
    sender: self,
    recipient: self
  })])
  assert pledge.sellToken.transfer(msg.sender, amount), "transfer"
  self.pledged[msg.sender][id] = 0
  # TODO: emit log
