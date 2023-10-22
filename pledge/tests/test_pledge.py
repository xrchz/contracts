import pytest
from ape import reverts

@pytest.fixture(scope='session')
def pledge(project, networks, accounts):
  return project.pledge.deploy(sender=accounts[0])

def test_deploy(pledge):
    assert pledge.numPledges() == 0
