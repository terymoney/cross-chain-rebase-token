// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IRebaseToken.sol";

/// @title Vault
/// @author Maria Terese Ezeobi
/// @notice ETH vault that mints and redeems a rebasing token
/// @dev
/// The Vault acts as the canonical entry and exit point for ETH backing
/// the rebasing token.
///
/// Design invariants:
/// - ETH deposited into the Vault MUST equal tokens minted
/// - Tokens burned MUST precede ETH redemption
/// - The Vault never holds accounting state; all balances live in the token
/// - Interest rate snapshots are delegated entirely to the token contract
///
/// Trust assumptions:
/// - IRebaseToken correctly implements mint, burn, and interest logic
/// - ETH transfers to users may fail and are explicitly checked

contract Vault {
    IRebaseToken public immutable i_rebaseToken;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    error Vault__RedeemFailed();

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    // allows the contract to receive rewards
    receive() external payable {}

    function deposit() external payable {
        i_rebaseToken.mint(msg.sender, msg.value, i_rebaseToken.getInterestRate());
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @dev redeems rebase token for the underlying asset
     * @param _amount the amount being redeemed
     *
     */
    function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        i_rebaseToken.burn(msg.sender, _amount);
        // executes redeem of the underlying asset
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }
}
