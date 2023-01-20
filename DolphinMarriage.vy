# @version ^0.3.7

interface RplInterface:
  def balanceOf(_who: address) -> uint256: view
  def transfer(_to: address, _wad: uint256) -> bool: nonpayable

interface RocketStorageInterface:
  def getAddress(_key: bytes32) -> address: view
  def confirmWithdrawalAddress(_nodeAddress: address): nonpayable

interface RocketNodeStakingInterface:
  def getNodeRPLStake(_nodeAddress: address) -> uint256: view

rocketNodeStakingKey: constant(bytes32) = keccak256("contract.addressrocketNodeStaking")
rocketStorageAddress: constant(address) = 0x1d8f8f00cfa6758d7bE78336684788Fb0ee0Fa46
rplTokenAddress: constant(address) = 0xD33526068D116cE69F19A9ee46F0bd304F21A51f
rocketStorage: immutable(RocketStorageInterface)
rplToken: immutable(RplInterface)

nodeAddress: immutable(address)
ownerEth: public(address)
ownerRpl: public(address)

rplPrincipal: public(uint256)
rplFeeNumerator: public(uint256)
rplFeeDenominator: public(uint256)
pendingRplFeeNumerator: public(uint256)
pendingRplFeeDenominator: public(uint256)

@external
def __init__(_ownerRpl: address, _nodeAddress: address):
  rocketStorage = RocketStorageInterface(rocketStorageAddress)
  rplToken = RplInterface(rplTokenAddress)
  nodeAddress = _nodeAddress
  self.ownerEth = msg.sender
  self.ownerRpl = _ownerRpl

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
  assert msg.sender == self.ownerRpl, "only ownerRpl can set ownerRpl"
  self.ownerRpl = newOwnerRpl

@internal
def _getNodeRPLStake() -> uint256:
  rocketNodeStakingAddress: address = rocketStorage.getAddress(rocketNodeStakingKey)
  rocketNodeStaking: RocketNodeStakingInterface = RocketNodeStakingInterface(rocketNodeStakingAddress)
  return rocketNodeStaking.getNodeRPLStake(nodeAddress)

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
def updateRplPrincipal():
  assert msg.sender == self.ownerRpl, "only ownerRpl can set principal"
  self.rplPrincipal = self._getNodeRPLStake()

@external
def withdrawRplPrincipal(amount: uint256):
  assert msg.sender == self.ownerRpl, "only ownerRpl can withdrawRplPrincipal"
  assert amount <= self.rplPrincipal, "amount exceeds principal"
  assert amount <= rplToken.balanceOf(self), "amount exceeds balance"
  assert rplToken.transfer(self.ownerRpl, amount), "rpl principal transfer failed"
  self.rplPrincipal -= amount

@external
def withdrawRewards(amount: uint256):
  assert msg.sender == self.ownerRpl, "only ownerRpl can withdrawRewards"
  assert amount <= rplToken.balanceOf(self), "amount exceeds balance"
  fee: uint256 = amount * self.rplFeeNumerator / self.rplFeeDenominator
  assert fee <= amount, "fee exceeds amount"
  assert rplToken.transfer(self.ownerEth, fee), "fee transfer failed"
  assert rplToken.transfer(self.ownerRpl, amount - fee), "rpl rewards transfer failed"
  send(self.ownerEth, self.balance)

@external
def withdrawEth():
  assert msg.sender == self.ownerEth, "only ownerEth can withdrawEth"
  assert self._getNodeRPLStake() == 0, "unstake RPL before withdrawing ETH"
  send(self.ownerEth, self.balance)

@external
def rpConfirmWithdrawalAddress():
  rocketStorage.confirmWithdrawalAddress(nodeAddress)
