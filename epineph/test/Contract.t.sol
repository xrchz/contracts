// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.15;

import "foundry-huff/HuffDeployer.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";

contract ContractTest is Test {
    Contract public c;

    function setUp() public {
        c = Contract(HuffDeployer.deploy("Contract"));
    }

    function testEmptyDeposit() public {
        c.deposit(0);
    }
}

interface Contract {
    function deposit(uint256) payable external;
    function drain() external;
    event Deposit(address indexed, uint256, uint256, uint256);
    event Drain(address indexed, uint256, uint256);
}
