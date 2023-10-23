import pytest
from ape import reverts, Contract
from eth_utils import to_wei

RETH_RPL_POOL_ID = '0x9f9d900462492d4c21e9523ca95a7cd86142f298000200000000000000000462'
RETH_ADDRESS = '0xae78736Cd615f374D3085123A210448E74Fc6393'
RPL_ADDRESS = '0xD33526068D116cE69F19A9ee46F0bd304F21A51f'
ONE_HOUR_SECONDS = 60 * 60
ONE_DAY_SECONDS = 24 * ONE_HOUR_SECONDS

@pytest.fixture(scope='session')
def pledgeContract(project, networks, accounts):
  return project.pledge.deploy(sender=accounts[0])

def test_deploy(pledgeContract):
    assert pledgeContract.numPledges() == 0

def test_create_bad_deadline(pledgeContract, accounts, chain):
    with reverts('deadline'):
        pledgeContract.create((
            RETH_RPL_POOL_ID,
            chain.blocks.head.timestamp,
            RPL_ADDRESS,
            '4.2 ether',
            RETH_ADDRESS,
            '0.05 ether'), 1, 0, sender=accounts[1])

def test_create_bad_indices(pledgeContract, accounts, chain):
    with reverts('buyToken'):
        pledgeContract.create((
            RETH_RPL_POOL_ID,
            chain.blocks.head.timestamp + ONE_HOUR_SECONDS,
            RPL_ADDRESS,
            '4.2 ether',
            RETH_ADDRESS,
            '0.05 ether'), 0, 1, sender=accounts[1])

@pytest.fixture
def createdPledge(pledgeContract, accounts, chain):
    receipt = pledgeContract.create((
        RETH_RPL_POOL_ID,
        chain.blocks.head.timestamp + ONE_DAY_SECONDS,
        RPL_ADDRESS,
        '4.2 ether',
        RETH_ADDRESS,
        '0.069 ether'), 1, 0, sender=accounts[1])
    return receipt.return_value

def test_create(pledgeContract, createdPledge):
    assert pledgeContract.numPledges() == 1
    assert pledgeContract.pledges(createdPledge)['minBuy'] == to_wei('4.2', 'ether')

@pytest.fixture
def rETHWhale(accounts):
    return accounts['0x742b8ea0754e4ac12b3f72e92d686c0b0664eee4'] # rethwhale.eth

@pytest.fixture
def rETHFish(accounts):
    return accounts['0x849b5E5116F1C3E8AdeB8Ef85562233ccE4C696B'] # immortall69.eth

def test_add_pledge_unapproved(pledgeContract, createdPledge, rETHWhale):
    with reverts('ERC20: transfer amount exceeds allowance'):
        pledgeContract.pledge(createdPledge, '42 gwei', sender=rETHWhale)

@pytest.fixture
def addPledge(pledgeContract, createdPledge, rETHWhale):
    rETH = Contract(RETH_ADDRESS)
    amount = to_wei(42, 'gwei')
    prevBalance = rETH.balanceOf(rETHWhale)
    rETH.approve(pledgeContract.address, amount, sender=rETHWhale)
    pledgeContract.pledge(createdPledge, amount, sender=rETHWhale)
    return {'amount': amount, 'rETH': rETH, 'prevBalance': prevBalance, 'sender': rETHWhale}

@pytest.fixture
def addPledge2(pledgeContract, createdPledge, addPledge, rETHFish):
    rETH = addPledge['rETH']
    amount = to_wei('0.04', 'ether')
    prevBalance = rETH.balanceOf(rETHFish)
    rETH.approve(pledgeContract.address, amount, sender=rETHFish)
    pledgeContract.pledge(createdPledge, amount, sender=rETHFish)
    return {'amount': amount, 'prevBalance': prevBalance, 'sender': rETHFish}

@pytest.fixture
def addPledge3(pledgeContract, createdPledge, addPledge, addPledge2, rETHWhale):
    rETH = addPledge['rETH']
    amount = to_wei('0.1', 'ether')
    prevBalance = rETH.balanceOf(rETHWhale)
    rETH.approve(pledgeContract.address, amount, sender=rETHWhale)
    pledgeContract.pledge(createdPledge, amount, sender=rETHWhale)
    return {'amount': amount, 'prevBalance': prevBalance, 'sender': rETHWhale}

def test_add_pledge(pledgeContract, createdPledge, addPledge, rETHWhale):
    rETH = addPledge['rETH']
    amount = addPledge['amount']
    assert pledgeContract.totalPledged(createdPledge) == amount
    assert pledgeContract.activePledgers(createdPledge) == 1
    assert pledgeContract.pledged(createdPledge, rETHWhale) == amount
    assert rETH.balanceOf(pledgeContract) == 0
    assert rETH.balanceOf(rETHWhale) == addPledge['prevBalance'] - amount

