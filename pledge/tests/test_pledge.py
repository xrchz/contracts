import pytest
from ape import reverts

RETH_RPL_POOL_ID = '0x9f9d900462492d4c21e9523ca95a7cd86142f298000200000000000000000462'
RETH_ADDRESS = '0xae78736Cd615f374D3085123A210448E74Fc6393'
RPL_ADDRESS = '0xD33526068D116cE69F19A9ee46F0bd304F21A51f'
ONE_HOUR_SECONDS = 60 * 60
ONE_DAY_SECONDS = 24 * ONE_HOUR_SECONDS

@pytest.fixture(scope='session')
def pledge(project, networks, accounts):
  return project.pledge.deploy(sender=accounts[0])

def test_deploy(pledge):
    assert pledge.numPledges() == 0

def test_create_bad_deadline(pledge, accounts, chain):
    with reverts('deadline'):
        pledge.create((
            RETH_RPL_POOL_ID,
            chain.blocks.head.timestamp,
            RPL_ADDRESS,
            '4.2 ETH',
            RETH_ADDRESS,
            '0.05 ETH'), 1, 0, sender=accounts[1])

def test_create_bad_indices(pledge, accounts, chain):
    with reverts('buyToken'):
        pledge.create((
            RETH_RPL_POOL_ID,
            chain.blocks.head.timestamp + ONE_HOUR_SECONDS,
            RPL_ADDRESS,
            '4.2 ETH',
            RETH_ADDRESS,
            '0.05 ETH'), 0, 1, sender=accounts[1])

def test_create(pledge, accounts, chain):
    pledge.create((
        RETH_RPL_POOL_ID,
        chain.blocks.head.timestamp + ONE_DAY_SECONDS,
        RPL_ADDRESS,
        '4.2 ETH',
        RETH_ADDRESS,
        '0.05 ETH'), 1, 0, sender=accounts[1])
    assert pledge.numPledges() == 1
