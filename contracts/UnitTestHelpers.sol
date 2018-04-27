/*!
 * Hubii - Omphalos
 *
 * Compliant with the Omphalos specification v0.12.
 *
 * Copyright (C) 2017-2018 Hubii AS
 */
pragma solidity ^0.4.21;

import "./SafeMathUint.sol";
import "./ERC20.sol";
import "./ClientFund.sol";

/**
@title UnitTestHelpers
@notice A dummy SC where several functions are added to assist in unit testing.
*/
contract UnitTestHelpers {
    using SafeMathUint for uint256;

    //
    // Constructor
    // -----------------------------------------------------------------------------------------------------------------
    function UnitTestHelpers() public {
    }

    function () public payable {
    }

    //
    // Functions
    // -----------------------------------------------------------------------------------------------------------------
    function callToTransferFromDepositedToStagedBalance(address clientFunds, address sourceWallet, address destWallet, uint256 amount, address token) public {
        require(clientFunds != address(0));
        ClientFund sc = ClientFund(clientFunds);
        sc.transferFromDepositedToStagedBalance(sourceWallet, destWallet, amount, token);
    }

    function callToWithdrawFromDepositedBalance(address clientFunds, address sourceWallet, address destWallet, uint256 amount, address token) public {
        require(clientFunds != address(0));
        ClientFund sc = ClientFund(clientFunds);
        sc.withdrawFromDepositedBalance(sourceWallet, destWallet, amount, token);
    }

    function callToDepositEthersToStagedBalance(address clientFunds, address destWallet) public payable {
        require(clientFunds != address(0));
        ClientFund sc = ClientFund(clientFunds);
        sc.depositEthersToStagedBalance.value(msg.value)(destWallet);
    }

    function callToDepositTokensToStagedBalance(address clientFunds, address destWallet, address token, uint256 amount) public {
        require(clientFunds != address(0));
        ClientFund sc = ClientFund(clientFunds);
        sc.depositTokensToStagedBalance(destWallet, token, amount);
    }

    function erc20_approve(address token, address spender, uint256 value) public {
        require(token != address(0));
        ERC20 tok = ERC20(token);
        tok.approve(spender, value);
    }
}
