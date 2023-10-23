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
            '4.2 ETH',
            RETH_ADDRESS,
            '0.05 ETH'), 1, 0, sender=accounts[1])

def test_create_bad_indices(pledgeContract, accounts, chain):
    with reverts('buyToken'):
        pledgeContract.create((
            RETH_RPL_POOL_ID,
            chain.blocks.head.timestamp + ONE_HOUR_SECONDS,
            RPL_ADDRESS,
            '4.2 ETH',
            RETH_ADDRESS,
            '0.05 ETH'), 0, 1, sender=accounts[1])

@pytest.fixture
def createdPledge(pledgeContract, accounts, chain):
    receipt = pledgeContract.create((
        RETH_RPL_POOL_ID,
        chain.blocks.head.timestamp + ONE_DAY_SECONDS,
        RPL_ADDRESS,
        '4.2 ETH',
        RETH_ADDRESS,
        '0.05 ETH'), 1, 0, sender=accounts[1])
    return receipt.return_value

def test_create(pledgeContract, createdPledge):
    assert pledgeContract.numPledges() == 1

@pytest.fixture
def rETHHolder(accounts):
    return accounts['0x742b8ea0754e4ac12b3f72e92d686c0b0664eee4'] # rethwhale.eth

def test_add_pledge_unapproved(pledgeContract, createdPledge, rETHHolder):
    with reverts('ERC20: transfer amount exceeds allowance'):
        pledgeContract.pledge(createdPledge, '42 gwei', sender=rETHHolder)

@pytest.fixture
def addPledge(pledgeContract, createdPledge, rETHHolder):
    rETH = Contract(RETH_ADDRESS)
    amount = to_wei(42, 'gwei')
    prevBalance = rETH.balanceOf(rETHHolder)
    rETH.approve(pledgeContract.address, amount, sender=rETHHolder)
    pledgeContract.pledge(createdPledge, amount, sender=rETHHolder)
    return {'amount': amount, 'rETH': rETH, 'prevBalance': prevBalance}

def test_add_pledge(pledgeContract, createdPledge, addPledge, rETHHolder):
    rETH = addPledge['rETH']
    amount = addPledge['amount']
    assert pledgeContract.totalPledged(createdPledge) == amount
    assert pledgeContract.activePledgers(createdPledge) == 1
    assert pledgeContract.pledged(createdPledge, rETHHolder) == amount
    assert rETH.balanceOf(pledgeContract) == 0
    assert rETH.balanceOf(rETHHolder) == addPledge['prevBalance'] - amount

def test_refund_before_deadline(pledgeContract, createdPledge, addPledge, rETHHolder):
    with reverts('active'):
        pledgeContract.refund(createdPledge, sender=rETHHolder)

def test_claim_before_bought(pledgeContract, createdPledge, addPledge, rETHHolder):
    with reverts('pending'):
        pledgeContract.claim(createdPledge, sender=rETHHolder)

def test_dust_before_deadline(pledgeContract, createdPledge, addPledge, rETHHolder):
    with reverts('active'):
        pledgeContract.dust(createdPledge, sender=rETHHolder)
