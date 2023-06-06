# @version 0.3.8

MAX_DEPOSIT: constant(uint256) = 10 ** 18 # 1 ETH

interface ERC20:
  def balanceOf(_owner: address) -> uint256: view
  def transfer(_to: address, _value: uint256) -> bool: nonpayable
  def transferFrom(_from: address, _to: address, _value: uint256) -> bool: nonpayable

interface RocketEther:
  def getRethValue(_ethAmount: uint256) -> uint256: view

interface RocketStorage:
  def getAddress(_key: bytes32) -> address: view

rocketStorage: immutable(RocketStorage)

rocketEther: immutable(ERC20)
stakedEther: immutable(ERC20)
owner: immutable(address)

@external
def __init__(_rocketStorage: address, _stETH: address, _owner: address):
  rocketStorage = RocketStorage(_rocketStorage)
  rocketEther = ERC20(rocketStorage.getAddress(keccak256("contract.addressrocketTokenRETH")))
  stakedEther = ERC20(_stETH)
  owner = _owner

event Deposit:
  who: indexed(address)
  stETH: uint256
  ETH: uint256
  rETH: uint256

event Drain:
  who: indexed(address)
  to: indexed(address)
  stETH: uint256
  ETH: uint256

@internal
def _finishDeposit(stETH: uint256, ETH: uint256):
  total: uint256 = stETH + ETH
  assert total <= MAX_DEPOSIT, "max"
  rETH: uint256 = RocketEther(rocketEther.address).getRethValue(total)
  assert rocketEther.transfer(msg.sender, rETH), "rETH"
  log Deposit(msg.sender, stETH, ETH, rETH)

@external
@payable
def deposit(stETH: uint256):
  assert stakedEther.transferFrom(msg.sender, self, stETH), "stETH"
  self._finishDeposit(stETH, msg.value)

@external
@payable
def depositETH():
  self._finishDeposit(0, msg.value)

@external
def depositStETH(stETH: uint256):
  assert stakedEther.transferFrom(msg.sender, self, stETH), "stETH"
  self._finishDeposit(stETH, 0)

@external
def drain():
  stETH: uint256 = stakedEther.balanceOf(self)
  assert stakedEther.transfer(owner, stETH)
  ETH: uint256 = self.balance
  send(owner, ETH)
  log Drain(msg.sender, owner, stETH, ETH)
