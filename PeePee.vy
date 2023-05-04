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
  return 18

totalSupply: public(uint256)

balanceOf: public(HashMap[address, uint256])

allowance: public(HashMap[address, HashMap[address, uint256]])

@external
def transfer(_to: address, _value: uint256) -> bool:
  assert _value <= self.balanceOf[msg.sender], "insufficient balance"
  assert _value <= unsafe_sub(max_value(uint256), self.balanceOf[_to]), "overflow"
  self.balanceOf[msg.sender] = unsafe_sub(self.balanceOf[msg.sender], _value)
  self.balanceOf[_to] = unsafe_add(self.balanceOf[_to], _value)
  log Transfer(msg.sender, _to, _value)
  return True

@external
def transferFrom(_from: address, _to: address, _value: uint256) -> bool:
  assert _value <= self.balanceOf[_from], "insufficient balance"
  assert _value <= self.allowance[msg.sender][_from], "insufficient allowance"
  assert _value <= unsafe_sub(max_value(uint256), self.balanceOf[_to]), "overflow"
  self.balanceOf[_from] = unsafe_sub(self.balanceOf[_from], _value)
  self.allowance[msg.sender][_from] = unsafe_sub(self.allowance[msg.sender][_from], _value)
  self.balanceOf[_to] = unsafe_add(self.balanceOf[_to], _value)
  log Transfer(_from, _to, _value)
  return True

@external
def approve(_spender: address, _value: uint256) -> bool:
  self.allowance[msg.sender][_spender] = _value
  log Approval(msg.sender, _spender, _value)
  return True
