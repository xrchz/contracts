# @version ^0.3.7

interface RplInterface:
  def balanceOf(_who: address) -> uint256: view
  def transfer(_to: address, _wad: uint256) -> bool: nonpayable

interface RocketStorageInterface:
  def getAddress(_key: bytes32) -> address: view
  def confirmWithdrawalAddress(_nodeAddress: address): nonpayable
  def setWithdrawalAddress(_nodeAddress: address, _newWithdrawalAddress: address, _confirm: bool): nonpayable

interface RocketNodeStakingInterface:
  def getNodeRPLStake(_nodeAddress: address) -> uint256: view

interface RocketMinipoolManagerInterface:
  def getNodeActiveMinipoolCount(_nodeAddress: address) -> uint256: view

ETH_PER_MINIPOOL: constant(uint256) = as_wei_value(16, "ether")

interface EnsRevRegInterface:
  def setName(_name: String[64]) -> bytes32: nonpayable

interface EnsRegInterface:
  def owner(_node: bytes32) -> address: view

addrReverseNode: constant(bytes32) = 0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2
ensRegAddress: constant(address) = 0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e
rocketNodeStakingKey: constant(bytes32) = keccak256("contract.addressrocketNodeStaking")
rocketMinipoolManagerKey: constant(bytes32) = keccak256("contract.addressrocketMinipoolManager")
rocketTokenRPLKey: constant(bytes32) = keccak256("contract.addressrocketTokenRPL")
rocketStorage: immutable(RocketStorageInterface)
rplToken: immutable(RplInterface)

owner: public(address)
pendingOwner: public(address)
feeRecipient: public(address)
pendingFeeRecipient: public(address)
nodeAddress: public(address)
pendingNodeAddress: public(address)
pendingWithdrawalAddress: public(address)

principal: public(uint256)
feeNumerator: public(uint256)
feeDenominator: public(uint256)
pendingFeeNumerator: public(uint256)
pendingFeeDenominator: public(uint256)

@external
def __init__(_rocketStorageAddress: address):
  rocketStorage = RocketStorageInterface(_rocketStorageAddress)
  rplToken = RplInterface(rocketStorage.getAddress(rocketTokenRPLKey))
  self.owner = msg.sender
  self.feeRecipient = msg.sender

@external
@payable
def __default__():
  pass

@external
def setOwner(_newOwner: address):
  assert msg.sender == self.owner, "only owner can set owner"
  self.pendingOwner = _newOwner

@external
def confirmOwner():
  assert msg.sender == self.pendingOwner, "wrong address"
  self.owner = msg.sender

@external
def setFeeRecipient(_newFeeRecipient: address):
  assert msg.sender == self.feeRecipient, "only fee recipient can set fee recipient"
  self.pendingFeeRecipient = _newFeeRecipient

@external
def confirmFeeRecipient():
  assert msg.sender == self.pendingFeeRecipient, "wrong address"
  self.feeRecipient = msg.sender

@external
def setFee(_numerator: uint256, _denominator: uint256):
  assert msg.sender == self.feeRecipient, "only fee recipient can initiate fee change"
  self.pendingFeeNumerator = _numerator
  self.pendingFeeDenominator = _denominator

@external
def confirmFee(_numerator: uint256, _denominator: uint256):
  assert msg.sender == self.owner, "only owner can confirm fee change"
  assert _numerator == self.pendingFeeNumerator, "incorrect numerator"
  assert _denominator == self.pendingFeeDenominator, "incorrect denominator"
  self.feeNumerator = _numerator
  self.feeDenominator = _denominator

@internal
def _getNodeMinipools() -> uint256:
  rocketMinipoolManagerAddress: address = rocketStorage.getAddress(rocketMinipoolManagerKey)
  rocketMinipoolManager: RocketMinipoolManagerInterface = RocketMinipoolManagerInterface(rocketMinipoolManagerAddress)
  return rocketMinipoolManager.getNodeActiveMinipoolCount(self.nodeAddress)

@external
def updatePrincipal(_expectedMinipools: uint256):
  assert msg.sender == self.owner, "only owner can set principal"
  assert _expectedMinipools == self._getNodeMinipools(), "incorrect active minipool count"
  self.principal = _expectedMinipools * ETH_PER_MINIPOOL

@external
def withdrawRpl() -> bool:
  assert msg.sender == self.owner, "only owner can withdraw RPL"
  return rplToken.transfer(self.owner, rplToken.balanceOf(self))

@external
def withdrawEthRewards(_amount: uint256):
  assert msg.sender == self.owner, "only owner can withdraw ETH rewards"
  assert _amount <= self.balance, "amount exceeds balance"
  fee: uint256 = _amount * self.feeNumerator / self.feeDenominator
  send(self.feeRecipient, fee)
  send(self.owner, _amount - fee)

@external
def withdrawEthPrincipal(_amount: uint256):
  assert msg.sender == self.owner, "only owner can withdraw ETH principal"
  assert _amount <= self.principal, "amount exceeds principal"
  assert _amount <= self.balance, "amount exceeds balance"
  self.principal -= _amount
  send(self.owner, _amount)

@external
def rpConfirmWithdrawalAddress():
  rocketStorage.confirmWithdrawalAddress(self.nodeAddress)

@external
def ensSetName(_name: String[64]):
  EnsRevRegInterface(
    EnsRegInterface(ensRegAddress).owner(addrReverseNode)).setName(_name)

@external
def changeNodeAddress(_newNodeAddress: address):
  assert msg.sender == self.owner, "only owner can changeNodeAddress"
  self.pendingNodeAddress = _newNodeAddress

@external
def confirmChangeNodeAddress(_newNodeAddress: address):
  assert msg.sender == self.feeRecipient, "only fee recipient can confirmChangeNodeAddress"
  assert _newNodeAddress == self.pendingNodeAddress, "incorrect address"
  self.nodeAddress = _newNodeAddress

@external
def changeWithdrawalAddress(_newWithdrawalAddress: address):
  assert msg.sender == self.owner, "only owner can changeWithdrawalAddress"
  self.pendingWithdrawalAddress = _newWithdrawalAddress

@external
def confirmChangeWithdrawalAddress(_newWithdrawalAddress: address):
  assert msg.sender == self.feeRecipient, "only feeRecipient can confirmChangeWithdrawalAddress"
  assert _newWithdrawalAddress == self.pendingWithdrawalAddress, "incorrect address"
  rocketStorage.setWithdrawalAddress(self.nodeAddress, _newWithdrawalAddress, False)
