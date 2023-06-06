// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.15;

import "foundry-huff/HuffDeployer.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";

contract ContractTest is Test {
    Contract public c;
    event Deposit(address indexed, uint256, uint256, uint256);
    event Transfer(address indexed, address indexed, uint256);
    address rETHAddress = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address stETHAddress = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;

    function setUp() public {
        c = Contract(HuffDeployer.deploy("Contract"));
    }

    function testUnauthorizedDeposit() public {
        vm.expectRevert();
        c.deposit(1);
    }

    function testDeposit() public {
        // pretend to be wstETH (which has a lot of stETH) since deal seems to break on lido
        address wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
        vm.startPrank(wstETH);
        // deal(stETHAddress, address(this), 42); // give ourselves some stETH
        deal(rETHAddress, address(c), 42); // give contract some rETH
        ERC20(stETHAddress).approve(address(c), 24);
        uint256 expected = rETH(rETHAddress).getRethValue(24);
        vm.expectEmit(true, true, true, true, stETHAddress);
        emit Transfer(wstETH, address(c), 24);
        vm.expectEmit(true, true, true, true, rETHAddress);
        emit Transfer(address(c), wstETH, expected);
        vm.expectEmit(true, true, true, true, address(c));
        emit Deposit(wstETH, 0, expected, 24);
        c.deposit(24);
        vm.stopPrank();
    }

    function testEmptyDeposit() public {
        vm.expectEmit(true, true, true, true, rETHAddress);
        emit Transfer(address(c), address(this), 0);
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

interface rETH {
  function getRethValue(uint256) view external returns (uint256);
}

interface ERC20 {
  function approve(address, uint256) external returns (bool);
}
