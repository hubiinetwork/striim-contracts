/*
 * Hubii Nahmii
 *
 * Compliant with the Hubii Nahmii specification v0.12.
 *
 * Copyright (C) 2017-2018 Hubii AS
 */

pragma solidity ^0.4.24;

import {MonetaryTypes} from "./MonetaryTypes.sol";

/**
 * @title     NahmiiTypes
 * @dev       Data types of order, trade, payment and more
 */
library NahmiiTypes {
    //
    // Enums
    // -----------------------------------------------------------------------------------------------------------------
    enum LiquidityRole {Maker, Taker}
    enum CurrencyRole {Intended, Conjugate}
    enum DriipType {Trade, Payment}
    enum Intention {Buy, Sell}
    enum TradePartyRole {Buyer, Seller}
    enum PaymentPartyRole {Sender, Recipient}
    enum ChallengePhase {Dispute, Closed}

    //
    // Structures
    // -----------------------------------------------------------------------------------------------------------------
    struct IntendedConjugateCurrency {
        MonetaryTypes.Currency intended;
        MonetaryTypes.Currency conjugate;
    }

    struct SingleFigureTotalFigures {
        MonetaryTypes.Figure single;
        MonetaryTypes.Figure[] total;
    }

    struct TotalFigures {
        MonetaryTypes.Figure[] total;
    }

    struct CurrentPreviousInt256 {
        int256 current;
        int256 previous;
    }

    struct SingleTotalInt256 {
        int256 single;
        int256 total;
    }

    struct IntendedConjugateCurrentPreviousInt256 {
        CurrentPreviousInt256 intended;
        CurrentPreviousInt256 conjugate;
    }

    struct IntendedConjugateSingleTotalInt256 {
        SingleTotalInt256 intended;
        SingleTotalInt256 conjugate;
    }

    struct WalletExchangeHashes {
        bytes32 wallet;
        bytes32 exchange;
    }

    struct TradeOrder {
        int256 amount;
        WalletExchangeHashes hashes;
        CurrentPreviousInt256 residuals;
    }

    struct Signature {
        bytes32 r;
        bytes32 s;
        uint8 v;
    }

    struct Seal {
        bytes32 hash;
        Signature signature;
    }

    struct WalletExchangeSeal {
        Seal wallet;
        Seal exchange;
    }

    struct TradeParty {
        uint256 nonce;
        address wallet;

        uint256 rollingVolume;

        LiquidityRole liquidityRole;

        TradeOrder order;

        IntendedConjugateCurrentPreviousInt256 balances;

        SingleFigureTotalFigures fees;
    }

    struct Trade {
        uint256 nonce;

        int256 amount;
        IntendedConjugateCurrency currencies;
        int256 rate;

        TradeParty buyer;
        TradeParty seller;

        // Positive intended transfer is always in direction from seller to buyer
        // Positive conjugate transfer is always in direction from buyer to seller
        IntendedConjugateSingleTotalInt256 transfers;

        Seal seal;
        uint256 blockNumber;
    }

    struct PaymentSenderParty {
        uint256 nonce;
        address wallet;

        CurrentPreviousInt256 balances;

        SingleFigureTotalFigures fees;
    }

    struct PaymentRecipientParty {
        uint256 nonce;
        address wallet;

        CurrentPreviousInt256 balances;

        TotalFigures fees;
    }

    struct Payment {
        uint256 nonce;

        int256 amount;
        MonetaryTypes.Currency currency;

        PaymentSenderParty sender;
        PaymentRecipientParty recipient;

        // Positive transfer is always in direction from sender to recipient
        SingleTotalInt256 transfers;

        WalletExchangeSeal seals;
        uint256 blockNumber;
    }

    struct OrderPlacement {
        Intention intention;

        int256 amount;
        IntendedConjugateCurrency currencies;
        int256 rate;

        CurrentPreviousInt256 residuals;
    }

    struct Order {
        uint256 nonce;
        address wallet;

        OrderPlacement placement;

        WalletExchangeSeal seals;
        uint256 blockNumber;
    }

    struct SettlementParty {
        uint256 nonce;
        address wallet;
        bool done;
    }

    struct Settlement {
        uint256 nonce;
        DriipType driipType;
        SettlementParty origin;
        SettlementParty target;
    }
}