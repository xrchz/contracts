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

struct PledgeInfo:
  poolId: bytes32
  deadline: uint256 # timestamp by which the pledge must be executed, else it will be refunded
  buyToken: ERC20   # pledging to buy this token
  minBuy: uint256   # pledge succeeds only if at least this amount will be bought in total
  sellToken: ERC20  # pledge succeeds only if the price for buying minBuy
  maxSellForMin: uint256 # of buyToken is no more than maxSellForMin of sellToken

# Pledges with a numeric ID (ever-increasing nonce)
pledges: public(HashMap[uint256, PledgeInfo])
numPledges: public(uint256)

# total amount pledged (including refunded or sold) per pledge
totalPledged: public(HashMap[uint256, uint256])

# total amount of buyToken bought for sellToken (0 if not executed)
totalBought: public(HashMap[uint256, uint256])

# total of the bought buyToken that has been paid out
totalClaimed: public(HashMap[uint256, uint256])

# pledgers who have not yet claimed or refunded
activePledgers: public(HashMap[uint256, uint256])

# amount pledged (and not refunded or sold) per user per pledge id
pledged: public(HashMap[uint256, HashMap[address, uint256]])

event Create:
  pledgeId: indexed(uint256)
  buyToken: indexed(address)
  sellToken: indexed(address)
  minBuy: uint256
  maxSellForMin: uint256
  deadline: uint256

event Pledge:
  pledgeId: indexed(uint256)
  pledger: indexed(address)
  amount: indexed(uint256)

event Execute:
  pledgeId: indexed(uint256)
  sellAmount: indexed(uint256)
  buyAmount: indexed(uint256)

event Claim:
  pledgeId: indexed(uint256)
  pledger: indexed(address)
  buyAmount: indexed(uint256)
  sellAmount: uint256

event Dust:
  pledgeId: indexed(uint256)
  duster: indexed(address)
  amount: indexed(uint256)

event Refund:
  pledgeId: indexed(uint256)
  pledger: indexed(address)
  amount: indexed(uint256)

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
def create(pledge: PledgeInfo, buyTokenIndex: uint256, sellTokenIndex: uint256):
  assert block.timestamp < pledge.deadline, "deadline"
  assert 0 < pledge.minBuy, "minBuy"
  tokens: DynArray[ERC20, MAX_TOKENS_PER_POOL] = vault.getPoolTokens(pledge.poolId)[0]
  assert tokens[buyTokenIndex] == pledge.buyToken, "buyToken"
  assert tokens[sellTokenIndex] == pledge.sellToken, "sellToken"
  self.pledges[self.numPledges] = pledge
  log Create(
    self.numPledges,
    pledge.buyToken.address,
    pledge.sellToken.address,
    pledge.minBuy,
    pledge.maxSellForMin,
    pledge.deadline)
  self.numPledges += 1

@external
def pledge(id: uint256, amount: uint256):
  pledge: PledgeInfo = self.pledges[id]
  assert block.timestamp < pledge.deadline, "expired"
  assert self.totalBought[id] == 0, "executed"
  assert pledge.sellToken.transferFrom(msg.sender, self, amount), "transferFrom"
  assert pledge.sellToken.approve(vault.address, amount), "approve"
  vault.manageUserBalance([UserBalanceOp({
    kind: UserBalanceOpKind.DEPOSIT_INTERNAL,
    asset: pledge.sellToken.address,
    amount: amount,
    sender: self,
    recipient: self
  })])
  self.pledged[id][msg.sender] += amount
  self.totalPledged[id] += amount
  self.activePledgers[id] += 1
  log Pledge(id, msg.sender, amount)

@external
def execute(id: uint256):
  assert id < self.numPledges, "id"
  pledge: PledgeInfo = self.pledges[id]
  assert block.timestamp < pledge.deadline, "expired"
  assert self.totalBought[id] == 0, "executed"
  sellAmount: uint256 = self.totalPledged[id]
  swap: SingleSwap = SingleSwap({
    poolId: pledge.poolId,
    kind: SwapKind.GIVEN_IN,
    assetIn: pledge.sellToken.address,
    assetOut: pledge.buyToken.address,
    amount: sellAmount,
    userData: b''})
  limit: uint256 = sellAmount / pledge.maxSellForMin * pledge.minBuy
  buyAmount: uint256 = vault.swap(swap, selfFunds, limit, block.timestamp)
  assert buyAmount >= pledge.minBuy, "minBuy"
  assert buyAmount / pledge.minBuy * pledge.maxSellForMin <= sellAmount, "price"
  self.totalBought[id] = buyAmount
  log Execute(id, sellAmount, buyAmount)

@external
def claim(id: uint256):
  assert id < self.numPledges, "id"
  pledge: PledgeInfo = self.pledges[id]
  assert 0 < self.totalBought[id], "pending"
  sellAmount: uint256 = self.pledged[id][msg.sender]
  assert 0 < sellAmount, "empty"
  buyAmount: uint256 = sellAmount * self.totalBought[id] / self.totalPledged[id]
  vault.manageUserBalance([UserBalanceOp({
    kind: UserBalanceOpKind.WITHDRAW_INTERNAL,
    asset: pledge.buyToken.address,
    amount: buyAmount,
    sender: self,
    recipient: self
  })])
  assert pledge.buyToken.transfer(msg.sender, buyAmount), "transfer"
  self.pledged[id][msg.sender] = 0
  self.totalClaimed[id] += buyAmount
  self.activePledgers[id] -= 1
  log Claim(id, msg.sender, buyAmount, sellAmount)

@external
def dust(id: uint256):
  assert id < self.numPledges, "id"
  pledge: PledgeInfo = self.pledges[id]
  assert pledge.deadline < block.timestamp, "active"
  assert 0 < self.totalBought[id], "pending"
  assert self.activePledgers[id] == 0, "claimants"
  buyAmount: uint256 = self.totalBought[id] - self.totalClaimed[id]
  assert 0 < buyAmount, "empty"
  vault.manageUserBalance([UserBalanceOp({
    kind: UserBalanceOpKind.WITHDRAW_INTERNAL,
    asset: pledge.buyToken.address,
    amount: buyAmount,
    sender: self,
    recipient: self
  })])
  assert pledge.buyToken.transfer(msg.sender, buyAmount), "transfer"
  self.totalClaimed[id] += buyAmount
  log Dust(id, msg.sender, buyAmount)

@external
def refund(id: uint256):
  assert id < self.numPledges, "id"
  pledge: PledgeInfo = self.pledges[id]
  assert pledge.deadline < block.timestamp, "active"
  assert self.totalBought[id] == 0, "executed"
  amount: uint256 = self.pledged[id][msg.sender]
  assert 0 < amount, "empty"
  vault.manageUserBalance([UserBalanceOp({
    kind: UserBalanceOpKind.WITHDRAW_INTERNAL,
    asset: pledge.sellToken.address,
    amount: amount,
    sender: self,
    recipient: self
  })])
  assert pledge.sellToken.transfer(msg.sender, amount), "transfer"
  self.pledged[id][msg.sender] = 0
  self.activePledgers[id] -= 1
  log Refund(id, msg.sender, amount)
