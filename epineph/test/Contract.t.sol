// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.15;

import "foundry-huff/HuffDeployer.sol";
import "forge-std/Test.sol";

contract ContractTest is Test {
    Contract public c;
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Deposit(address indexed sender, uint256 ETH, uint256 rETH, uint256 stETH);
    event Drain(address indexed sender, uint256 ETH, uint256 stETH);
    address rETHAddress = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address stETHAddress = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address ownerAddress = 0x1234567890000000000000000000000000000000;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
        c = Contract(HuffDeployer.deploy("Contract"));
    }

    function testUnauthorizedDeposit() public {
        vm.expectRevert();
        c.deposit(1);
    }

    function testDeposit() public {
        // pretend to be wstETH (which has a lot of stETH) since deal seems to break on lido
        address wstETHAddress = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
        vm.startPrank(wstETHAddress);
        // deal(stETHAddress, address(this), 42); // give ourselves some stETH
        deal(rETHAddress, address(c), 42); // give contract some rETH
        ERC20(stETHAddress).approve(address(c), 24);
        uint256 expected = rETH(rETHAddress).getRethValue(24);
        vm.expectEmit(true, true, true, true, stETHAddress);
        emit Transfer(wstETHAddress, address(c), 24);
        vm.expectEmit(true, true, true, true, rETHAddress);
        emit Transfer(address(c), wstETHAddress, expected);
        vm.expectEmit(true, true, true, true, address(c));
        emit Deposit(wstETHAddress, 0, expected, 24);
        c.deposit(24);
        vm.stopPrank();
    }

    function testDrainNothing() public {
        vm.expectEmit(true, true, true, true, stETHAddress);
        emit Transfer(address(c), ownerAddress, 0);
        vm.expectEmit(true, true, true, true, address(c));
        emit Drain(address(this), 0, 0);
        c.drain();
    }

    function testDepositNoReth() public {
        // pretend to be wstETH (which has a lot of stETH) since deal seems to break on lido
        address wstETHAddress = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
        vm.startPrank(wstETHAddress);
        ERC20(stETHAddress).approve(address(c), 24);
        vm.expectRevert();
        c.deposit(12);
        vm.stopPrank();
    }

    function testDepositTooMuch() public {
        deal(rETHAddress, address(c), 20 ether); // give contract enough rETH
        vm.expectRevert();
        c.deposit{value: 1 ether + 1}(0);
    }

    function testDepositExactly1() public {
        deal(rETHAddress, address(c), 20 ether); // give contract enough rETH
        uint256 expected = rETH(rETHAddress).getRethValue(1 ether);
        vm.expectEmit(true, true, true, true, address(c));
        emit Deposit(address(this), 1 ether, expected, 0);
        c.deposit{value: 1 ether}(0);
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
    function deposit(uint256 stETH) payable external;
    function drain() external;
}

interface rETH {
    function getRethValue(uint256) view external returns (uint256);
}

interface ERC20 {
    function approve(address, uint256) external returns (bool);
}
