#pragma version ^0.3.0

# ERC20 Pledging System
#
# Create a matching pledge to buy (on Balancer) a token at a particular price
# (or better) by a deadline, using a particular sell token, as long as a target
# buy amount is reached. Either everyone buys the token together, or everyone
# is refunded their sell token.

interface ERC20:
  def balanceOf(_who: address) -> uint256: view
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

interface BalancerVault:
  def swap(singleSwap: SingleSwap, funds: FundManagement, limit: uint256, deadline: uint256) -> uint256: payable

struct Pledge:
  owner: address      # owner (initially creator) of the pledge
  deadline: uint256   # timestamp by which the pledge must be executed, else it will be refunded
  buyToken: ERC20     # pledging to buy this token
  minPledges: uint256 # pledge succeeds only if at least this number of pledges are made
  minBuy: uint256     # pledge succeeds only if at least this amount will be bought in total
  maxSellForMin: uint256 # pledge succeeds only if the price for buying minBuy
  sellToken: ERC20       # of buyToken is no more than maxSellForMin of sellToken

# Pledges with a numeric ID (ever-increasing nonce)
pledges: HashMap[uint256, Pledge]
numPledges: uint256

pledged: HashMap[address, HashMap[uint256, uint256]]

owner: address

@external
def __init__():
  self.owner = msg.sender

@external
def setOwner(newOwner: address):
  assert msg.sender == self.owner, "auth"
  self.owner = newOwner

@external
def createPledge(pledge: Pledge):
  assert pledge.owner == msg.sender, "auth"
  assert block.timestamp < pledge.deadline, "deadline must be in future"
  # TODO: assert Balancer pool exists for this pair?
  self.pledges[self.numPledges] = pledge
  self.numPledges += 1
  # TODO: emit log

@external
def pledge(id: uint256, amount: uint256):
  pledge: Pledge = self.pledges[id]
  assert block.timestamp < pledge.deadline, "expired"
  assert pledge.sellToken.transferFrom(msg.sender, self, amount), "transferFrom"
  self.pledged[msg.sender][id] += amount
  # TODO: emit log
