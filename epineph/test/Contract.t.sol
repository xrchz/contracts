// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.15;

import "foundry-huff/HuffDeployer.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";

contract ContractTest is Test {
    Contract public c;
    event Deposit(address indexed, uint256, uint256, uint256);

    function setUp() public {
        c = Contract(HuffDeployer.deploy("Contract"));
    }

    function testUnauthorizedDeposit() public {
        vm.expectRevert();
        c.deposit(1);
    }

    function testEmptyDeposit() public {
        vm.expectEmit(true, true, true, true, address(c));
        emit Deposit(address(this), 0, 0, 0);
        c.deposit(0);
    }
}

interface Contract {
    function deposit(uint256) payable external;
    function drain() external;
    event Deposit(address indexed, uint256, uint256, uint256);
    event Drain(address indexed, uint256, uint256);
}
