// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../src/FundMe.sol";
import {DeployFundMe} from "../script/DeployFundMe.s.sol";

contract TestMinimumDollarIsFive is Test {
    FundMe f;
    DeployFundMe deployFundMe;
    address alice = makeAddr("alice");
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant SEND_VALUE = 0.1 ether;

    function setUp() public {
        deployFundMe = new DeployFundMe();
        f = deployFundMe.run();
        vm.deal(alice, STARTING_BALANCE);
        console.log("Hello, world!");
    }

    function testDemo() public view {
        assertEq(f.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public view {
        assertEq(f.i_owner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public view {
        uint256 version = f.getVersion();
        assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert();
        f.fund();
    }

    function testFundUpdatesFundDataStructure() public {
        vm.prank(alice);
        f.fund{value: 10 ether}();
        uint256 amountFunded = f.getAddressToAmountFunded(alice);
        assertEq(amountFunded, 10 ether);
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(alice);
        f.fund{value: 10 ether}();
        address funder = f.getFunder(0);
        assertEq(funder, alice);
    }

    modifier funded() {
        vm.prank(alice);
        f.fund{value: 10 ether}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.prank(alice);
        vm.expectRevert();
        f.withdraw();
    }

    function testWithdrawFromASingleFunder() public funded {
        uint256 startingFundMeBalance = address(f).balance;
        uint256 startingOwnerBalance = f.i_owner().balance;

        vm.startPrank(f.i_owner());
        f.withdraw();
        vm.stopPrank();

        uint256 endingFundMeBalance = address(f).balance;
        uint256 endingOwnerBalance = f.i_owner().balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(
            startingFundMeBalance + startingOwnerBalance,
            endingOwnerBalance
        );
    }

    function testWithdrawFromMultipleFunders() public funded {
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;
        for (
            uint160 i = startingFunderIndex;
            i < numberOfFunders + startingFunderIndex;
            i++
        ) {
            // we get hoax from stdcheats
            // prank + deal
            hoax(address(i), SEND_VALUE);
            f.fund{value: SEND_VALUE}();
        }

        uint256 startingFundMeBalance = address(f).balance;
        uint256 startingOwnerBalance = f.i_owner().balance;

        vm.startPrank(f.i_owner());
        f.withdraw();
        vm.stopPrank();

        assert(address(f).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance == f.i_owner().balance
        );
        assert(
            (numberOfFunders + 1) * SEND_VALUE ==
                f.i_owner().balance - startingOwnerBalance
        );
    }
}
