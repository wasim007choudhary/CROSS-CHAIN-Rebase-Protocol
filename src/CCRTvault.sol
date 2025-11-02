// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ICCRebaseToken} from "./Interface/ICCRebaseToken.sol";

contract CCRVault {
    error CCRVault___redeem_RedeemFailed();

    ICCRebaseToken private immutable i_ccrebaseToken;

    event Deposited(address indexed user, uint256 amount);
    event Redeemed(address indexed user, uint256 amount);

    constructor(ICCRebaseToken _rebaseToken) {
        i_ccrebaseToken = _rebaseToken;
    }

    receive() external payable {}

    function deposit() external payable {
        uint256 interestRate = i_ccrebaseToken.getInterestRate();
        i_ccrebaseToken.mint(msg.sender, msg.value, interestRate);
        emit Deposited(msg.sender, msg.value);
    }

    function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = i_ccrebaseToken.balanceOf(msg.sender);
        }

        i_ccrebaseToken.burn(msg.sender, _amount);

        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert CCRVault___redeem_RedeemFailed();
        }
        emit Redeemed(msg.sender, _amount);
    }

    function getCCRebaseTokenAddress() external view returns (address) {
        return address(i_ccrebaseToken);
    }
}
