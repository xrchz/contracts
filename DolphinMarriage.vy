# @version ^0.3.7

interface RplInterface:
  def balanceOf(_who: address) -> uint256: view
  def transfer(_to: address, _wad: uint256) -> bool: nonpayable

interface RocketStorageInterface:
  def confirmWithdrawalAddress(_nodeAddress: address): nonpayable

rocketStorageAddress: constant(address) = 0x1d8f8f00cfa6758d7bE78336684788Fb0ee0Fa46
rplTokenAddress: constant(address) = 0xD33526068D116cE69F19A9ee46F0bd304F21A51f
rocketStorage: immutable(RocketStorageInterface)
rplToken: immutable(RplInterface)

ownerEth: public(address)
ownerRpl: public(address)

rplPrincipal: public(uint256)
pendingAddRplPrincipal: public(uint256)

rplFeeNumerator: public(uint256)
rplFeeDenominator: public(uint256)
pendingRplFeeNumerator: public(uint256)
pendingRplFeeDenominator: public(uint256)

@external
def __init__(ownerRplAddress: address):
  rocketStorage = RocketStorageInterface(rocketStorageAddress)
  rplToken = RplInterface(rplTokenAddress)
  self.ownerEth = msg.sender
  self.ownerRpl = ownerRplAddress

@external
@payable
def __default__():
  pass

@external
def setOwnerEth(newOwnerEth: address):
  assert msg.sender == self.ownerEth, "only ownerEth can set ownerEth"
  self.ownerEth = newOwnerEth

@external
def setOwnerRpl(newOwnerRpl: address):
  assert msg.sender == self.ownerRpl, "owner ownerRpl can set ownerRpl"
  self.ownerRpl = newOwnerRpl

@external
def addRplPrincipal(amount: uint256):
  assert msg.sender == self.ownerRpl, "only ownerRpl can initiate add principal"
  self.pendingAddRplPrincipal = amount

@external
def confirmAddRplPrincipal(amount: uint256):
  assert msg.sender == self.ownerEth, "only ownerEth can confirm add principal"
  assert amount == self.pendingAddRplPrincipal, "incorrect amount"
  self.rplPrincipal += amount

@external
def setRplFee(numerator: uint256, denominator: uint256):
  assert msg.sender == self.ownerEth, "only ownerEth can initiate fee change"
  self.pendingRplFeeNumerator = numerator
  self.pendingRplFeeDenominator = denominator

@external
def confirmRplFee(numerator: uint256, denominator: uint256):
  assert msg.sender == self.ownerRpl, "only ownerRpl can confirm fee change"
  assert numerator == self.pendingRplFeeNumerator, "incorrect numerator"
  assert denominator == self.pendingRplFeeDenominator, "incorrect denominator"
  self.rplFeeNumerator = numerator
  self.rplFeeDenominator = denominator

@external
def withdrawEth():
  assert msg.sender == self.ownerEth, "only ownerEth can withdrawEth"
  send(self.ownerEth, self.balance)

@external
def withdrawRplRewards():
  assert msg.sender == self.ownerRpl, "only ownerRpl can withdrawRplRewards"
  fee: uint256 = rplToken.balanceOf(self) * self.rplFeeNumerator / self.rplFeeDenominator
  assert rplToken.transfer(self.ownerEth, fee), "fee transfer failed"
  assert rplToken.transfer(self.ownerRpl, rplToken.balanceOf(self)), "rpl rewards transfer failed"

@external
def withdrawRplPrincipal(amount: uint256):
  assert msg.sender == self.ownerRpl, "only ownerRpl can withdrawRplPrincipal"
  assert amount <= self.rplPrincipal, "amount exceeds principal"
  assert amount <= rplToken.balanceOf(self), "amount exceeds balance"
  assert rplToken.transfer(self.ownerRpl, amount), "rpl principal transfer failed"
  self.rplPrincipal -= amount

@external
def rpConfirmWithdrawalAddress(nodeAddress: address):
  rocketStorage.confirmWithdrawalAddress(nodeAddress)
