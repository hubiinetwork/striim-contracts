/*
 * Hubii Striim
 *
 * Compliant with the Hubii Striim specification v0.12.
 *
 * Copyright (C) 2017-2018 Hubii AS
 */

pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import {SafeMathInt} from "./SafeMathInt.sol";
import {SafeMathUint} from "./SafeMathUint.sol";
import "./Ownable.sol";
import "./Types.sol";
import "./ERC20.sol";
import {Configurable} from "./Configurable.sol";
import {Validatable} from "./Validatable.sol";
import {ClientFundable} from "./ClientFundable.sol";
import {CommunityVotable} from "./CommunityVotable.sol";
import "./ReserveFund.sol";
import "./RevenueFund.sol";
import {DealSettlementChallenge} from "./DealSettlementChallenge.sol";
import {SelfDestructible} from "./SelfDestructible.sol";

/**
@title Exchange
@notice The orchestrator of trades and payments on-chain.
*/
contract Exchange is Ownable, Configurable, Validatable, ClientFundable, CommunityVotable, SelfDestructible {
    using SafeMathInt for int256;
    using SafeMathUint for uint256;

    //
    // Variables
    // -----------------------------------------------------------------------------------------------------------------
    uint256 public highestAbsoluteDealNonce;

    address[] public seizedWallets;
    mapping(address => bool) public seizedWalletsMap;

    DealSettlementChallenge public dealSettlementChallenge;
    ReserveFund public tradesReserveFund;
    ReserveFund public paymentsReserveFund;
    RevenueFund public tradesRevenueFund;
    RevenueFund public paymentsRevenueFund;

    Types.Settlement[] public settlements;
    mapping(address => uint256[]) walletSettlementIndexMap;

    //
    // Events
    // -----------------------------------------------------------------------------------------------------------------
    event SettleDealAsTradeEvent(Types.Trade trade, address wallet);
    event SettleDealAsPaymentEvent(Types.Payment payment, address wallet);
    event ChangeDealSettlementChallengeEvent(DealSettlementChallenge oldDealSettlementChallenge, DealSettlementChallenge newDealSettlementChallenge);
    event ChangeTradesReserveFundEvent(ReserveFund oldReserveFund, ReserveFund newReserveFund);
    event ChangePaymentsReserveFundEvent(ReserveFund oldReserveFund, ReserveFund newReserveFund);
    event ChangeTradesRevenueFundEvent(RevenueFund oldRevenueFund, RevenueFund newRevenueFund);
    event ChangePaymentsRevenueFundEvent(RevenueFund oldRevenueFund, RevenueFund newRevenueFund);

    //
    // Constructor
    // -----------------------------------------------------------------------------------------------------------------
    constructor(address owner) Ownable(owner) public {
    }

    //
    // Functions
    // -----------------------------------------------------------------------------------------------------------------
    /// @notice Change the deal settlement challenge contract
    /// @param newDealSettlementChallenge The (address of) DealSettlementChallenge contract instance
    function changeDealSettlementChallenge(DealSettlementChallenge newDealSettlementChallenge)
    public
    onlyOwner
    notNullAddress(newDealSettlementChallenge)
    notEqualAddresses(newDealSettlementChallenge, dealSettlementChallenge)
    {
        DealSettlementChallenge oldDealSettlementChallenge = dealSettlementChallenge;
        dealSettlementChallenge = newDealSettlementChallenge;
        emit ChangeDealSettlementChallengeEvent(oldDealSettlementChallenge, dealSettlementChallenge);
    }

    /// @notice Change the trades reserve fund contract
    /// @param newTradesReserveFund The (address of) trades ReserveFund contract instance
    function changeTradesReserveFund(ReserveFund newTradesReserveFund)
    public
    onlyOwner
    notNullAddress(newTradesReserveFund)
    notEqualAddresses(newTradesReserveFund, tradesReserveFund)
    {
        ReserveFund oldTradesReserveFund = tradesReserveFund;
        tradesReserveFund = newTradesReserveFund;
        emit ChangeTradesReserveFundEvent(oldTradesReserveFund, tradesReserveFund);
    }

    /// @notice Change the payments reserve fund contract
    /// @param newPaymentsReserveFund The (address of) payments ReserveFund contract instance
    function changePaymentsReserveFund(ReserveFund newPaymentsReserveFund)
    public
    onlyOwner
    notNullAddress(newPaymentsReserveFund)
    notEqualAddresses(newPaymentsReserveFund, paymentsReserveFund)
    {
        ReserveFund oldPaymentsReserveFund = paymentsReserveFund;
        paymentsReserveFund = newPaymentsReserveFund;
        emit ChangePaymentsReserveFundEvent(oldPaymentsReserveFund, paymentsReserveFund);
    }

    /// @notice Change the trades revenue fund contract
    /// @param newTradesRevenueFund The (address of) trades RevenueFund contract instance
    function changeTradesRevenueFund(RevenueFund newTradesRevenueFund)
    public
    onlyOwner
    notNullAddress(newTradesRevenueFund)
    notEqualAddresses(newTradesRevenueFund, tradesRevenueFund)
    {
        RevenueFund oldTradesRevenueFund = tradesRevenueFund;
        tradesRevenueFund = newTradesRevenueFund;
        emit ChangeTradesRevenueFundEvent(oldTradesRevenueFund, tradesRevenueFund);
    }

    /// @notice Change the payments revenue fund contract
    /// @param newPaymentsRevenueFund The (address of) payments RevenueFund contract instance
    function changePaymentsRevenueFund(RevenueFund newPaymentsRevenueFund)
    public
    onlyOwner
    notNullAddress(newPaymentsRevenueFund)
    notEqualAddresses(newPaymentsRevenueFund, paymentsRevenueFund)
    {
        RevenueFund oldPaymentsRevenueFund = paymentsRevenueFund;
        paymentsRevenueFund = newPaymentsRevenueFund;
        emit ChangePaymentsRevenueFundEvent(oldPaymentsRevenueFund, paymentsRevenueFund);
    }

    /// @notice Get the seized status of given wallet
    /// @return true if wallet is seized, false otherwise
    function isSeizedWallet(address wallet) public view returns (bool) {
        return seizedWalletsMap[wallet];
    }

    /// @notice Get the number of wallets whose funds have be seized
    /// @return Number of wallets
    function seizedWalletsCount() public view returns (uint256) {
        return seizedWallets.length;
    }

    /// @notice Get the count of settlements
    function settlementsCount() public view returns (uint256) {
        return settlements.length;
    }

    /// @notice Get the count of settlements for given wallet
    /// @param wallet The address for which to return settlement count
    function walletSettlementsCount(address wallet) public view returns (uint256) {
        return walletSettlementIndexMap[wallet].length;
    }

    /// @notice Get settlement of given wallet
    /// @param wallet The address for which to return settlement
    /// @param index The wallet's settlement index
    function walletSettlement(address wallet, uint256 index) public view returns (Types.Settlement) {
        require(walletSettlementIndexMap[wallet].length > index);
        return settlements[walletSettlementIndexMap[wallet][index]];
    }

    /// @notice Update the highest absolute deal nonce property from CommunityVote contract
    function updateHighestAbsoluteDealNonce() public {
        uint256 _highestAbsoluteDealNonce = communityVote.getHighestAbsoluteDealNonce();
        if (_highestAbsoluteDealNonce > 0) {
            highestAbsoluteDealNonce = _highestAbsoluteDealNonce;
        }
    }

    /// @notice Settle deal that is a trade
    /// @param trade The trade to be settled
    /// @param wallet The wallet whose side of the deal is to be settled one-sidedly if supported by reserve fund
    function settleDealAsTrade(Types.Trade trade, address wallet)
    public
    validatorInitialized
    onlySealedTrade(trade)
    {
        require(communityVote != address(0));
        require(dealSettlementChallenge != address(0));
        require(configuration != address(0));
        require(clientFund != address(0));

        if (!trade.immediateSettlement)
            require(tradesReserveFund != address(0));

        if (msg.sender != owner)
            wallet = msg.sender;

        require(Types.isTradeParty(trade, wallet));
        require(!communityVote.isDoubleSpenderWallet(wallet));

        (Types.ChallengeResult result, address challenger) = dealSettlementChallenge.dealSettlementChallengeStatus(wallet, trade.nonce);

        if (Types.ChallengeResult.Qualified == result) {

            require((configuration.isOperationalModeNormal() && communityVote.isDataAvailable())
                || (trade.nonce < highestAbsoluteDealNonce));

            Types.TradePartyRole tradePartyRole = (wallet == trade.buyer.wallet ? Types.TradePartyRole.Buyer : Types.TradePartyRole.Seller);

            // Positive transfer of intended currency defined as being from trade seller to buyer
            bool transferIntendedToParty = ((0 < trade.transfers.intended.net && Types.TradePartyRole.Buyer == tradePartyRole)
            || (0 > trade.transfers.intended.net && Types.TradePartyRole.Seller == tradePartyRole));
            int256 transferIntendedAbs = trade.transfers.intended.net.abs();

            // Positive transfer of conjugate currency defined as being from trade buyer to seller
            //            bool transferConjugateToParty = ((0 < trade.transfers.conjugate.net && Types.TradePartyRole.Seller == tradePartyRole)
            //            || (0 > trade.transfers.conjugate.net && Types.TradePartyRole.Buyer == tradePartyRole));
            //            int256 transferConjugateAbs = trade.transfers.conjugate.net.abs();

            //            if (!trade.immediateSettlement &&
            //            (!transferIntendedToParty || tradesReserveFund.outboundTransferSupported(trade.currencies.intended, transferIntendedAbs)) &&
            //            (!transferConjugateToParty || tradesReserveFund.outboundTransferSupported(trade.currencies.conjugate, transferConjugateAbs))) {
            //                tradesReserveFund.twoWayTransfer(wallet, trade.currencies.intended, transferIntendedToParty ? transferIntendedAbs.mul(- 1) : transferIntendedAbs);
            //                tradesReserveFund.twoWayTransfer(wallet, trade.currencies.conjugate, transferConjugateToParty ? transferConjugateAbs.mul(- 1) : transferConjugateAbs);
            //                addOneSidedSettlementFromTrade(trade, wallet);
            //            } else {
            settleTradeTransfers(trade);
            settleTradeFees(trade);
            addTwoSidedSettlementFromTrade(trade);
            //            }

            if (trade.nonce > highestAbsoluteDealNonce)
                highestAbsoluteDealNonce = trade.nonce;

        } else if (Types.ChallengeResult.Disqualified == result) {
            clientFund.seizeDepositedAndSettledBalances(wallet, challenger);
            addToSeizedWallets(wallet);
        }

        emit SettleDealAsTradeEvent(trade, wallet);
    }

    /// @notice Settle deal that is a payment
    /// @param payment The payment to be settled
    /// @param wallet The wallet whose side of the deal is to be settled one-sidedly if supported by reserve fund
    function settleDealAsPayment(Types.Payment payment, address wallet)
    public
    validatorInitialized
    onlySealedPayment(payment)
    {
        require(communityVote != address(0));
        require(dealSettlementChallenge != address(0));
        require(configuration != address(0));
        require(clientFund != address(0));

        if (!payment.immediateSettlement)
            require(paymentsReserveFund != address(0));

        if (msg.sender != owner)
            wallet = msg.sender;

        require(Types.isPaymentParty(payment, wallet));
        require(!communityVote.isDoubleSpenderWallet(wallet));

        (Types.ChallengeResult result, address challenger) = dealSettlementChallenge.dealSettlementChallengeStatus(wallet, payment.nonce);

        if (Types.ChallengeResult.Qualified == result) {

            require((configuration.isOperationalModeNormal() && communityVote.isDataAvailable())
                || (payment.nonce < highestAbsoluteDealNonce));

            Types.PaymentPartyRole paymentPartyRole = (wallet == payment.sender.wallet ? Types.PaymentPartyRole.Sender : Types.PaymentPartyRole.Recipient);

            // Positive transfer defined as being from payment sender to recipient
            //            bool transferToParty = ((0 > payment.transfers.net && Types.PaymentPartyRole.Sender == paymentPartyRole)
            //            || (0 < payment.transfers.net && Types.PaymentPartyRole.Recipient == paymentPartyRole));
            //            int256 transferAbs = payment.transfers.net.abs();

            //            if (!payment.immediateSettlement &&
            //            (!transferToParty || paymentsReserveFund.outboundTransferSupported(payment.currency, transferAbs))) {
            //                paymentsReserveFund.twoWayTransfer(wallet, payment.currency, transferToParty ? transferAbs.mul(-1) : transferAbs);
            //                addOneSidedSettlementFromPayment(payment, wallet);
            //            } else {
            settlePaymentTransfers(payment);
            settlePaymentFees(payment);
            addTwoSidedSettlementFromPayment(payment);
            //            }

            if (payment.nonce > highestAbsoluteDealNonce)
                highestAbsoluteDealNonce = payment.nonce;

        } else if (Types.ChallengeResult.Disqualified == result) {
            clientFund.seizeDepositedAndSettledBalances(wallet, challenger);
            addToSeizedWallets(wallet);
        }

        emit SettleDealAsPaymentEvent(payment, wallet);
    }

    function settleTradeTransfers(Types.Trade trade) private {
        if (0 < trade.transfers.intended.net.sub(trade.buyer.netFees.intended)) {// Transfer from seller to buyer
            clientFund.transferFromDepositedToSettledBalance(
                trade.seller.wallet,
                trade.buyer.wallet,
                trade.transfers.intended.net.sub(trade.buyer.netFees.intended),
                trade.currencies.intended
            );

        } else if (0 > trade.transfers.intended.net.add(trade.seller.netFees.intended)) {// Transfer from buyer to seller
            clientFund.transferFromDepositedToSettledBalance(
                trade.buyer.wallet,
                trade.seller.wallet,
                trade.transfers.intended.net.add(trade.seller.netFees.intended).abs(),
                trade.currencies.intended
            );
        }

        if (0 < trade.transfers.conjugate.net.sub(trade.seller.netFees.conjugate)) {// Transfer from buyer to seller
            clientFund.transferFromDepositedToSettledBalance(
                trade.buyer.wallet,
                trade.seller.wallet,
                trade.transfers.conjugate.net.sub(trade.seller.netFees.conjugate),
                trade.currencies.conjugate
            );

        } else if (0 > trade.transfers.conjugate.net.add(trade.buyer.netFees.conjugate)) {// Transfer from seller to buyer
            clientFund.transferFromDepositedToSettledBalance(
                trade.seller.wallet,
                trade.buyer.wallet,
                trade.transfers.conjugate.net.add(trade.buyer.netFees.conjugate).abs(),
                trade.currencies.conjugate
            );
        }
    }

    function settlePaymentTransfers(Types.Payment payment) private {
        if (0 < payment.transfers.net.sub(payment.sender.netFee)) {// Transfer from sender to recipient
            clientFund.transferFromDepositedToSettledBalance(
                payment.sender.wallet,
                payment.recipient.wallet,
                payment.transfers.net.sub(payment.sender.netFee),
                payment.currency
            );

        } else if (0 > payment.transfers.net.add(payment.recipient.netFee)) {// Transfer from recipient to sender
            clientFund.transferFromDepositedToSettledBalance(
                payment.recipient.wallet,
                payment.sender.wallet,
                payment.transfers.net.add(payment.recipient.netFee).abs(),
                payment.currency
            );
        }
    }

    function addOneSidedSettlementFromTrade(Types.Trade trade, address wallet) private {
        settlements.push(
            Types.Settlement(trade.nonce, Types.DealType.Trade, Types.Sidedness.OneSided, [wallet, address(0)])
        );
        walletSettlementIndexMap[wallet].push(settlements.length - 1);
    }

    function addTwoSidedSettlementFromTrade(Types.Trade trade) private {
        settlements.push(
            Types.Settlement(trade.nonce, Types.DealType.Trade, Types.Sidedness.TwoSided, [trade.buyer.wallet, trade.seller.wallet])
        );
        walletSettlementIndexMap[trade.buyer.wallet].push(settlements.length - 1);
        walletSettlementIndexMap[trade.seller.wallet].push(settlements.length - 1);
    }

    function addOneSidedSettlementFromPayment(Types.Payment payment, address wallet) private {
        settlements.push(
            Types.Settlement(payment.nonce, Types.DealType.Payment, Types.Sidedness.OneSided, [wallet, address(0)])
        );
        walletSettlementIndexMap[wallet].push(settlements.length - 1);
    }

    function addTwoSidedSettlementFromPayment(Types.Payment payment) private {
        settlements.push(
            Types.Settlement(payment.nonce, Types.DealType.Payment, Types.Sidedness.TwoSided, [payment.sender.wallet, payment.recipient.wallet])
        );
        walletSettlementIndexMap[payment.sender.wallet].push(settlements.length - 1);
        walletSettlementIndexMap[payment.recipient.wallet].push(settlements.length - 1);
    }

    function settleTradeFees(Types.Trade trade) private {
        if (0 < trade.buyer.netFees.intended) {
            clientFund.withdrawFromDepositedBalance(
                trade.buyer.wallet,
                tradesRevenueFund,
                trade.buyer.netFees.intended,
                trade.currencies.intended
            );
            if (address(0) != trade.currencies.intended)
                tradesRevenueFund.recordDepositTokens(ERC20(trade.currencies.intended), trade.buyer.netFees.intended);
        }

        if (0 < trade.buyer.netFees.conjugate) {
            clientFund.withdrawFromDepositedBalance(
                trade.buyer.wallet,
                tradesRevenueFund,
                trade.buyer.netFees.conjugate,
                trade.currencies.conjugate
            );
            if (address(0) != trade.currencies.conjugate)
                tradesRevenueFund.recordDepositTokens(ERC20(trade.currencies.conjugate), trade.buyer.netFees.conjugate);
        }

        if (0 < trade.seller.netFees.intended) {
            clientFund.withdrawFromDepositedBalance(
                trade.seller.wallet,
                tradesRevenueFund,
                trade.seller.netFees.intended,
                trade.currencies.intended
            );
            if (address(0) != trade.currencies.intended)
                tradesRevenueFund.recordDepositTokens(ERC20(trade.currencies.intended), trade.seller.netFees.intended);
        }

        if (0 < trade.seller.netFees.conjugate) {
            clientFund.withdrawFromDepositedBalance(
                trade.seller.wallet,
                tradesRevenueFund,
                trade.seller.netFees.conjugate,
                trade.currencies.conjugate
            );
            if (address(0) != trade.currencies.conjugate)
                tradesRevenueFund.recordDepositTokens(ERC20(trade.currencies.conjugate), trade.seller.netFees.conjugate);
        }
    }

    function settlePaymentFees(Types.Payment payment) private {
        if (0 < payment.sender.netFee) {
            clientFund.withdrawFromDepositedBalance(
                payment.sender.wallet,
                paymentsRevenueFund,
                payment.sender.netFee,
                payment.currency
            );
            if (address(0) != payment.currency)
                paymentsRevenueFund.recordDepositTokens(ERC20(payment.currency), payment.sender.netFee);
        }

        if (0 < payment.recipient.netFee) {
            clientFund.withdrawFromDepositedBalance(
                payment.recipient.wallet,
                paymentsRevenueFund,
                payment.recipient.netFee,
                payment.currency
            );
            if (address(0) != payment.currency)
                paymentsRevenueFund.recordDepositTokens(ERC20(payment.currency), payment.recipient.netFee);
        }
    }

    function addToSeizedWallets(address _address) private {
        if (!seizedWalletsMap[_address]) {
            seizedWallets.push(_address);
            seizedWalletsMap[_address] = true;
        }
    }

    //
    // Modifiers
    // -----------------------------------------------------------------------------------------------------------------
    modifier notNullAddress(address _address) {
        require(_address != address(0));
        _;
    }

    modifier notEqualAddresses(address address1, address address2) {
        require(address1 != address2);
        _;
    }

    modifier onlyOwner() {
        require(isOwner());
        _;
    }

    modifier validatorInitialized() {
        require(validator != address(0));
        _;
    }

    modifier onlySealedTrade(Types.Trade trade) {
        require(validator.isGenuineTradeSeal(trade, owner));
        _;
    }

    modifier onlySealedPayment(Types.Payment payment) {
        require(validator.isGenuinePaymentSeals(payment, owner));
        _;
    }
}