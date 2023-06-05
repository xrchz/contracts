# @version 0.3.8

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
owner: public(address)

@external
def __init__(_rocketStorage: address, _stETH: address):
  rocketStorage = RocketStorage(_rocketStorage)
  rocketEther = ERC20(rocketStorage.getAddress(keccak256("contract.addressrocketTokenRETH")))
  stakedEther = ERC20(_stETH)
  self.owner = msg.sender

@external
def changeOwner(_newOwner: address):
  assert msg.sender == self.owner, "auth"
  self.owner = _newOwner

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

@external
@payable
def deposit(_stETH: uint256):
  amount: uint256 = _stETH + msg.value
  assert stakedEther.transferFrom(msg.sender, self, _stETH), "stETH"
  rETH: uint256 = RocketEther(rocketEther.address).getRethValue(amount)
  assert rocketEther.transfer(msg.sender, rETH), "rETH"
  log Deposit(msg.sender, _stETH, msg.value, rETH)

@external
def drain():
  stETH: uint256 = stakedEther.balanceOf(self)
  assert stakedEther.transfer(self.owner, stETH)
  ETH: uint256 = self.balance
  send(self.owner, ETH)
  log Drain(msg.sender, self.owner, stETH, ETH)