def test_refund_before_deadline(pledgeContract, createdPledge, addPledge, rETHWhale):
    with reverts('active'):
        pledgeContract.refund(createdPledge, sender=rETHWhale)

def test_claim_before_bought(pledgeContract, createdPledge, addPledge, rETHWhale):
    with reverts('pending'):
        pledgeContract.claim(createdPledge, sender=rETHWhale)

def test_dust_before_deadline(pledgeContract, createdPledge, addPledge, rETHWhale, chain):
    assert chain.blocks.head.timestamp < pledgeContract.pledges(createdPledge)['deadline']
    with reverts('active'):
        pledgeContract.dust(createdPledge, sender=rETHWhale)

def test_execute_before_min(pledgeContract, createdPledge, addPledge, accounts):
    with reverts('minBuy'):
        receipt = pledgeContract.execute(createdPledge, sender=accounts[2])

def test_refund_after_deadline(pledgeContract, createdPledge, addPledge, rETHWhale, chain):
    chain.mine(1, None, ONE_DAY_SECONDS)
    assert chain.blocks.head.timestamp > pledgeContract.pledges(createdPledge)['deadline']
    rETH = addPledge['rETH']
    prevBalance = rETH.balanceOf(rETHWhale)
    receipt = pledgeContract.refund(createdPledge, sender=rETHWhale)
    assert rETH.balanceOf(rETHWhale) == addPledge['prevBalance']
    assert receipt.return_value + prevBalance == addPledge['prevBalance']
    assert pledgeContract.pledged(createdPledge, rETHWhale) == 0
    assert pledgeContract.activePledgers(createdPledge) == 0

def test_refund_not_pledger(pledgeContract, createdPledge, addPledge, accounts, chain):
    chain.mine(1, None, ONE_DAY_SECONDS)
    assert chain.blocks.head.timestamp > pledgeContract.pledges(createdPledge)['deadline']
    with reverts('empty'):
        pledgeContract.refund(createdPledge, sender=accounts[2])

def test_pledge2(pledgeContract, createdPledge, addPledge, addPledge2):
    assert pledgeContract.numPledges() == 1
    assert pledgeContract.activePledgers(createdPledge) == 2
    assert pledgeContract.totalPledged(createdPledge) == addPledge2['amount'] + addPledge['amount']
    assert pledgeContract.totalBought(createdPledge) == 0
    assert pledgeContract.totalClaimed(createdPledge) == 0
    assert pledgeContract.pledged(createdPledge, addPledge2['sender']) == addPledge2['amount']

def test_execute_before_min2(pledgeContract, createdPledge, addPledge2, accounts):
    with reverts('minBuy'):
        pledgeContract.execute(createdPledge, sender=accounts[2])

def test_pledge3(pledgeContract, createdPledge, addPledge, addPledge2, addPledge3):
    assert pledgeContract.numPledges() == 1
    assert pledgeContract.activePledgers(createdPledge) == 2 # one pledger went twice
    assert (pledgeContract.totalPledged(createdPledge) ==
            addPledge3['amount'] + addPledge2['amount'] + addPledge['amount'])
    assert pledgeContract.totalBought(createdPledge) == 0
    assert pledgeContract.totalClaimed(createdPledge) == 0
    assert (pledgeContract.pledged(createdPledge, addPledge3['sender']) ==
            addPledge['amount'] + addPledge3['amount'])

def test_execute_after_deadline(pledgeContract, createdPledge, addPledge3, accounts, chain):
    chain.mine(1, None, ONE_DAY_SECONDS)
    with reverts('expired'):
        pledgeContract.execute(createdPledge, sender=accounts[1])

@pytest.fixture
def executed(pledgeContract, createdPledge, addPledge3, accounts):
    return pledgeContract.execute(createdPledge, sender=accounts[2])

def test_executed(pledgeContract, createdPledge, executed):
    assert executed.return_value >= pledgeContract.pledges(createdPledge).minBuy

def test_claim(pledgeContract, createdPledge, addPledge, addPledge2, addPledge3, executed, rETHWhale):
    RPL = Contract(RPL_ADDRESS)
    prevBalance = RPL.balanceOf(rETHWhale)
    receipt = pledgeContract.claim(createdPledge, sender=rETHWhale)
    assert RPL.balanceOf(rETHWhale) == prevBalance + receipt.return_value
    assert pledgeContract.activePledgers(createdPledge) == 1
    assert receipt.return_value
    amountSold = addPledge['amount'] + addPledge3['amount']
    totalSold = amountSold + addPledge2['amount']
    totalBought = executed.return_value
    amountBought = receipt.return_value
    assert amountBought / totalBought == amountSold / totalSold
