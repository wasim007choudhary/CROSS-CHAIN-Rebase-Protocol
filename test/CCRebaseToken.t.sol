// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {CCRToken} from "../src/CCRebaseToken.sol";
import {CCRVault} from "../src/CCRTvault.sol";
import {ICCRebaseToken} from "../src/Interface/ICCRebaseToken.sol";

contract CCRebaseTokenTest is Test {
    CCRToken private ccrToken;
    CCRVault private ccrVault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    address public user2nd = makeAddr("user2nd");

    function setUp() public {
        vm.startPrank(owner);
        ccrToken = new CCRToken();
        ccrVault = new CCRVault(ICCRebaseToken(address(ccrToken)));
        ccrToken.grantMintAndBurnRoleAccess(address(ccrVault));
        (bool success,) = payable(address(ccrVault)).call{value: 1e18}("");
        if (!success) {
            console.log("Encountered An Error");
        }
        vm.stopPrank();
    }

    function testNameAndSymbolOfTheToken() public view {
        string memory expectedName = "CC Rebase Token";
        string memory expectedSymbol = "$CCRT";
        string memory actualName = ccrToken.name();
        string memory actualSymbol = ccrToken.symbol();

        assert(keccak256(abi.encodePacked(expectedName)) == keccak256(abi.encodePacked(actualName)));
        assert(keccak256(abi.encodePacked(expectedSymbol)) == keccak256(abi.encodePacked(actualSymbol)));
    }

    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        vm.startPrank(user);
        vm.deal(user, amount);
        ccrVault.deposit{value: amount}();
        uint256 startBalance = ccrToken.balanceOf(user);
        assertEq(startBalance, amount);

        vm.warp(block.timestamp + 2 hours);
        uint256 balanceAfter1stWarp = ccrToken.balanceOf(user);
        assertGt(balanceAfter1stWarp, startBalance);

        vm.warp(block.timestamp + 2 hours);
        uint256 balanceAfter2ndWarp = ccrToken.balanceOf(user);
        assertGt(balanceAfter2ndWarp, balanceAfter1stWarp);

        uint256 amountDiff1st = balanceAfter1stWarp - startBalance;
        uint256 amountDiff2nd = balanceAfter2ndWarp - balanceAfter1stWarp;

        assertApproxEqAbs(amountDiff2nd, amountDiff1st, 1);
        vm.stopPrank();
    }

    function testRedeemInstant(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        vm.startPrank(user);
        vm.deal(user, amount);
        ccrVault.deposit{value: amount}();
        assertEq(ccrToken.balanceOf(user), amount);

        ccrVault.redeem(type(uint256).max);
        assertEq(address(user).balance, amount);
        assertEq(ccrToken.balanceOf(user), 0);
        vm.stopPrank();
    }

    function addRewardToVault(uint256 rewardAmount) public {
        (bool success,) = payable(ccrVault).call{value: rewardAmount}("");
        if (!success) {
            console.log("Failed To Add Reward");
        }
    }

    function testRedeemAfterTimeElasped(uint256 amount, uint256 time) public {
        time = bound(time, 1000, type(uint96).max);
        amount = bound(amount, 1e5, type(uint96).max);

        vm.prank(user);
        vm.deal(user, amount);
        ccrVault.deposit{value: amount}();
        uint256 depositAmount = ccrToken.balanceOf(user);

        vm.warp(block.timestamp + time);
        uint256 balanceAfterWarp = ccrToken.balanceOf(user);

        uint256 rewardAmount = balanceAfterWarp - depositAmount;
        vm.prank(owner);
        vm.deal(owner, rewardAmount);
        addRewardToVault(rewardAmount);

        vm.prank(user);
        ccrVault.redeem(type(uint256).max);
        uint256 userEthBalance = address(user).balance;

        assertEq(depositAmount, amount);
        assertGt(balanceAfterWarp, depositAmount);
        assertEq(userEthBalance, depositAmount + rewardAmount);
    }

    function testFullTransfer(uint256 amount, uint256 sendAmount) public {
        amount = bound(amount, 1e5 + 1e3, type(uint96).max);
        sendAmount = bound(sendAmount, 1e5, amount - 1e3);
        vm.deal(user, amount);
        vm.prank(user);
        ccrVault.deposit{value: amount}();

        // uint256 userBalance = ccrToken.balanceOf(user);
        uint256 user2balance = ccrToken.balanceOf(user2nd);

        assertEq(ccrToken.balanceOf(user), amount);
        assertEq(user2balance, 0);

        vm.prank(owner);
        ccrToken.setInterestRate(4e10);

        vm.prank(user);
        ccrToken.transfer(user2nd, sendAmount);

        uint256 userBalanceAfterTransfer = ccrToken.balanceOf(user);
        uint256 user2ndBalanceAfterTransfer = ccrToken.balanceOf(user2nd);
        console.log("sendAmount -> ", sendAmount);
        console.log("user2ndBalanceAfterTransfer -> ", user2ndBalanceAfterTransfer);

        assertEq(userBalanceAfterTransfer, amount - sendAmount);
        assertEq(user2ndBalanceAfterTransfer, sendAmount);

        vm.warp(block.timestamp + 2 days);

        uint256 userBalanceAfterWarp = ccrToken.balanceOf(user);
        uint256 user2ndBalanceAfterWarp = ccrToken.balanceOf(user2nd);

        uint256 userInterestRate = ccrToken.getUserInterestRate(user);
        uint256 user2ndInterestRate = ccrToken.getUserInterestRate(user2nd);

        assertGt(userBalanceAfterWarp, userBalanceAfterTransfer);
        assertGt(user2ndBalanceAfterWarp, user2ndBalanceAfterTransfer);

        assertNotEq(userInterestRate, 4e10);
        assertNotEq(user2ndInterestRate, 4e10);

        assertEq(userInterestRate, 5e10);
        assertEq(user2ndInterestRate, 5e10);
    }

    function testFullBalanceTransfer(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.prank(user);
        ccrVault.deposit{value: amount}();

        uint256 principalBlanceOfUser = ccrToken.principalBalanceOf(user);
        assertEq(principalBlanceOfUser, amount);
        vm.warp(block.timestamp + 5 days);
        uint256 balanceNow = ccrToken.balanceOf(user);

        vm.prank(user);
        ccrToken.transfer(user2nd, type(uint256).max);

        // uint256 principalBlanceOfUser2nd = ccrToken.principalBalanceOf(user2nd); uncomment if want to check the below commented assertEq after plaicng vm.warp after transfer is called not before
        uint256 userBalanceNow = ccrToken.balanceOf(user);
        uint256 user2ndBalanceNow = ccrToken.balanceOf(user2nd);
        // assertEq(principalBlanceOfUser2nd, amount); true if vm warp done after transfer!! then uncomment
        assertEq(user2ndBalanceNow, balanceNow);
        assertEq(userBalanceNow, 0);
    }

    function testInstantTransferFrom(uint256 amount, uint256 sendAmount) public {
        amount = bound(amount, 1e5 + 1e4, type(uint96).max);
        sendAmount = bound(sendAmount, 1e5, amount - 1e4);

        vm.deal(user, amount);
        vm.prank(user);
        ccrVault.deposit{value: amount}();

        vm.prank(user);
        ccrToken.approve(user2nd, sendAmount);
        vm.prank(user2nd);
        ccrToken.transferFrom(user, user2nd, sendAmount);

        uint256 userBalanceAfterTransfer = ccrToken.balanceOf(user);
        uint256 user2ndBalanceAfterTransfer = ccrToken.balanceOf(user2nd);

        assertEq(userBalanceAfterTransfer, amount - sendAmount);

        assertEq(user2ndBalanceAfterTransfer, sendAmount);
    }

    function testTransferFromFunctionWIthFullBalance(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.prank(user);
        ccrVault.deposit{value: amount}();

        vm.warp(block.timestamp + 10 days);

        uint256 userbalanceNow = ccrToken.balanceOf(user);
        vm.prank(user);
        ccrToken.approve(user2nd, userbalanceNow);
        vm.prank(user2nd);
        ccrToken.transferFrom(user, user2nd, type(uint256).max);

        assertEq(ccrToken.balanceOf(user2nd), userbalanceNow);
        assertEq(ccrToken.balanceOf(user), 0);
    }

    function testCannotMintIfNotGivenRole() public {
        vm.deal(user, 5e18);
        vm.prank(user);
        ccrVault.deposit{value: 5e18}();

        vm.startPrank(user);
        uint256 userInterestRate = ccrToken.getUserInterestRate(user);
        console.log("Check User Interest Rate -> ", userInterestRate);
        vm.expectRevert();
        ccrToken.mint(user, 5e18, userInterestRate);
    }

    function testCannotBurnIfRoleNotGiven() public {
        vm.deal(user, 5e18);
        vm.prank(user);
        ccrVault.deposit{value: 5e18}();

        vm.startPrank(user);
        vm.expectRevert();
        ccrToken.burn(user, 5e18);
    }

    function testCannotsetInterestIfNotOwner() public {
        vm.deal(user, 5e18);
        vm.prank(user);
        ccrVault.deposit{value: 5e18}();

        vm.prank(user);
        vm.expectRevert();
        ccrToken.setInterestRate(2e10);
    }

    function testWillRevertIfInterestRateIncreased() public {
        uint256 previousInterestRate = ccrToken.getInterestRate();
        console.log(previousInterestRate);
        vm.expectRevert(
            abi.encodeWithSelector(
                CCRToken.CCRToken___InterestRateCanOnlyDecrease.selector, previousInterestRate, previousInterestRate + 1
            )
        );
        vm.prank(owner);
        uint256 newInterest = previousInterestRate + 1;
        ccrToken.setInterestRate(newInterest);

        vm.expectRevert(
            abi.encodeWithSelector(
                CCRToken.CCRToken___InterestRateCanOnlyDecrease.selector, previousInterestRate, previousInterestRate
            )
        );
        vm.prank(owner);
        ccrToken.setInterestRate(previousInterestRate);
    }

    event InterestRateSet(uint256 newInterestRate);

    function testSetInterestRateSuccesfullAndEmitsEvent(uint256 newInterestRate, uint256 amount) public {
        newInterestRate = bound(newInterestRate, 0, ccrToken.getInterestRate() - 1);
        amount = bound(amount, 1e5, type(uint96).max);

        uint256 defaultInterestRate = ccrToken.getInterestRate();
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit InterestRateSet(newInterestRate);
        ccrToken.setInterestRate(newInterestRate);
        uint256 newInterestRateAfterSet = ccrToken.getInterestRate();
        assertEq(newInterestRateAfterSet, newInterestRate);

        vm.deal(user, amount);

        vm.prank(user);
        ccrVault.deposit{value: amount}();
        uint256 userInterestRate = ccrToken.getUserInterestRate(user);

        assertGt(defaultInterestRate, newInterestRateAfterSet);
        assertEq(userInterestRate, newInterestRateAfterSet);
    }

    function testCCRTokenAddress() public view {
        address expectedAddress = address(ccrToken);
        address actualAddress = ccrVault.getCCRebaseTokenAddress();
        assertEq(expectedAddress, actualAddress);
    }

    function testRedeemWillRevertWithRedeemedFailedError(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.prank(user);

        ccrVault.deposit{value: amount}();

        vm.warp(block.timestamp + 1 hours);

        vm.expectRevert(CCRVault.CCRVault___redeem_RedeemFailed.selector);
        vm.prank(user);
        ccrVault.redeem(type(uint256).max);
    }
}
