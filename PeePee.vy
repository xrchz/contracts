# @version 0.3.7

interface ERC20:
  def name() -> String[64]: view
  def symbol() -> String[8]: view
  def decimals() -> uint8: view
  def totalSupply() -> uint256: view
  def balanceOf(_owner: address) -> uint256: view
  def transfer(_to: address, _value: uint256) -> bool: nonpayable
  def transferFrom(_from: address, _to: address, _value: uint256) -> bool: nonpayable
  def approve(_spender: address, _value: uint256) -> bool: nonpayable
  def allowance(_owner: address, _spender: address) -> uint256: view

event Transfer:
  _from: indexed(address)
  _to: indexed(address)
  _value: uint256

event Approval:
  _owner: indexed(address)
  _spender: indexed(address)
  _value: uint256

@external
@view
def name() -> String[64]:
  return "PeePee Token"

@external
@view
def symbol() -> String[8]:
  return "PEEPEE"

@external
@view
def decimals() -> uint8:
  return 2

totalSupply: public(uint256)

balanceOf: public(HashMap[address, uint256])

allowance: public(HashMap[address, HashMap[address, uint256]])

@internal
def _transfer(_from: address, _to: address, _value: uint256):
  assert _value <= self.balanceOf[_from], "insufficient balance"
  self.balanceOf[_from] = unsafe_sub(self.balanceOf[_from], _value)
  self.balanceOf[_to] = self.balanceOf[_to] + _value
  log Transfer(_from, _to, _value)

@external
def transfer(_to: address, _value: uint256) -> bool:
  self._transfer(msg.sender, _to, _value)
  return True

@external
def transferFrom(_from: address, _to: address, _value: uint256) -> bool:
  assert _value <= self.allowance[msg.sender][_from], "insufficient allowance"
  self.allowance[msg.sender][_from] = unsafe_sub(self.allowance[msg.sender][_from], _value)
  self._transfer(_from, _to, _value)
  return True

@external
def approve(_spender: address, _value: uint256) -> bool:
  self.allowance[msg.sender][_spender] = _value
  log Approval(msg.sender, _spender, _value)
  return True

burnable: public(HashMap[ERC20, bool])

priceN: public(HashMap[ERC20, uint256])
priceD: public(HashMap[ERC20, uint256])

@external
def mint(_burnToken: ERC20, _value: uint256):
  assert self.burnable[_burnToken], "invalid token"
  assert _burnToken.transferFrom(msg.sender, self, _value)
  amount: uint256 = (_value * self.priceN[_burnToken]) / self.priceD[_burnToken]
  self.totalSupply += amount
  self.balanceOf[empty(address)] = amount
  self._transfer(empty(address), msg.sender, amount)

score: public(HashMap[address, uint256])
totalScore: public(uint256)

SubmitToken: constant(uint256) = 0
DeleteToken: constant(uint256) = 1
ChangePrice: constant(uint256) = 2
ChangeSpend: constant(uint256) = 3
ChangeScore: constant(uint256) = 4
numActions: constant(uint256) = 5

event Act:
  action: indexed(uint256)
  actor: indexed(address)

spends: public(uint256[numActions])
scores: public(uint256[numActions])

@internal
def _act(action: uint256, actor: address):
  assert action < numActions
  assert ERC20(self).transferFrom(actor, empty(address), self.spends[action])
  self.totalSupply -= self.spends[action]
  self.score[actor] += self.scores[action]
  self.totalScore += self.scores[action]
  log Act(action, actor)

@internal
def _changePrice(_burnToken: ERC20, _priceN: uint256, _priceD: uint256):
  assert 0 < _priceD, "invalid denominator"
  self.priceN[_burnToken] = _priceN
  self.priceD[_burnToken] = _priceD

@external
def addToken(_burnToken: ERC20, _priceN: uint256, _priceD: uint256):
  assert not self.burnable[_burnToken], "already added"
  self._act(SubmitToken, msg.sender)
  self.burnable[_burnToken] = True
  self._changePrice(_burnToken, _priceN, _priceD)

@external
def deleteToken(_burnToken: ERC20):
  assert self.burnable[_burnToken], "not added"
  self._act(DeleteToken, msg.sender)
  self.burnable[_burnToken] = False

@external
def changePrice(_burnToken: ERC20, _priceN: uint256, _priceD: uint256):
  assert self.burnable[_burnToken], "not added"
  self._act(ChangePrice, msg.sender)
  self._changePrice(_burnToken, _priceN, _priceD)

@external
def changeSpend(_action: uint256, _spend: uint256):
  assert _action < numActions
  self._act(ChangeSpend, msg.sender)
  assert 0 < _spend, "invalid spend"
  self.spends[_action] = _spend

@external
def changeScore(_action: uint256, _score: uint256):
  assert _action < numActions
  self._act(ChangeScore, msg.sender)
  self.scores[_action] = _score

@external
def __init__():
  WETH: ERC20 = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)
  self.burnable[WETH] = True
  self.priceN[WETH] = 1000000000
  self.priceD[WETH] = 1
  self.spends[SubmitToken] = 100
  self.spends[DeleteToken] = 200
  self.spends[ChangeSpend] = 144
  self.spends[ChangePrice] = 189
  self.spends[ChangeScore] = 243
  self.scores[SubmitToken] = 4
  self.scores[DeleteToken] = 7
  self.scores[ChangeSpend] = 3
  self.scores[ChangePrice] = 6
  self.scores[ChangeScore] = 2
