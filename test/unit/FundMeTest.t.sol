// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant STARTING_BALANCE = 100 ether;
    uint256 constant GAS_PRICE = 20;

    function setUp() external {
        fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, STARTING_BALANCE);
    }

    function testMinimumDollarIsFive() public {
        assertEq(fundMe.MINIMUM_USD(), 5e18, "Minimum USD should be 5");
    }

    function testOwnserIsMsgSender() public {
        assertEq(fundMe.getOwner(), msg.sender, "Owner should be msg.sender");
    }

    function testPriceFeedVersionIsAccurate() public {
        assertEq(fundMe.getVersion(), 4, "Price feed version should be 4");
    }

    function testFundFailsWothoutEnoughEth() public {
        vm.expectRevert();
        fundMe.fund();
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE, "Amount funded should be 10");
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        address funders = fundMe.getFunders(0);
        assertEq(funders, USER, "The funder should be USER");
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testWithdrawFailsIfNotOwner() public funded {
        vm.prank(USER);
        vm.expectRevert();
        fundMe.withdraw();
    }

    function testWithdrawWithASingleFunder() public funded {
        //arrange
        uint256 balanceOwnerStart = fundMe.getOwner().balance;
        uint256 balanceFundMeStart = address(fundMe).balance;

        //act
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        //assert
        uint256 balanceOwnerEnd = fundMe.getOwner().balance;
        uint256 balanceFundMeEnd = address(fundMe).balance;
        assertEq(
            balanceFundMeStart + balanceOwnerStart,
            balanceOwnerEnd,
            "Balances should be equal"
        );
        assertEq(balanceFundMeEnd, 0, "Balance of fundMe should be 0");
    }

    function testWithdrawFromMultipleFunders() public funded {
        //arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;

        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 balanceOwnerStart = fundMe.getOwner().balance;
        uint256 balanceFundMeStart = address(fundMe).balance;

        //act
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        //assert
        assertEq(address(fundMe).balance, 0, "Balance of fundMe should be 0");
        assertEq(
            fundMe.getOwner().balance,
            balanceFundMeStart + balanceOwnerStart,
            "Balances should be equal"
        );
    }

    function testWithdrawFromMultipleFundersCheaper() public funded {
        //arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;

        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 balanceOwnerStart = fundMe.getOwner().balance;
        uint256 balanceFundMeStart = address(fundMe).balance;

        //act
        vm.prank(fundMe.getOwner());
        fundMe.cheaperWithdraw();

        //assert
        assertEq(address(fundMe).balance, 0, "Balance of fundMe should be 0");
        assertEq(
            fundMe.getOwner().balance,
            balanceFundMeStart + balanceOwnerStart,
            "Balances should be equal"
        );
    }
}
