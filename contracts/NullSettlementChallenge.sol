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
import {DriipChallenge} from "./DriipChallenge.sol";
import {Validatable} from "./Validatable.sol";
import {ClientFundable} from "./ClientFundable.sol";
import {SafeMathIntLib} from "./SafeMathIntLib.sol";
import {SafeMathUintLib} from "./SafeMathUintLib.sol";
import {NullSettlementDispute} from "./NullSettlementDispute.sol";
import {MonetaryTypes} from "./MonetaryTypes.sol";
import {NahmiiTypes} from "./NahmiiTypes.sol";
import {SettlementTypes} from "./SettlementTypes.sol";

/**
@title NullSettlementChallenge
@notice Where null settlements are challenged
*/
contract NullSettlementChallenge is Ownable, DriipChallenge, Validatable, ClientFundable {
    using SafeMathIntLib for int256;
    using SafeMathUintLib for uint256;

    //
    // Variables
    // -----------------------------------------------------------------------------------------------------------------
    NullSettlementDispute public nullSettlementDispute;

    mapping(address => SettlementTypes.Proposal) public walletProposalMap;

    mapping(address => NahmiiTypes.Trade[]) public walletChallengedTradesMap;
    mapping(address => NahmiiTypes.Payment[]) public walletChallengedPaymentsMap;

    NahmiiTypes.Order[] public challengeCandidateOrders;
    NahmiiTypes.Trade[] public challengeCandidateTrades;
    NahmiiTypes.Payment[] public challengeCandidatePayments;

    //
    // Events
    // -----------------------------------------------------------------------------------------------------------------
    event ChangeNullSettlementDisputeEvent(NullSettlementDispute oldNullSettlementDispute, NullSettlementDispute newNullSettlementDispute);
    event StartChallenge(address wallet, int256 amount, address stageCurrencyCt, uint stageCurrencyId);

    //
    // Constructor
    // -----------------------------------------------------------------------------------------------------------------
    constructor(address owner) Ownable(owner) public {
    }

    //
    // Functions
    // -----------------------------------------------------------------------------------------------------------------
    /// @notice Change the null settlement dispute contract
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

    /// @notice Get the number of current and past null settlement challenges for given wallet
    /// @param wallet The wallet for which to return count
    /// @return The count of null settlement challenges
    function walletChallengeCount(address wallet)
    public
    view
    returns (uint256)
    {
        return walletProposalMap[wallet].nonce;
    }

    /// @notice Start null settlement challenge
    /// @param amount The concerned amount to stage
    /// @param currencyCt The address of the concerned currency contract (address(0) == ETH)
    /// @param currencyId The ID of the concerned currency (0 for ETH and ERC20)
    function startChallenge(int256 amount, address currencyCt, uint256 currencyId)
    public
    validatorInitialized
    {
        require(configuration != address(0));
        require(amount.isPositiveInt256());

        require(
            0 == walletProposalMap[msg.sender].nonce || block.timestamp >= walletProposalMap[msg.sender].timeout
        );

        int256 balanceAmount = clientFund.activeBalance(msg.sender, currencyCt, currencyId);
        require(balanceAmount >= amount);

        walletProposalMap[msg.sender].nonce = walletProposalMap[msg.sender].nonce.add(1);
        walletProposalMap[msg.sender].timeout = block.timestamp.add(configuration.settlementChallengeTimeout());
        walletProposalMap[msg.sender].status = SettlementTypes.ChallengeStatus.Qualified;
        walletProposalMap[msg.sender].currencies.length = 0;
        walletProposalMap[msg.sender].currencies.push(MonetaryTypes.Currency(currencyCt, currencyId));
        walletProposalMap[msg.sender].stageAmounts.length = 0;
        walletProposalMap[msg.sender].stageAmounts.push(amount);
        walletProposalMap[msg.sender].targetBalanceAmounts.length = 0;
        walletProposalMap[msg.sender].targetBalanceAmounts.push(balanceAmount.sub(amount));

        emit StartChallenge(msg.sender, amount, currencyCt, currencyId);
    }

    /// @notice Get null settlement challenge phase of the given wallet
    /// @param wallet The concerned wallet
    /// @return The settlement challenge phase
    function challengePhase(address wallet)
    public
    view
    returns (NahmiiTypes.ChallengePhase) {
        if (msg.sender != deployer)
            wallet = msg.sender;
        if (0 != walletProposalMap[wallet].nonce && block.timestamp < walletProposalMap[wallet].timeout)
            return NahmiiTypes.ChallengePhase.Dispute;
        else
            return NahmiiTypes.ChallengePhase.Closed;
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
    returns (SettlementTypes.ChallengeStatus)
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
    returns (MonetaryTypes.Currency)
    {
        return walletProposalMap[wallet].currencies[index];
    }

    /// @notice Get the settlement proposal stage amount of the given wallet and currency
    /// @param wallet The concerned wallet
    /// @param currencyCt The address of the concerned currency contract (address(0) == ETH)
    /// @param currencyId The ID of the concerned currency (0 for ETH and ERC20)
    /// @return The settlement proposal stage amount
    function proposalStageAmount(address wallet, address currencyCt, uint256 currencyId)
    public
    view
    returns (int256)
    {
        for (uint256 i = 0; i < walletProposalMap[wallet].currencies.length; i++) {
            if (
                walletProposalMap[wallet].currencies[i].ct == currencyCt &&
                walletProposalMap[wallet].currencies[i].id == currencyId
            )
                return walletProposalMap[wallet].stageAmounts[i];
        }
        return 0;
    }

    /// @notice Get the settlement proposal target balance amount of the given wallet and currency
    /// @param wallet The concerned wallet
    /// @param currencyCt The address of the concerned currency contract (address(0) == ETH)
    /// @param currencyId The ID of the concerned currency (0 for ETH and ERC20)
    /// @return The settlement proposal target balance amount
    function proposalTargetBalanceAmount(address wallet, address currencyCt, uint256 currencyId)
    public
    view
    returns (int256)
    {
        for (uint256 i = 0; i < walletProposalMap[wallet].currencies.length; i++) {
            if (
                walletProposalMap[wallet].currencies[i].ct == currencyCt &&
                walletProposalMap[wallet].currencies[i].id == currencyId
            )
                return walletProposalMap[wallet].targetBalanceAmounts[i];
        }
        return 0;
    }

    /// @notice Get the driip type of the given wallet's settlement proposal
    /// @param wallet The concerned wallet
    /// @return The driip type of the settlement proposal
    function proposalDriipType(address wallet)
    public
    view
    returns (NahmiiTypes.DriipType)
    {
        return walletProposalMap[wallet].driipType;
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

    /// @notice Get the settlement proposal of the given wallet
    /// @param wallet The concerned wallet
    /// @return The settlement proposal of the wallet
    //    function proposal(address wallet)
    //    public
    //    view
    //    returns (SettlementTypes.Proposal)
    //    {
    //        return walletProposalMap[wallet];
    //    }

    /// @notice Set the settlement proposal of the given wallet
    /// @dev This function can only be called by this contract's dispute instance
    /// @param wallet The concerned wallet
    /// @param proposal The settlement proposal to be set
    //    function setWalletProposal(address wallet, SettlementTypes.Proposal proposal)
    //    public
    //    onlyNullSettlementDispute
    //    {
    //        walletProposalMap[wallet].nonce = proposal.nonce;
    //        walletProposalMap[wallet].timeout = proposal.timeout;
    //        walletProposalMap[wallet].status = proposal.status;
    //        walletProposalMap[wallet].currencies.length = 0;
    //        walletProposalMap[wallet].stageAmounts.length = 0;
    //        walletProposalMap[wallet].targetBalanceAmounts.length = 0;
    //        for (uint i = 0; i < proposal.currencies.length; i++) {
    //            walletProposalMap[wallet].currencies.push(proposal.currencies[i]);
    //            walletProposalMap[wallet].stageAmounts.push(proposal.stageAmounts[i]);
    //            walletProposalMap[wallet].targetBalanceAmounts.push(proposal.targetBalanceAmounts[i]);
    //        }
    //        walletProposalMap[wallet].driipType = proposal.driipType;
    //        walletProposalMap[wallet].driipIndex = proposal.driipIndex;
    //        walletProposalMap[wallet].candidateType = proposal.candidateType;
    //        walletProposalMap[wallet].candidateIndex = proposal.candidateIndex;
    //        walletProposalMap[wallet].challenger = proposal.challenger;
    //    }

    /// @notice Set settlement proposal timeout property of the given wallet
    /// @dev This function can only be called by this contract's dispute instance
    /// @param wallet The concerned wallet
    /// @param timeout The timeout value
    function setProposalTimeout(address wallet, uint256 timeout)
    public
    onlyNullSettlementDispute
    {
        walletProposalMap[wallet].timeout = timeout;
    }

    /// @notice Set settlement proposal properties of the given wallet
    /// @dev This function can only be called by this contract's dispute instance
    /// @param wallet The concerned wallet
    /// @param status The status value
    /// @param candidateType The candidate type value
    /// @param candidateIndex The candidate index value
    /// @param challenger The challenger value
    //    function setWalletProposalStatusCandidateChallenge(address wallet, SettlementTypes.ChallengeStatus status,
    //        SettlementTypes.ChallengeCandidateType candidateType, uint256 candidateIndex, address challenger)
    //    public
    //    onlyNullSettlementDispute
    //    {
    //        walletProposalMap[wallet].status = status;
    //        walletProposalMap[wallet].candidateType = candidateType;
    //        walletProposalMap[wallet].candidateIndex = candidateIndex;
    //        walletProposalMap[wallet].challenger = challenger;
    //    }

    /// @notice Set settlement proposal status property of the given wallet
    /// @dev This function can only be called by this contract's dispute instance
    /// @param wallet The concerned wallet
    /// @param status The status value
    function setProposalStatus(address wallet, SettlementTypes.ChallengeStatus status)
    public
    onlyNullSettlementDispute
    {
        walletProposalMap[wallet].status = status;
    }

    /// @notice Set settlement proposal candidate type property of the given wallet
    /// @dev This function can only be called by this contract's dispute instance
    /// @param wallet The concerned wallet
    /// @param candidateType The candidate type value
    function setProposalCandidateType(address wallet, SettlementTypes.ChallengeCandidateType candidateType)
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

    /// @notice Reset the settlement proposal of the given wallet
    /// @dev This function can only be called by this contract's dispute instance
    /// @param wallet The concerned wallet
    //    function resetWalletProposal(address wallet)
    //    public
    //    onlyNullSettlementDispute
    //    {
    //        walletProposalMap[wallet].status = SettlementTypes.ChallengeStatus.Qualified;
    //        walletProposalMap[wallet].candidateType = SettlementTypes.ChallengeCandidateType.None;
    //        walletProposalMap[wallet].candidateIndex = 0;
    //        walletProposalMap[wallet].challenger = address(0);
    //    }

    /// @notice Challenge the null settlement by providing order candidate
    /// @param order The order candidate that challenges the challenged driip
    function challengeByOrder(NahmiiTypes.Order order)
    public
    onlyOperationalModeNormal
    {
        nullSettlementDispute.challengeByOrder(order, msg.sender);
    }

    /// @notice Unchallenge null settlement by providing trade that shows that challenge order candidate has been filled
    /// @param order The order candidate that challenged driip
    /// @param trade The trade in which order has been filled
    function unchallengeOrderCandidateByTrade(NahmiiTypes.Order order, NahmiiTypes.Trade trade)
    public
    onlyOperationalModeNormal
    {
        nullSettlementDispute.unchallengeOrderCandidateByTrade(order, trade, msg.sender);
    }

    /// @notice Challenge the null settlement by providing trade candidate
    /// @param trade The trade candidate that challenges the challenged driip
    /// @param wallet The wallet whose null settlement is being challenged
    function challengeByTrade(NahmiiTypes.Trade trade, address wallet)
    public
    onlyOperationalModeNormal
    {
        nullSettlementDispute.challengeByTrade(trade, wallet, msg.sender);
    }

    /// @notice Challenge the null settlement by providing payment candidate
    /// @param payment The payment candidate that challenges the challenged driip
    /// @param wallet The wallet whose null settlement is being challenged
    function challengeByPayment(NahmiiTypes.Payment payment, address wallet)
    public
    onlyOperationalModeNormal
    {
        nullSettlementDispute.challengeByPayment(payment, wallet, msg.sender);
    }

    /// @notice Push to store the given challenge candidate order
    /// @dev This function can only be called by this contract's dispute instance
    /// @param order The challenge candidate order to push
    function pushChallengeCandidateOrder(NahmiiTypes.Order order)
    public
    onlyNullSettlementDispute
    {
        challengeCandidateOrders.push(order);
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

    /// @notice Push to store the given challenge candidate trade
    /// @dev This function can only be called by this contract's dispute instance
    /// @param trade The challenge candidate trade to push
    function pushChallengeCandidateTrade(NahmiiTypes.Trade trade)
    public
    onlyNullSettlementDispute
    {
        pushMemoryTradeToStorageArray(trade, challengeCandidateTrades);
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

    /// @notice Push to store the given challenge candidate payment
    /// @dev This function can only be called by this contract's dispute instance
    /// @param payment The challenge candidate payment to push
    function pushChallengeCandidatePayment(NahmiiTypes.Payment payment)
    public
    onlyNullSettlementDispute
    {
        pushMemoryPaymentToStorageArray(payment, challengeCandidatePayments);
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

    //
    // Modifiers
    // -----------------------------------------------------------------------------------------------------------------
    modifier onlyNullSettlementDispute() {
        require(msg.sender == address(nullSettlementDispute));
        _;
    }
}
