/*
 * Hubii Nahmii
 *
 * Compliant with the Hubii Nahmii specification v0.12.
 *
 * Copyright (C) 2017-2018 Hubii AS
 */

pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import {Ownable} from "./Ownable.sol";
import {Configurable} from "./Configurable.sol";
import {ClientFundable} from "./ClientFundable.sol";
import {CommunityVotable} from "./CommunityVotable.sol";
import {RevenueFund} from "./RevenueFund.sol";
import {NullSettlementChallenge} from "./NullSettlementChallenge.sol";
import {Beneficiary} from "./Beneficiary.sol";
import {SafeMathIntLib} from "./SafeMathIntLib.sol";
import {SafeMathUintLib} from "./SafeMathUintLib.sol";
import {MonetaryTypes} from "./MonetaryTypes.sol";
import {NahmiiTypes} from "./NahmiiTypes.sol";
import {SettlementTypes} from "./SettlementTypes.sol";

/**
@title NullSettlement
@notice Where null settlement are finalized
*/
contract NullSettlement is Ownable, Configurable, ClientFundable, CommunityVotable {
    using SafeMathIntLib for int256;
    using SafeMathUintLib for uint256;

    //
    // Variables
    // -----------------------------------------------------------------------------------------------------------------
    NullSettlementChallenge public nullSettlementChallenge;

    uint256 public maxNullNonce;

    address[] public seizedWallets;
    mapping(address => bool) public seizedWalletsMap;

    mapping(address => mapping(address => mapping(uint256 => uint256))) public walletCurrencyMaxNullNonce;

    //
    // Events
    // -----------------------------------------------------------------------------------------------------------------
    event SettleNullEvent(address wallet, SettlementTypes.ChallengeStatus challengeStatus);
    event ChangeNullSettlementChallengeEvent(NullSettlementChallenge oldNullSettlementChallenge,
        NullSettlementChallenge newNullSettlementChallenge);

    //
    // Constructor
    // -----------------------------------------------------------------------------------------------------------------
    constructor(address owner) Ownable(owner) public {
    }

    //
    // Functions
    // -----------------------------------------------------------------------------------------------------------------
    /// @notice Change the null settlement challenge contract
    /// @param newNullSettlementChallenge The (address of) NullSettlementChallenge contract instance
    function changeNullSettlementChallenge(NullSettlementChallenge newNullSettlementChallenge)
    public
    onlyDeployer
    notNullAddress(newNullSettlementChallenge)
    {
        NullSettlementChallenge oldNullSettlementChallenge = nullSettlementChallenge;
        nullSettlementChallenge = newNullSettlementChallenge;
        emit ChangeNullSettlementChallengeEvent(oldNullSettlementChallenge, nullSettlementChallenge);
    }

    /// @notice Get the seized status of given wallet
    /// @return true if wallet is seized, false otherwise
    function isSeizedWallet(address wallet)
    public
    view
    returns (bool)
    {
        return seizedWalletsMap[wallet];
    }

    /// @notice Get the number of wallets whose funds have be seized
    /// @return Number of wallets
    function seizedWalletsCount()
    public
    view
    returns (uint256)
    {
        return seizedWallets.length;
    }

    /// @notice Update the max null settlement nonce property from CommunityVote contract
    function updateMaxNullNonce()
    public
    {
        uint256 _maxNullNonce = communityVote.getMaxNullNonce();
        if (_maxNullNonce > 0)
            maxNullNonce = _maxNullNonce;
    }

    /// @notice Settle null
    /// @param wallet The wallet whose side of the payment is to be settled
    function settleNull(address wallet)
    public
    configurationInitialized
    clientFundInitialized
    communityVoteInitialized
    nullSettlementChallengeInitialized
    {
        if (msg.sender != deployer)
            wallet = msg.sender;

        // The current null settlement proposal qualified for settlement
        if (nullSettlementChallenge.proposalStatus(wallet) == SettlementTypes.ChallengeStatus.Qualified) {

            uint256 nonce = nullSettlementChallenge.proposalNonce(wallet);

            // Require that operational mode is normal and data is available, or that nonce is
            // smaller than max null nonce
            require((configuration.isOperationalModeNormal() && communityVote.isDataAvailable())
                || (nonce < maxNullNonce));

            // If wallet has previously settled balance of the concerned currency with higher
            // null settlement nonce, then don't settle again
            require(nonce > walletCurrencyMaxNullNonce[wallet][currency.ct][currency.id]);

            // Update settled nonce of wallet and currency
            walletCurrencyMaxNullNonce[wallet][currency.ct][currency.id] = nonce;

            // Get proposal's currency, target balance amount and stage amount. (Null settlement proposals only have one of each.)
            MonetaryTypes.Currency memory currency = nullSettlementChallenge.proposalCurrency(wallet, 0);
            int256 stageAmount = nullSettlementChallenge.proposalStageAmount(wallet, currency.ct, currency.id);
            int256 targetBalanceAmount = nullSettlementChallenge.proposalTargetBalanceAmount(wallet, currency.ct, currency.id);

            // Update settled balance
            clientFund.updateSettledBalance(wallet, targetBalanceAmount, currency.ct, currency.id);

            // Stage the proposed amount
            if (stageAmount.isNonZeroPositiveInt256())
                clientFund.stage(wallet, stageAmount, currency.ct, currency.id);

            // If payment nonce is beyond max null settlement nonce then update max null nonce
            if (nonce > maxNullNonce)
                maxNullNonce = nonce;
        }

        // The current null settlement proposal disqualified for settlement
        else if (nullSettlementChallenge.proposalStatus(wallet) == SettlementTypes.ChallengeStatus.Disqualified) {
            // Add wallet to store of seized wallets
            addToSeizedWallets(wallet);

            // Slash wallet's funds
            clientFund.seizeAllBalances(wallet, nullSettlementChallenge.proposalChallenger(wallet));
        }

        // Emit event
        emit SettleNullEvent(wallet, nullSettlementChallenge.proposalStatus(wallet));
    }

    function addToSeizedWallets(address _address)
    private
    {
        if (!seizedWalletsMap[_address]) {
            seizedWallets.push(_address);
            seizedWalletsMap[_address] = true;
        }
    }

    //
    // Modifiers
    // -----------------------------------------------------------------------------------------------------------------
    modifier nullSettlementChallengeInitialized() {
        require(nullSettlementChallenge != address(0));
        _;
    }
}