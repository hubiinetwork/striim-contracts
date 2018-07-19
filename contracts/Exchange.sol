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
import {Ownable} from "./Ownable.sol";
import {Types} from "./Types.sol";
import {ERC20} from "./ERC20.sol";
import {Modifiable} from "./Modifiable.sol";
import {Configurable} from "./Configurable.sol";
import {Validatable} from "./Validatable.sol";
import {ClientFundable} from "./ClientFundable.sol";
import {CommunityVotable} from "./CommunityVotable.sol";
import {RevenueFund} from "./RevenueFund.sol";
import {DriipSettlementChallenge} from "./DriipSettlementChallenge.sol";
import {FraudChallenge} from "./FraudChallenge.sol";
import {SelfDestructible} from "./SelfDestructible.sol";

/**
@title Exchange
@notice The orchestrator of driip settlements
*/
contract Exchange is Ownable, Modifiable, Configurable, Validatable, ClientFundable, CommunityVotable, SelfDestructible {
    using SafeMathInt for int256;
    using SafeMathUint for uint256;

    //
    // Variables
    // -----------------------------------------------------------------------------------------------------------------
    uint256 public highestAbsoluteDriipNonce;

    address[] public seizedWallets;
    mapping(address => bool) public seizedWalletsMap;

    FraudChallenge public fraudChallenge;
    DriipSettlementChallenge public driipSettlementChallenge;
    RevenueFund public tradesRevenueFund;
    RevenueFund public paymentsRevenueFund;

    Types.Settlement[] public settlements;
    mapping(address => uint256[]) walletSettlementIndexMap;

    //
    // Events
    // -----------------------------------------------------------------------------------------------------------------
    event SettleDriipAsTradeEvent(Types.Trade trade, address wallet);
    event SettleDriipAsPaymentEvent(Types.Payment payment, address wallet);
    event ChangeFraudChallengeEvent(FraudChallenge oldFraudChallenge, FraudChallenge newFraudChallenge);
    event ChangeDriipSettlementChallengeEvent(DriipSettlementChallenge oldDriipSettlementChallenge, DriipSettlementChallenge newDriipSettlementChallenge);
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
    /// @notice Change the fraud challenge contract
    /// @param newFraudChallenge The (address of) FraudChallenge contract instance
    function changeFraudChallenge(FraudChallenge newFraudChallenge)
    public
    onlyOwner
    notNullAddress(newFraudChallenge)
    {
        FraudChallenge oldFraudChallenge = fraudChallenge;
        fraudChallenge = newFraudChallenge;
        emit ChangeFraudChallengeEvent(oldFraudChallenge, fraudChallenge);
    }

    /// @notice Change the driip settlement challenge contract
    /// @param newDriipSettlementChallenge The (address of) DriipSettlementChallenge contract instance
    function changeDriipSettlementChallenge(DriipSettlementChallenge newDriipSettlementChallenge)
    public
    onlyOwner
    notNullAddress(newDriipSettlementChallenge)
    {
        DriipSettlementChallenge oldDriipSettlementChallenge = driipSettlementChallenge;
        driipSettlementChallenge = newDriipSettlementChallenge;
        emit ChangeDriipSettlementChallengeEvent(oldDriipSettlementChallenge, driipSettlementChallenge);
    }

    /// @notice Change the trades revenue fund contract
    /// @param newTradesRevenueFund The (address of) trades RevenueFund contract instance
    function changeTradesRevenueFund(RevenueFund newTradesRevenueFund)
    public
    onlyOwner
    notNullAddress(newTradesRevenueFund)
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

    /// @notice Update the highest absolute driip nonce property from CommunityVote contract
    function updateHighestAbsoluteDriipNonce() public {
        uint256 _highestAbsoluteDriipNonce = communityVote.getHighestAbsoluteDriipNonce();
        if (_highestAbsoluteDriipNonce > 0) {
            highestAbsoluteDriipNonce = _highestAbsoluteDriipNonce;
        }
    }

    // TODO Remove wallet parameter
    /// @notice Settle driip that is a trade
    /// @param trade The trade to be settled
    function settleDriipAsTrade(Types.Trade trade, address wallet)
    public
    validatorInitialized
    onlySealedTrade(trade)
    {
        require(fraudChallenge != address(0));
        require(communityVote != address(0));
        require(driipSettlementChallenge != address(0));
        require(configuration != address(0));
        require(clientFund != address(0));

        if (msg.sender != owner)
            wallet = msg.sender;

        require(!fraudChallenge.isFraudulentTradeHash(trade.seal.hash));
        require(Types.isTradeParty(trade, wallet));
        require(!communityVote.isDoubleSpenderWallet(wallet));

        (Types.ChallengeResult result, address challenger) = driipSettlementChallenge.driipSettlementChallengeStatus(wallet, trade.nonce);

        if (Types.ChallengeResult.Qualified == result) {

            require((configuration.isOperationalModeNormal() && communityVote.isDataAvailable())
                || (trade.nonce < highestAbsoluteDriipNonce));

            settleTradeTransfers(trade);
            settleTradeFees(trade);
            addSettlementFromTrade(trade);

            if (trade.nonce > highestAbsoluteDriipNonce)
                highestAbsoluteDriipNonce = trade.nonce;

        } else if (Types.ChallengeResult.Disqualified == result) {
            clientFund.seizeDepositedAndSettledBalances(wallet, challenger);
            addToSeizedWallets(wallet);
        }

        emit SettleDriipAsTradeEvent(trade, wallet);
    }

    // TODO Remove wallet parameter
    /// @notice Settle driip that is a payment
    /// @param payment The payment to be settled
    function settleDriipAsPayment(Types.Payment payment, address wallet)
    public
    validatorInitialized
    onlySealedPayment(payment)
    {
        require(fraudChallenge != address(0));
        require(communityVote != address(0));
        require(driipSettlementChallenge != address(0));
        require(configuration != address(0));
        require(clientFund != address(0));

        if (msg.sender != owner)
            wallet = msg.sender;

        require(!fraudChallenge.isFraudulentPaymentExchangeHash(payment.seals.exchange.hash));
        require(Types.isPaymentParty(payment, wallet));
        require(!communityVote.isDoubleSpenderWallet(wallet));

        (Types.ChallengeResult result, address challenger) = driipSettlementChallenge.driipSettlementChallengeStatus(wallet, payment.nonce);

        if (Types.ChallengeResult.Qualified == result) {

            require((configuration.isOperationalModeNormal() && communityVote.isDataAvailable())
                || (payment.nonce < highestAbsoluteDriipNonce));

            settlePaymentTransfers(payment);
            settlePaymentFees(payment);
            addSettlementFromPayment(payment);

            if (payment.nonce > highestAbsoluteDriipNonce)
                highestAbsoluteDriipNonce = payment.nonce;

        }
        else if (Types.ChallengeResult.Disqualified == result) {
            clientFund.seizeDepositedAndSettledBalances(wallet, challenger);
            addToSeizedWallets(wallet);
        }

        emit SettleDriipAsPaymentEvent(payment, wallet);
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
        if (0 < payment.transfers.net) {// Transfer from sender to recipient
            clientFund.transferFromDepositedToSettledBalance(
                payment.sender.wallet,
                payment.recipient.wallet,
                payment.transfers.net,
                payment.currency
            );

        } else if (0 > payment.transfers.net) {// Transfer from recipient to sender
            clientFund.transferFromDepositedToSettledBalance(
                payment.recipient.wallet,
                payment.sender.wallet,
                payment.transfers.net.abs(),
                payment.currency
            );
        }
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

    function addSettlementFromTrade(Types.Trade trade) private {
        settlements.push(
            Types.Settlement(trade.nonce, Types.DriipType.Trade, [trade.buyer.wallet, trade.seller.wallet])
        );
        walletSettlementIndexMap[trade.buyer.wallet].push(settlements.length - 1);
        walletSettlementIndexMap[trade.seller.wallet].push(settlements.length - 1);
    }

    function addSettlementFromPayment(Types.Payment payment) private {
        settlements.push(
            Types.Settlement(payment.nonce, Types.DriipType.Payment, [payment.sender.wallet, payment.recipient.wallet])
        );
        walletSettlementIndexMap[payment.sender.wallet].push(settlements.length - 1);
        walletSettlementIndexMap[payment.recipient.wallet].push(settlements.length - 1);
    }

    function addToSeizedWallets(address _address) private {
        if (!seizedWalletsMap[_address]) {
            seizedWallets.push(_address);
            seizedWalletsMap[_address] = true;
        }
    }
}