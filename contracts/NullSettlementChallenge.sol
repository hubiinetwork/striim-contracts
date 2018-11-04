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
import {Challenge} from "./Challenge.sol";
import {DriipStorable} from "./DriipStorable.sol";
import {ClientFundable} from "./ClientFundable.sol";
import {SafeMathIntLib} from "./SafeMathIntLib.sol";
import {SafeMathUintLib} from "./SafeMathUintLib.sol";
import {NullSettlementDispute} from "./NullSettlementDispute.sol";
import {MonetaryTypesLib} from "./MonetaryTypesLib.sol";
import {NahmiiTypesLib} from "./NahmiiTypesLib.sol";
import {SettlementTypesLib} from "./SettlementTypesLib.sol";

/**
@title NullSettlementChallenge
@notice Where null settlements are started and challenged
*/
contract NullSettlementChallenge is Ownable, Challenge, DriipStorable, ClientFundable {
    using SafeMathIntLib for int256;
    using SafeMathUintLib for uint256;

    //
    // Variables
    // -----------------------------------------------------------------------------------------------------------------
    NullSettlementDispute public nullSettlementDispute;

    uint256 public nonce;

    address[] public challengedWallets;

    mapping(address => SettlementTypesLib.Proposal) public walletProposalMap;

    mapping(address => NahmiiTypesLib.Trade[]) public walletChallengedTradesMap;
    mapping(address => NahmiiTypesLib.Payment[]) public walletChallengedPaymentsMap;

    NahmiiTypesLib.Order[] public challengeCandidateOrders;
    NahmiiTypesLib.Trade[] public challengeCandidateTrades;
    NahmiiTypesLib.Payment[] public challengeCandidatePayments;

    //
    // Events
    // -----------------------------------------------------------------------------------------------------------------
    event ChangeNullSettlementDisputeEvent(NullSettlementDispute oldNullSettlementDispute,
        NullSettlementDispute newNullSettlementDispute);
    event StartChallengeEvent(address wallet, int256 amount, address stageCurrencyCt,
        uint stageCurrencyId);
    event StartChallengeByProxyEvent(address proxy, address wallet, int256 amount,
        address stageCurrencyCt, uint stageCurrencyId);

    //
    // Constructor
    // -----------------------------------------------------------------------------------------------------------------
    constructor(address owner) Ownable(owner) public {
    }

    //
    // Functions
    // -----------------------------------------------------------------------------------------------------------------
    /// @notice Change the settlement dispute contract
    /// @param newNullSettlementDispute The (address of) NullSettlementDispute contract instance
    function changeNullSettlementDispute(NullSettlementDispute newNullSettlementDispute)
    public
    onlyDeployer
    notNullAddress(newNullSettlementDispute)
    {
        NullSettlementDispute oldNullSettlementDispute = nullSettlementDispute;
        nullSettlementDispute = newNullSettlementDispute;
        emit ChangeNullSettlementDisputeEvent(oldNullSettlementDispute, nullSettlementDispute);
    }

    /// @notice Get the number of challenged wallets
    /// @return The number of challenged wallets
    function challengedWalletsCount()
    public
    view
    returns (uint256)
    {
        return challengedWallets.length;
    }

    /// @notice Get the number of current and past settlement challenges for given wallet
    /// @param wallet The wallet for which to return count
    /// @return The count of settlement challenges
    function walletChallengeCount(address wallet)
    public
    view
    returns (uint256)
    {
        return walletProposalMap[wallet].nonce;
    }

    /// @notice Start settlement challenge
    /// @param amount The concerned amount to stage
    /// @param currencyCt The address of the concerned currency contract (address(0) == ETH)
    /// @param currencyId The ID of the concerned currency (0 for ETH and ERC20)
    function startChallenge(int256 amount, address currencyCt, uint256 currencyId)
    public
    {
        // Start challenge for wallet
        startChallengePrivate(msg.sender, amount, currencyCt, currencyId);

        // Emit event
        emit StartChallengeEvent(msg.sender, amount, currencyCt, currencyId);
    }

    /// @notice Start settlement challenge for the given wallet
    /// @param wallet The concerned wallet
    /// @param amount The concerned amount to stage
    /// @param currencyCt The address of the concerned currency contract (address(0) == ETH)
    /// @param currencyId The ID of the concerned currency (0 for ETH and ERC20)
    function startChallengeByProxy(address wallet, int256 amount, address currencyCt, uint256 currencyId)
    public
    onlyDeployer
    {
        // Start challenge for wallet
        startChallengePrivate(wallet, amount, currencyCt, currencyId);

        // Emit event
        emit StartChallengeByProxyEvent(msg.sender, wallet, amount, currencyCt, currencyId);
    }

    /// @notice Get settlement challenge phase of the given wallet
    /// @param wallet The concerned wallet
    /// @return The settlement challenge phase
    function challengePhase(address wallet)
    public
    view
    returns (NahmiiTypesLib.ChallengePhase) {
        if (0 < walletProposalMap[wallet].nonce && block.timestamp < walletProposalMap[wallet].timeout)
            return NahmiiTypesLib.ChallengePhase.Dispute;
        else
            return NahmiiTypesLib.ChallengePhase.Closed;
    }

    /// @notice Get the settlement proposal nonce of the given wallet
    /// @param wallet The concerned wallet
    /// @return The settlement proposal nonce
    function proposalNonce(address wallet)
    public
    view
    returns (uint256)
    {
        return walletProposalMap[wallet].nonce;
    }

    /// @notice Get the settlement proposal block number of the given wallet
    /// @param wallet The concerned wallet
    /// @return The settlement proposal block number
    function proposalBlockNumber(address wallet)
    public
    view
    returns (uint256)
    {
        return walletProposalMap[wallet].blockNumber;
    }

    /// @notice Get the settlement proposal timeout of the given wallet
    /// @param wallet The concerned wallet
    /// @return The settlement proposal timeout
    function proposalTimeout(address wallet)
    public
    view
    returns (uint256)
    {
        return walletProposalMap[wallet].timeout;
    }

    /// @notice Get the settlement proposal status of the given wallet
    /// @param wallet The concerned wallet
    /// @return The settlement proposal status
    function proposalStatus(address wallet)
    public
    view
    returns (SettlementTypesLib.ProposalStatus)
    {
        return walletProposalMap[wallet].status;
    }

    /// @notice Get the settlement proposal currency count of the given wallet
    /// @param wallet The concerned wallet
    /// @return The settlement proposal currency count
    function proposalCurrencyCount(address wallet)
    public
    view
    returns (uint256)
    {
        return walletProposalMap[wallet].currencies.length;
    }

    /// @notice Get the settlement proposal currency of the given wallet at the given index
    /// @param wallet The concerned wallet
    /// @param index The index of the concerned currency
    /// @return The settlement proposal currency
    function proposalCurrency(address wallet, uint256 index)
    public
    view
    returns (MonetaryTypesLib.Currency)
    {
        require(index < walletProposalMap[wallet].currencies.length);
        return walletProposalMap[wallet].currencies[index];
    }

    /// @notice Get the settlement proposal stage amount of the given wallet and currency
    /// @param wallet The concerned wallet
    /// @param currency The concerned currency
    /// @return The settlement proposal stage amount
    function proposalStageAmount(address wallet, MonetaryTypesLib.Currency currency)
    public
    view
    returns (int256)
    {
        uint256 index = proposalCurrencyIndex(wallet, currency);
        return walletProposalMap[wallet].stageAmounts[index];
    }

    /// @notice Get the settlement proposal target balance amount of the given wallet and currency
    /// @param wallet The concerned wallet
    /// @param currency The concerned currency
    /// @return The settlement proposal target balance amount
    function proposalTargetBalanceAmount(address wallet, MonetaryTypesLib.Currency currency)
    public
    view
    returns (int256)
    {
        uint256 index = proposalCurrencyIndex(wallet, currency);
        return walletProposalMap[wallet].targetBalanceAmounts[index];
    }

    /// @notice Get the candidate type of the given wallet's settlement proposal
    /// @param wallet The concerned wallet
    /// @return The candidate type of the settlement proposal
    function proposalCandidateType(address wallet)
    public
    view
    returns (SettlementTypesLib.CandidateType)
    {
        return walletProposalMap[wallet].candidateType;
    }

    /// @notice Get the candidate index of the given wallet's settlement proposal
    /// @param wallet The concerned wallet
    /// @return The candidate index of the settlement proposal
    function proposalCandidateIndex(address wallet)
    public
    view
    returns (uint256)
    {
        return walletProposalMap[wallet].candidateIndex;
    }

    /// @notice Get the challenger of the given wallet's settlement proposal
    /// @param wallet The concerned wallet
    /// @return The challenger of the settlement proposal
    function proposalChallenger(address wallet)
    public
    view
    returns (address)
    {
        return walletProposalMap[wallet].challenger;
    }

    /// @notice Set settlement proposal status property of the given wallet
    /// @dev This function can only be called by this contract's dispute instance
    /// @param wallet The concerned wallet
    /// @param status The status value
    function setProposalStatus(address wallet, SettlementTypesLib.ProposalStatus status)
    public
    onlyNullSettlementDispute
    {
        walletProposalMap[wallet].status = status;
    }

    /// @notice Set settlement proposal candidate type property of the given wallet
    /// @dev This function can only be called by this contract's dispute instance
    /// @param wallet The concerned wallet
    /// @param candidateType The candidate type value
    function setProposalCandidateType(address wallet, SettlementTypesLib.CandidateType candidateType)
    public
    onlyNullSettlementDispute
    {
        walletProposalMap[wallet].candidateType = candidateType;
    }

    /// @notice Set settlement proposal candidate index property of the given wallet
    /// @dev This function can only be called by this contract's dispute instance
    /// @param wallet The concerned wallet
    /// @param candidateIndex The candidate index value
    function setProposalCandidateIndex(address wallet, uint256 candidateIndex)
    public
    onlyNullSettlementDispute
    {
        walletProposalMap[wallet].candidateIndex = candidateIndex;
    }

    /// @notice Set settlement proposal challenger property of the given wallet
    /// @dev This function can only be called by this contract's dispute instance
    /// @param wallet The concerned wallet
    /// @param challenger The challenger value
    function setProposalChallenger(address wallet, address challenger)
    public
    onlyNullSettlementDispute
    {
        walletProposalMap[wallet].challenger = challenger;
    }

    /// @notice Challenge the settlement by providing order candidate
    /// @param order The order candidate that challenges the challenged driip
    function challengeByOrder(NahmiiTypesLib.Order order)
    public
    onlyOperationalModeNormal
    {
        nullSettlementDispute.challengeByOrder(order, msg.sender);
    }

    /// @notice Challenge the settlement by providing trade candidate
    /// @param wallet The wallet whose settlement is being challenged
    /// @param trade The trade candidate that challenges the challenged driip
    function challengeByTrade(address wallet, NahmiiTypesLib.Trade trade)
    public
    onlyOperationalModeNormal
    {
        nullSettlementDispute.challengeByTrade(wallet, trade, msg.sender);
    }

    /// @notice Challenge the settlement by providing payment candidate
    /// @param payment The payment candidate that challenges the challenged driip
    function challengeByPayment(NahmiiTypesLib.Payment payment)
    public
    onlyOperationalModeNormal
    {
        nullSettlementDispute.challengeByPayment(payment, msg.sender);
    }

    /// @notice Get the count of challenge candidate orders
    /// @return The count of challenge candidate orders
    function challengeCandidateOrdersCount()
    public
    view
    returns (uint256)
    {
        return challengeCandidateOrders.length;
    }

    /// @notice Push to store the given challenge candidate order
    /// @dev This function can only be called by this contract's dispute instance
    /// @param order The challenge candidate order to push
    function pushChallengeCandidateOrder(NahmiiTypesLib.Order order)
    public
    onlyNullSettlementDispute
    {
        challengeCandidateOrders.push(order);
    }

    /// @notice Get the count of challenge candidate trades
    /// @return The count of challenge candidate trades
    function challengeCandidateTradesCount()
    public
    view
    returns (uint256)
    {
        return challengeCandidateTrades.length;
    }

    /// @notice Push to store the given challenge candidate trade
    /// @dev This function can only be called by this contract's dispute instance
    /// @param trade The challenge candidate trade to push
    function pushChallengeCandidateTrade(NahmiiTypesLib.Trade trade)
    public
    onlyNullSettlementDispute
    {
        pushMemoryTradeToStorageArray(trade, challengeCandidateTrades);
    }

    /// @notice Get the count of challenge candidate payments
    /// @return The count of challenge candidate payments
    function challengeCandidatePaymentsCount()
    public
    view
    returns (uint256)
    {
        return challengeCandidatePayments.length;
    }

    /// @notice Push to store the given challenge candidate payment
    /// @dev This function can only be called by this contract's dispute instance
    /// @param payment The challenge candidate payment to push
    function pushChallengeCandidatePayment(NahmiiTypesLib.Payment payment)
    public
    onlyNullSettlementDispute
    {
        pushMemoryPaymentToStorageArray(payment, challengeCandidatePayments);
    }

    function startChallengePrivate(address wallet, int256 amount, address currencyCt, uint256 currencyId)
    private
    configurationInitialized
    {
        require(amount.isPositiveInt256());

        // Require that wallet has no overlap with ongoing challenge
        require(NahmiiTypesLib.ChallengePhase.Closed == challengePhase(wallet));

        uint256 activeBalanceLogEntriesCount = clientFund.activeBalanceLogEntriesCount(wallet, currencyCt, currencyId);
        require(activeBalanceLogEntriesCount > 0);

        (int256 activeBalanceAmount, uint256 activeBalanceBlockNumber) = clientFund.activeBalanceLogEntry(
            wallet, currencyCt, currencyId, activeBalanceLogEntriesCount.sub(1)
        );
        require(activeBalanceAmount >= amount);

        if (0 == walletProposalMap[wallet].nonce)
            challengedWallets.push(wallet);

        walletProposalMap[wallet].nonce = ++nonce;
        walletProposalMap[wallet].blockNumber = activeBalanceBlockNumber;
        walletProposalMap[wallet].timeout = block.timestamp.add(configuration.settlementChallengeTimeout());
        walletProposalMap[wallet].status = SettlementTypesLib.ProposalStatus.Qualified;
        walletProposalMap[wallet].currencies.length = 0;
        walletProposalMap[wallet].currencies.push(MonetaryTypesLib.Currency(currencyCt, currencyId));
        walletProposalMap[wallet].stageAmounts.length = 0;
        walletProposalMap[wallet].stageAmounts.push(amount);
        walletProposalMap[wallet].targetBalanceAmounts.length = 0;
        walletProposalMap[wallet].targetBalanceAmounts.push(activeBalanceAmount.sub(amount));
    }

    function proposalCurrencyIndex(address wallet, MonetaryTypesLib.Currency currency)
    private
    view
    returns (uint256)
    {
        for (uint256 i = 0; i < walletProposalMap[wallet].currencies.length; i++) {
            if (
                walletProposalMap[wallet].currencies[i].ct == currency.ct &&
                walletProposalMap[wallet].currencies[i].id == currency.id
            )
                return i;
        }
        require(false);
    }

    //
    // Modifiers
    // -----------------------------------------------------------------------------------------------------------------
    modifier onlyNullSettlementDispute() {
        require(msg.sender == address(nullSettlementDispute));
        _;
    }
}
