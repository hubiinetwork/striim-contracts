/*
 * Hubii Nahmii
 *
 * Compliant with the Hubii Nahmii specification v0.12.
 *
 * Copyright (C) 2017-2018 Hubii AS
 */

pragma solidity ^0.4.25;
pragma experimental ABIEncoderV2;

import {Ownable} from "./Ownable.sol";
import {Servable} from "./Servable.sol";
import {CommunityVotable} from "./CommunityVotable.sol";
import {RevenueFund} from "./RevenueFund.sol";
import {PartnerFund} from "./PartnerFund.sol";
import {Beneficiary} from "./Beneficiary.sol";
import {SafeMathIntLib} from "./SafeMathIntLib.sol";
import {SafeMathUintLib} from "./SafeMathUintLib.sol";
import {MonetaryTypesLib} from "./MonetaryTypesLib.sol";
import {NahmiiTypesLib} from "./NahmiiTypesLib.sol";
import {DriipSettlementTypesLib} from "./DriipSettlementTypesLib.sol";

/**
 * @title DriipSettlementState
 * @notice Where driip settlement state is managed
 */
contract DriipSettlementState is Ownable, Servable, CommunityVotable {
    using SafeMathIntLib for int256;
    using SafeMathUintLib for uint256;

    //
    // Constants
    // -----------------------------------------------------------------------------------------------------------------
    string constant public INIT_SETTLEMENT_ACTION = "init_settlement";
    string constant public SET_SETTLEMENT_ROLE_DONE_ACTION = "set_settlement_role_done";
    string constant public SET_MAX_NONCE_ACTION = "set_max_nonce";
    string constant public SET_FEE_TOTAL_ACTION = "set_fee_total";

    //
    // Variables
    // -----------------------------------------------------------------------------------------------------------------
    uint256 public maxDriipNonce;

    DriipSettlementTypesLib.Settlement[] public settlements;
    mapping(address => uint256[]) public walletSettlementIndices;
    mapping(address => mapping(uint256 => uint256)) public walletNonceSettlementIndex;
    mapping(address => mapping(address => mapping(uint256 => uint256))) public walletCurrencyMaxNonce;

    mapping(address => mapping(address => mapping(address => mapping(address => mapping(uint256 => MonetaryTypesLib.NoncedAmount))))) public totalFeesMap;

    bool public upgradesFrozen;

    //
    // Events
    // -----------------------------------------------------------------------------------------------------------------
    event InitSettlementEvent(DriipSettlementTypesLib.Settlement settlement);
    event CompleteSettlementPartyEvent(address wallet, uint256 nonce, DriipSettlementTypesLib.SettlementRole settlementRole,
        bool done, uint256 doneBlockNumber);
    event SetMaxNonceByWalletAndCurrencyEvent(address wallet, MonetaryTypesLib.Currency currency,
        uint256 maxNonce);
    event SetMaxDriipNonceEvent(uint256 maxDriipNonce);
    event UpdateMaxDriipNonceFromCommunityVoteEvent(uint256 maxDriipNonce);
    event SetTotalFeeEvent(address wallet, Beneficiary beneficiary, address destination,
        MonetaryTypesLib.Currency currency, MonetaryTypesLib.NoncedAmount totalFee);
    event FreezeUpgradesEvent();
    event UpgradeSettlementEvent(DriipSettlementTypesLib.Settlement settlement);

    //
    // Constructor
    // -----------------------------------------------------------------------------------------------------------------
    constructor(address deployer) Ownable(deployer) public {
    }

    //
    // Functions
    // -----------------------------------------------------------------------------------------------------------------
    /// @notice Get the count of settlements
    function settlementsCount()
    public
    view
    returns (uint256)
    {
        return settlements.length;
    }

    /// @notice Get the count of settlements for given wallet
    /// @param wallet The address for which to return settlement count
    /// @return count of settlements for the provided wallet
    function settlementsCountByWallet(address wallet)
    public
    view
    returns (uint256)
    {
        return walletSettlementIndices[wallet].length;
    }

    /// @notice Get settlement of given wallet and index
    /// @param wallet The address for which to return settlement
    /// @param index The wallet's settlement index
    /// @return settlement for the provided wallet and index
    function settlementByWalletAndIndex(address wallet, uint256 index)
    public
    view
    returns (DriipSettlementTypesLib.Settlement)
    {
        require(walletSettlementIndices[wallet].length > index);
        return settlements[walletSettlementIndices[wallet][index] - 1];
    }

    /// @notice Get settlement of given wallet and wallet nonce
    /// @param wallet The address for which to return settlement
    /// @param nonce The wallet's nonce
    /// @return settlement for the provided wallet and index
    function settlementByWalletAndNonce(address wallet, uint256 nonce)
    public
    view
    returns (DriipSettlementTypesLib.Settlement)
    {
        require(0 < walletNonceSettlementIndex[wallet][nonce]);
        return settlements[walletNonceSettlementIndex[wallet][nonce] - 1];
    }

    /// @notice Initialize settlement, i.e. create one if no such settlement exists
    /// for the double pair of wallets and nonces
    /// @param settledKind The kind of driip of the settlement
    /// @param settledHash The hash of driip of the settlement
    /// @param originWallet The address of the origin wallet
    /// @param originNonce The wallet nonce of the origin wallet
    /// @param targetWallet The address of the target wallet
    /// @param targetNonce The wallet nonce of the target wallet
    function initSettlement(string settledKind, bytes32 settledHash, address originWallet,
        uint256 originNonce, address targetWallet, uint256 targetNonce)
    public
    onlyEnabledServiceAction(INIT_SETTLEMENT_ACTION)
    {
        if (
            0 == walletNonceSettlementIndex[originWallet][originNonce] &&
            0 == walletNonceSettlementIndex[targetWallet][targetNonce]
        ) {
            // Create new settlement
            settlements.length++;

            // Get the 0-based index
            uint256 index = settlements.length - 1;

            // Update settlement
            settlements[index].settledKind = settledKind;
            settlements[index].settledHash = settledHash;
            settlements[index].origin.nonce = originNonce;
            settlements[index].origin.wallet = originWallet;
            settlements[index].target.nonce = targetNonce;
            settlements[index].target.wallet = targetWallet;

            // Emit event
            emit InitSettlementEvent(settlements[index]);

            // Store 1-based index value
            index++;
            walletSettlementIndices[originWallet].push(index);
            walletSettlementIndices[targetWallet].push(index);
            walletNonceSettlementIndex[originWallet][originNonce] = index;
            walletNonceSettlementIndex[targetWallet][targetNonce] = index;
        }
    }

    /// @notice Set the done of the given settlement role in the given settlement
    /// @param wallet The address of the concerned wallet
    /// @param nonce The nonce of the concerned wallet
    /// @param settlementRole The settlement role
    /// @param done The done flag
    function completeSettlementParty(address wallet, uint256 nonce,
        DriipSettlementTypesLib.SettlementRole settlementRole, bool done)
    public
    onlyEnabledServiceAction(SET_SETTLEMENT_ROLE_DONE_ACTION)
    {
        // Get the 1-based index of the settlement
        uint256 index = walletNonceSettlementIndex[wallet][nonce];

        // Require the existence of settlement
        require(0 != index);

        // Get the settlement party
        DriipSettlementTypesLib.SettlementParty storage party =
        DriipSettlementTypesLib.SettlementRole.Origin == settlementRole ?
        settlements[index - 1].origin :
        settlements[index - 1].target;

        // Update party done and done block number properties
        party.done = done;
        party.doneBlockNumber = done ? block.number : 0;

        // Emit event
        emit CompleteSettlementPartyEvent(wallet, nonce, settlementRole, done, party.doneBlockNumber);
    }

    /// @notice Gauge whether the settlement is done wrt the given wallet and nonce
    /// @param wallet The address of the concerned wallet
    /// @param nonce The nonce of the concerned wallet
    /// @return True if settlement is done for role, else false
    function isSettlementPartyDone(address wallet, uint256 nonce)
    public
    view
    returns (bool)
    {
        // Get the 1-based index of the settlement
        uint256 index = walletNonceSettlementIndex[wallet][nonce];

        // Return false if settlement does not exist
        if (0 == index)
            return false;

        // Return done
        return (
        wallet == settlements[index - 1].origin.wallet ?
        settlements[index - 1].origin.done :
        settlements[index - 1].target.done
        );
    }

    /// @notice Gauge whether the settlement is done wrt the given wallet, nonce
    /// and settlement role
    /// @param wallet The address of the concerned wallet
    /// @param nonce The nonce of the concerned wallet
    /// @param settlementRole The settlement role
    /// @return True if settlement is done for role, else false
    function isSettlementPartyDone(address wallet, uint256 nonce,
        DriipSettlementTypesLib.SettlementRole settlementRole)
    public
    view
    returns (bool)
    {
        // Get the 1-based index of the settlement
        uint256 index = walletNonceSettlementIndex[wallet][nonce];

        // Return false if settlement does not exist
        if (0 == index)
            return false;

        // Get the settlement party
        DriipSettlementTypesLib.SettlementParty storage settlementParty =
        DriipSettlementTypesLib.SettlementRole.Origin == settlementRole ?
        settlements[index - 1].origin : settlements[index - 1].target;

        // Require that wallet is party of the right role
        require(wallet == settlementParty.wallet);

        // Return done
        return settlementParty.done;
    }

    /// @notice Get the done block number of the settlement party with the given wallet and nonce
    /// @param wallet The address of the concerned wallet
    /// @param nonce The nonce of the concerned wallet
    /// @return The done block number of the settlement wrt the given settlement role
    function settlementPartyDoneBlockNumber(address wallet, uint256 nonce)
    public
    view
    returns (uint256)
    {
        // Get the 1-based index of the settlement
        uint256 index = walletNonceSettlementIndex[wallet][nonce];

        // Require the existence of settlement
        require(0 != index);

        // Return done block number
        return (
        wallet == settlements[index - 1].origin.wallet ?
        settlements[index - 1].origin.doneBlockNumber :
        settlements[index - 1].target.doneBlockNumber
        );
    }

    /// @notice Get the done block number of the settlement party with the given wallet, nonce and settlement role
    /// @param wallet The address of the concerned wallet
    /// @param nonce The nonce of the concerned wallet
    /// @param settlementRole The settlement role
    /// @return The done block number of the settlement wrt the given settlement role
    function settlementPartyDoneBlockNumber(address wallet, uint256 nonce,
        DriipSettlementTypesLib.SettlementRole settlementRole)
    public
    view
    returns (uint256)
    {
        // Get the 1-based index of the settlement
        uint256 index = walletNonceSettlementIndex[wallet][nonce];

        // Require the existence of settlement
        require(0 != index);

        // Get the settlement party
        DriipSettlementTypesLib.SettlementParty storage settlementParty =
        DriipSettlementTypesLib.SettlementRole.Origin == settlementRole ?
        settlements[index - 1].origin : settlements[index - 1].target;

        // Require that wallet is party of the right role
        require(wallet == settlementParty.wallet);

        // Return done block number
        return settlementParty.doneBlockNumber;
    }

    /// @notice Set the max (driip) nonce
    /// @param _maxDriipNonce The max nonce
    function setMaxDriipNonce(uint256 _maxDriipNonce)
    public
    onlyEnabledServiceAction(SET_MAX_NONCE_ACTION)
    {
        maxDriipNonce = _maxDriipNonce;

        // Emit event
        emit SetMaxDriipNonceEvent(maxDriipNonce);
    }

    /// @notice Update the max driip nonce property from CommunityVote contract
    function updateMaxDriipNonceFromCommunityVote()
    public
    {
        uint256 _maxDriipNonce = communityVote.getMaxDriipNonce();
        if (0 == _maxDriipNonce)
            return;

        maxDriipNonce = _maxDriipNonce;

        // Emit event
        emit UpdateMaxDriipNonceFromCommunityVoteEvent(maxDriipNonce);
    }

    /// @notice Get the max nonce of the given wallet and currency
    /// @param wallet The address of the concerned wallet
    /// @param currency The concerned currency
    /// @return The max nonce
    function maxNonceByWalletAndCurrency(address wallet, MonetaryTypesLib.Currency currency)
    public
    view
    returns (uint256)
    {
        return walletCurrencyMaxNonce[wallet][currency.ct][currency.id];
    }

    /// @notice Set the max nonce of the given wallet and currency
    /// @param wallet The address of the concerned wallet
    /// @param currency The concerned currency
    /// @param maxNonce The max nonce
    function setMaxNonceByWalletAndCurrency(address wallet, MonetaryTypesLib.Currency currency,
        uint256 maxNonce)
    public
    onlyEnabledServiceAction(SET_MAX_NONCE_ACTION)
    {
        // Update max nonce value
        walletCurrencyMaxNonce[wallet][currency.ct][currency.id] = maxNonce;

        // Emit event
        emit SetMaxNonceByWalletAndCurrencyEvent(wallet, currency, maxNonce);
    }

    /// @notice Get the total fee payed by the given wallet to the given beneficiary and destination
    /// in the given currency
    /// @param wallet The address of the concerned wallet
    /// @param beneficiary The concerned beneficiary
    /// @param destination The concerned destination
    /// @param currency The concerned currency
    /// @return The total fee
    function totalFee(address wallet, Beneficiary beneficiary, address destination,
        MonetaryTypesLib.Currency currency)
    public
    view
    returns (MonetaryTypesLib.NoncedAmount)
    {
        return totalFeesMap[wallet][address(beneficiary)][destination][currency.ct][currency.id];
    }

    /// @notice Set the total fee payed by the given wallet to the given beneficiary and destination
    /// in the given currency
    /// @param wallet The address of the concerned wallet
    /// @param beneficiary The concerned beneficiary
    /// @param destination The concerned destination
    /// @param _totalFee The total fee
    function setTotalFee(address wallet, Beneficiary beneficiary, address destination,
        MonetaryTypesLib.Currency currency, MonetaryTypesLib.NoncedAmount _totalFee)
    public
    onlyEnabledServiceAction(SET_FEE_TOTAL_ACTION)
    {
        // Update total fees value
        totalFeesMap[wallet][address(beneficiary)][destination][currency.ct][currency.id] = _totalFee;

        // Emit event
        emit SetTotalFeeEvent(wallet, beneficiary, destination, currency, _totalFee);
    }

    /// @notice Freeze all future settlement upgrades
    /// @dev This operation can not be undone
    function freezeUpgrades()
    public
    onlyDeployer
    {
        // Freeze upgrade
        upgradesFrozen = true;

        // Emit event
        emit FreezeUpgradesEvent();
    }

    /// @notice Upgrade settlement from other driip settlement state instance
    function upgradeSettlement(string settledKind, bytes32 settledHash,
        address originWallet, uint256 originNonce, bool originDone, uint256 originDoneBlockNumber,
        address targetWallet, uint256 targetNonce, bool targetDone, uint256 targetDoneBlockNumber)
    public
    onlyDeployer
    {
        // Require that upgrades have not been frozen
        require(!upgradesFrozen);

        // Require that settlement has not been initialized/upgraded already
        require(
            0 == walletNonceSettlementIndex[originWallet][originNonce] &&
            0 == walletNonceSettlementIndex[targetWallet][targetNonce]
        );

        // Create new settlement
        settlements.length++;

        // Get the 0-based index
        uint256 index = settlements.length - 1;

        // Update settlement
        settlements[index].settledKind = settledKind;
        settlements[index].settledHash = settledHash;
        settlements[index].origin.nonce = originNonce;
        settlements[index].origin.wallet = originWallet;
        settlements[index].origin.done = originDone;
        settlements[index].origin.doneBlockNumber = originDoneBlockNumber;
        settlements[index].target.nonce = targetNonce;
        settlements[index].target.wallet = targetWallet;
        settlements[index].target.done = targetDone;
        settlements[index].target.doneBlockNumber = targetDoneBlockNumber;

        // Emit event
        emit UpgradeSettlementEvent(settlements[index]);

        // Store 1-based index value
        index++;
        walletSettlementIndices[originWallet].push(index);
        walletSettlementIndices[targetWallet].push(index);
        walletNonceSettlementIndex[originWallet][originNonce] = index;
        walletNonceSettlementIndex[targetWallet][targetNonce] = index;
    }
}