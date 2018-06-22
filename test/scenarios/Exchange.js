const chai = require('chai');
const sinonChai = require("sinon-chai");
const chaiAsPromised = require("chai-as-promised");
const {Wallet, Contract, utils} = require('ethers');
const mocks = require('../mocks');
const cryptography = require('omphalos-commons').util.cryptography;
const MockedConfiguration = artifacts.require("MockedConfiguration");
const MockedClientFund = artifacts.require("MockedClientFund");
const MockedReserveFund = artifacts.require("MockedReserveFund");
const MockedRevenueFund = artifacts.require("MockedRevenueFund");
const MockedDriipSettlementChallenge = artifacts.require("MockedDriipSettlementChallenge");
const MockedCommunityVote = artifacts.require("MockedCommunityVote");
const MockedValidator = artifacts.require("MockedValidator");

chai.use(sinonChai);
chai.use(chaiAsPromised);
chai.should();

let provider;

module.exports = (glob) => {
    describe('Exchange', () => {
        let web3Exchange, ethersExchange;
        let web3Configuration, ethersConfiguration;
        let web3ClientFund, ethersClientFund;
        let web3ReserveFund, ethersReserveFund;
        let web3RevenueFund, ethersRevenueFund;
        let web3CommunityVote, ethersCommunityVote;
        let web3DriipSettlementChallenge, ethersDriipSettlementChallenge;
        let web3Validator, ethersValidator;
        let blockNumber0, blockNumber10, blockNumber20;

        before(async () => {
            provider = glob.signer_owner.provider;

            web3Exchange = glob.web3Exchange;
            ethersExchange = glob.ethersIoExchange;

            web3Configuration = await MockedConfiguration.new(glob.owner);
            ethersConfiguration = new Contract(web3Configuration.address, MockedConfiguration.abi, glob.signer_owner);
            web3ClientFund = await MockedClientFund.new(/*glob.owner*/);
            ethersClientFund = new Contract(web3ClientFund.address, MockedClientFund.abi, glob.signer_owner);
            web3ReserveFund = await MockedReserveFund.new(/*glob.owner*/);
            ethersReserveFund = new Contract(web3ReserveFund.address, MockedReserveFund.abi, glob.signer_owner);
            web3RevenueFund = await MockedRevenueFund.new(/*glob.owner*/);
            ethersRevenueFund = new Contract(web3RevenueFund.address, MockedRevenueFund.abi, glob.signer_owner);
            web3CommunityVote = await MockedCommunityVote.new(/*glob.owner*/);
            ethersCommunityVote = new Contract(web3CommunityVote.address, MockedCommunityVote.abi, glob.signer_owner);
            web3DriipSettlementChallenge = await MockedDriipSettlementChallenge.new(/*glob.owner*/);
            ethersDriipSettlementChallenge = new Contract(web3DriipSettlementChallenge.address, MockedDriipSettlementChallenge.abi, glob.signer_owner);
            web3Validator = await MockedValidator.new(glob.owner);
            ethersValidator = new Contract(web3Validator.address, MockedValidator.abi, glob.signer_owner);

            await ethersExchange.changeConfiguration(web3Configuration.address);
            await ethersExchange.changeClientFund(web3ClientFund.address);
            await ethersExchange.changeTradesReserveFund(web3ReserveFund.address);
            await ethersExchange.changePaymentsReserveFund(web3ReserveFund.address);
            await ethersExchange.changeTradesRevenueFund(web3RevenueFund.address);
            await ethersExchange.changePaymentsRevenueFund(web3RevenueFund.address);
            await ethersExchange.changeCommunityVote(web3CommunityVote.address);
            await ethersExchange.changeDriipSettlementChallenge(web3DriipSettlementChallenge.address);
            await ethersExchange.changeValidator(web3Validator.address);
        });

        beforeEach(async () => {
            blockNumber0 = await provider.getBlockNumber();
            blockNumber10 = blockNumber0 + 10;
            blockNumber20 = blockNumber0 + 20;
        });

        describe('constructor', () => {
            it('should initialize fields', async () => {
                const owner = await web3Exchange.owner.call();
                owner.should.equal(glob.owner);
            });
        });

        describe('changeOwner()', () => {
            describe('if called with (current) owner as sender', () => {
                afterEach(async () => {
                    await web3Exchange.changeOwner(glob.owner, {from: glob.user_a});
                });

                it('should set new value and emit event', async () => {
                    const result = await web3Exchange.changeOwner(glob.user_a);
                    result.logs.should.be.an('array').and.have.lengthOf(1);
                    result.logs[0].event.should.equal('ChangeOwnerEvent');
                    const owner = await web3Exchange.owner.call();
                    owner.should.equal(glob.user_a);
                });
            });

            describe('if called with sender that is not (current) owner', () => {
                it('should revert', async () => {
                    web3Exchange.changeOwner(glob.user_a, {from: glob.user_a}).should.be.rejected;
                });
            });
        });

        describe('configuration()', () => {
            it('should equal value initialized', async () => {
                const configuration = await ethersExchange.configuration();
                configuration.should.equal(utils.getAddress(ethersConfiguration.address));
            });
        });

        describe('changeConfiguration()', () => {
            let address;

            before(() => {
                address = Wallet.createRandom().address;
            });

            describe('if called with owner as sender', () => {
                let configuration;

                beforeEach(async () => {
                    configuration = await web3Exchange.configuration.call();
                });

                afterEach(async () => {
                    await web3Exchange.changeConfiguration(configuration);
                });

                it('should set new value and emit event', async () => {
                    const result = await web3Exchange.changeConfiguration(address);
                    result.logs.should.be.an('array').and.have.lengthOf(1);
                    result.logs[0].event.should.equal('ChangeConfigurationEvent');
                    const configuration = await web3Exchange.configuration();
                    utils.getAddress(configuration).should.equal(address);
                });
            });

            describe('if called with sender that is not owner', () => {
                it('should revert', async () => {
                    web3Exchange.changeConfiguration(address, {from: glob.user_a}).should.be.rejected;
                });
            });
        });

        describe('validator()', () => {
            it('should equal value initialized', async () => {
                const validator = await ethersExchange.validator();
                validator.should.equal(utils.getAddress(ethersValidator.address));
            });
        });

        describe('changeValidator()', () => {
            let address;

            before(() => {
                address = Wallet.createRandom().address;
            });

            describe('if called with owner as sender', () => {
                let validator;

                beforeEach(async () => {
                    validator = await web3Exchange.validator.call();
                });

                afterEach(async () => {
                    await web3Exchange.changeValidator(validator);
                });

                it('should set new value and emit event', async () => {
                    const result = await web3Exchange.changeValidator(address);
                    result.logs.should.be.an('array').and.have.lengthOf(1);
                    result.logs[0].event.should.equal('ChangeValidatorEvent');
                    const validator = await web3Exchange.validator();
                    utils.getAddress(validator).should.equal(address);
                });
            });

            describe('if called with sender that is not owner', () => {
                it('should revert', async () => {
                    web3Exchange.changeValidator(address, {from: glob.user_a}).should.be.rejected;
                });
            });
        });

        describe('driipSettlementChallenge()', () => {
            it('should equal value initialized', async () => {
                const driipSettlementChallenge = await ethersExchange.driipSettlementChallenge();
                driipSettlementChallenge.should.equal(utils.getAddress(ethersDriipSettlementChallenge.address));
            });
        });

        describe('changeDriipSettlementChallenge()', () => {
            let address;

            before(() => {
                address = Wallet.createRandom().address;
            });

            describe('if called with owner as sender', () => {
                let driipSettlementChallenge;

                beforeEach(async () => {
                    driipSettlementChallenge = await web3Exchange.driipSettlementChallenge.call();
                });

                afterEach(async () => {
                    await web3Exchange.changeDriipSettlementChallenge(driipSettlementChallenge);
                });

                it('should set new value and emit event', async () => {
                    const result = await web3Exchange.changeDriipSettlementChallenge(address);
                    result.logs.should.be.an('array').and.have.lengthOf(1);
                    result.logs[0].event.should.equal('ChangeDriipSettlementChallengeEvent');
                    const driipSettlementChallenge = await web3Exchange.driipSettlementChallenge();
                    utils.getAddress(driipSettlementChallenge).should.equal(address);
                });
            });

            describe('if called with sender that is not owner', () => {
                it('should revert', async () => {
                    web3Exchange.changeDriipSettlementChallenge(address, {from: glob.user_a}).should.be.rejected;
                });
            });
        });

        describe('changeClientFund()', () => {
            let address;

            before(() => {
                address = Wallet.createRandom().address;
            });

            describe('if called with owner as sender', () => {
                let clientFund;

                beforeEach(async () => {
                    clientFund = await web3Exchange.clientFund.call();
                });

                afterEach(async () => {
                    await web3Exchange.changeClientFund(clientFund);
                });

                it('should set new value and emit event', async () => {
                    const result = await web3Exchange.changeClientFund(address);
                    result.logs.should.be.an('array').and.have.lengthOf(1);
                    result.logs[0].event.should.equal('ChangeClientFundEvent');
                    const clientFund = await web3Exchange.clientFund();
                    utils.getAddress(clientFund).should.equal(address);
                });
            });

            describe('if called with sender that is not owner', () => {
                it('should revert', async () => {
                    web3Exchange.changeClientFund(address, {from: glob.user_a}).should.be.rejected;
                });
            });
        });

        describe('changeTradesReserveFund()', () => {
            let address;

            before(() => {
                address = Wallet.createRandom().address;
            });

            describe('if called with owner as sender', () => {
                let tradesReserveFund;

                beforeEach(async () => {
                    tradesReserveFund = await web3Exchange.tradesReserveFund.call();
                });

                afterEach(async () => {
                    await web3Exchange.changeTradesReserveFund(tradesReserveFund);
                });

                it('should set new value and emit event', async () => {
                    const result = await web3Exchange.changeTradesReserveFund(address);
                    result.logs.should.be.an('array').and.have.lengthOf(1);
                    result.logs[0].event.should.equal('ChangeTradesReserveFundEvent');
                    const reserveFund = await web3Exchange.tradesReserveFund();
                    utils.getAddress(reserveFund).should.equal(address);
                });
            });

            describe('if called with sender that is not owner', () => {
                it('should revert', async () => {
                    web3Exchange.changeTradesReserveFund(address, {from: glob.user_a}).should.be.rejected;
                });
            });
        });

        describe('changePaymentsReserveFund()', () => {
            let address;

            before(() => {
                address = Wallet.createRandom().address;
            });

            describe('if called with owner as sender', () => {
                let paymentsReserveFund;

                beforeEach(async () => {
                    paymentsReserveFund = await web3Exchange.paymentsReserveFund.call();
                });

                afterEach(async () => {
                    await web3Exchange.changePaymentsReserveFund(paymentsReserveFund);
                });

                it('should set new value and emit event', async () => {
                    const result = await web3Exchange.changePaymentsReserveFund(address);
                    result.logs.should.be.an('array').and.have.lengthOf(1);
                    result.logs[0].event.should.equal('ChangePaymentsReserveFundEvent');
                    const reserveFund = await web3Exchange.paymentsReserveFund();
                    utils.getAddress(reserveFund).should.equal(address);
                });
            });

            describe('if called with sender that is not owner', () => {
                it('should revert', async () => {
                    web3Exchange.changePaymentsReserveFund(address, {from: glob.user_a}).should.be.rejected;
                });
            });
        });

        describe('changeTradesRevenueFund()', () => {
            let address;

            before(() => {
                address = Wallet.createRandom().address;
            });

            describe('if called with owner as sender', () => {
                let tradesRevenueFund;

                beforeEach(async () => {
                    tradesRevenueFund = await web3Exchange.tradesRevenueFund.call();
                });

                afterEach(async () => {
                    await web3Exchange.changeTradesRevenueFund(tradesRevenueFund);
                });

                it('should set new value and emit event', async () => {
                    const result = await web3Exchange.changeTradesRevenueFund(address);
                    result.logs.should.be.an('array').and.have.lengthOf(1);
                    result.logs[0].event.should.equal('ChangeTradesRevenueFundEvent');
                    const revenueFund = await web3Exchange.tradesRevenueFund();
                    utils.getAddress(revenueFund).should.equal(address);
                });
            });

            describe('if called with sender that is not owner', () => {
                it('should revert', async () => {
                    web3Exchange.changeTradesRevenueFund(address, {from: glob.user_a}).should.be.rejected;
                });
            });
        });

        describe('changePaymentsRevenueFund()', () => {
            let address;

            before(() => {
                address = Wallet.createRandom().address;
            });

            describe('if called with owner as sender', () => {
                let paymentsRevenueFund;

                beforeEach(async () => {
                    paymentsRevenueFund = await web3Exchange.paymentsRevenueFund.call();
                });

                afterEach(async () => {
                    await web3Exchange.changePaymentsRevenueFund(paymentsRevenueFund);
                });

                it('should set new value and emit event', async () => {
                    const result = await web3Exchange.changePaymentsRevenueFund(address);
                    result.logs.should.be.an('array').and.have.lengthOf(1);
                    result.logs[0].event.should.equal('ChangePaymentsRevenueFundEvent');
                    const revenueFund = await web3Exchange.paymentsRevenueFund();
                    utils.getAddress(revenueFund).should.equal(address);
                });
            });

            describe('if called with sender that is not owner', () => {
                it('should revert', async () => {
                    web3Exchange.changePaymentsRevenueFund(address, {from: glob.user_a}).should.be.rejected;
                });
            });
        });

        describe('communityVoteUpdateDisabled()', () => {
            it('should return value initialized', async () => {
                const result = await ethersExchange.communityVoteUpdateDisabled();
                result.should.be.false;
            });
        });

        describe('changeCommunityVote()', () => {
            let address;

            before(() => {
                address = Wallet.createRandom().address;
            });

            describe('if called with owner as sender', () => {
                let communityVote;

                beforeEach(async () => {
                    communityVote = await web3Exchange.communityVote.call();
                });

                afterEach(async () => {
                    await web3Exchange.changeCommunityVote(communityVote);
                });

                it('should set new value and emit event', async () => {
                    const result = await web3Exchange.changeCommunityVote(address);
                    result.logs.should.be.an('array').and.have.lengthOf(1);
                    result.logs[0].event.should.equal('ChangeCommunityVoteEvent');
                    const communityVote = await web3Exchange.communityVote();
                    utils.getAddress(communityVote).should.equal(address);
                });
            });

            describe('if called with sender that is not owner', () => {
                it('should revert', async () => {
                    web3Exchange.changeCommunityVote(address, {from: glob.user_a}).should.be.rejected;
                });
            });
        });

        describe('disableUpdateOfCommunityVote()', () => {
            describe('if called with sender that is not owner', () => {
                it('should revert', async () => {
                    web3Exchange.disableUpdateOfCommunityVote({from: glob.user_a}).should.be.rejected;
                });
            });

            describe('if called with owner as sender', () => {
                let address;

                before(async () => {
                    address = Wallet.createRandom().address;
                });

                it('should disable changing community vote', async () => {
                    await web3Exchange.disableUpdateOfCommunityVote();
                    web3Exchange.changeCommunityVote(address).should.be.rejected;
                });
            });
        });

        describe('isSeizedWallet()', () => {
            it('should equal value initialized', async () => {
                const result = await ethersExchange.isSeizedWallet(glob.user_a);
                result.should.be.false;
            });
        });

        describe('seizedWalletsCount()', () => {
            it('should equal value initialized', async () => {
                const count = await ethersExchange.seizedWalletsCount();
                count.toNumber().should.equal(0);
            })
        });

        describe('seizedWallets()', () => {
            it('should equal value initialized', async () => {
                ethersExchange.seizedWallets(0).should.be.rejected;
            })
        });

        describe('settlementsCount()', () => {
            it('should equal value initialized', async () => {
                const count = await ethersExchange.seizedWalletsCount();
                count.toNumber().should.equal(0);
            })
        });

        describe('walletSettlementsCount()', () => {
            it('should equal value initialized', async () => {
                const address = Wallet.createRandom().address;
                const count = await ethersExchange.walletSettlementsCount(address);
                count.toNumber().should.equal(0);
            })
        });

        describe('walletSettlement', () => {
            describe('if index is out of bounds', () => {
                it('should revert', async () => {
                    const address = Wallet.createRandom().address;
                    ethersExchange.walletSettlement(address, 0).should.be.rejected;
                })
            });
        });

        describe('highestAbsoluteDriipNonce()', () => {
            it('should equal value initialized', async () => {
                const highestAbsoluteDriipNonce = await ethersExchange.highestAbsoluteDriipNonce();
                highestAbsoluteDriipNonce.eq(utils.bigNumberify(0)).should.be.true;
            });
        });

        describe('updateHighestAbsoluteDriipNonce()', () => {
            describe('if community vote returns 0', () => {
                let highestAbsoluteDriipNonce;

                before(async () => {
                    highestAbsoluteDriipNonce = await ethersExchange.highestAbsoluteDriipNonce();
                    await ethersCommunityVote.setHighestAbsoluteDriipNonce(utils.bigNumberify(0));
                });

                it('should not update highestAbsoluteDriipNonce property', async () => {
                    await ethersExchange.updateHighestAbsoluteDriipNonce();
                    const result = await ethersExchange.highestAbsoluteDriipNonce();
                    result.eq(highestAbsoluteDriipNonce).should.be.true;
                });
            });

            describe('if community vote returns non-zero value', () => {
                let highestAbsoluteDriipNonce;

                before(async () => {
                    highestAbsoluteDriipNonce = utils.bigNumberify(10);
                    await ethersCommunityVote.setHighestAbsoluteDriipNonce(highestAbsoluteDriipNonce);
                });

                it('should update highestAbsoluteDriipNonce property', async () => {
                    await ethersExchange.updateHighestAbsoluteDriipNonce();
                    const result = await ethersExchange.highestAbsoluteDriipNonce();
                    result.eq(highestAbsoluteDriipNonce).should.be.true;
                });
            });
        });

        describe('settleDriipAsTrade()', () => {
            let trade, overrideOptions;

            before(async () => {
                overrideOptions = {gasLimit: 5e6};
            });

            beforeEach(async () => {
                await ethersClientFund.reset(overrideOptions);
                await ethersCommunityVote.reset(overrideOptions);
                await ethersReserveFund.reset(overrideOptions);
                await ethersConfiguration.reset(overrideOptions);
                await ethersValidator.reset(overrideOptions);

                await ethersConfiguration.setTradeMakerFee(utils.bigNumberify(blockNumber10), utils.parseUnits('0.001', 18), [], [], overrideOptions);
                await ethersConfiguration.setTradeMakerMinimumFee(utils.bigNumberify(blockNumber10), utils.parseUnits('0.0001', 18), overrideOptions);
                await ethersConfiguration.setTradeTakerFee(utils.bigNumberify(blockNumber10), utils.parseUnits('0.002', 18), [1], [utils.parseUnits('0.1', 18)], overrideOptions);
                await ethersConfiguration.setTradeTakerMinimumFee(utils.bigNumberify(blockNumber10), utils.parseUnits('0.0002', 18), overrideOptions);
            });

            describe('if trade is not sealed', () => {
                beforeEach(async () => {
                    await ethersValidator.setGenuineTradeSeal(false, overrideOptions);
                    trade = await mocks.mockTrade(glob.user_a);
                });

                it('should revert', async () => {
                    await ethersExchange.settleDriipAsTrade(trade, trade.buyer.wallet, overrideOptions).should.be.rejected;
                });
            });

            describe('if wallet is not trade party', () => {
                beforeEach(async () => {
                    trade = await mocks.mockTrade(glob.owner);
                });

                it('should revert', async () => {
                    const address = Wallet.createRandom().address;
                    ethersExchange.settleDriipAsTrade(trade, address, overrideOptions).should.be.rejected;
                });
            });

            describe('if wallet is flagged as double spender', () => {
                beforeEach(async () => {
                    trade = await mocks.mockTrade(glob.owner);
                    await ethersCommunityVote.setDoubleSpenderWallet(trade.buyer.wallet, true);
                });

                it('should revert', async () => {
                    ethersExchange.settleDriipAsTrade(trade, trade.buyer.wallet, overrideOptions).should.be.rejected;
                });
            });

            describe('if driip settlement challenge result is Qualified', () => {
                let challenger;

                before(() => {
                    challenger = Wallet.createRandom().address;
                });

                describe('if operational mode is exit and trade nonce is higher than absolute driip nonce', () => {
                    beforeEach(async () => {
                        await ethersConfiguration.setOperationalModeExit();
                    });

                    it('should revert', async () => {
                        ethersExchange.settleDriipAsTrade(trade, trade.buyer.wallet, overrideOptions).should.be.rejected;
                    });
                });

                describe('if data is unavailable and trade nonce is higher than absolute driip nonce', () => {
                    beforeEach(async () => {
                        await ethersCommunityVote.setDataAvailable(false);
                    });

                    it('should revert', async () => {
                        ethersExchange.settleDriipAsTrade(trade, trade.buyer.wallet, overrideOptions).should.be.rejected;
                    });
                });

                describe('if immediateSettlement is true', () => {
                    beforeEach(async () => {
                        trade = await mocks.mockTrade(glob.owner, {
                            blockNumber: utils.bigNumberify(await provider.getBlockNumber())
                        });
                        await ethersDriipSettlementChallenge.setDriipSettlementChallengeStatus(
                            trade.buyer.wallet,
                            trade.nonce,
                            mocks.challengeResults.indexOf('Qualified'),
                            challenger,
                            overrideOptions
                        );
                    });

                    it('should settle both trade parties', async () => {
                        await ethersExchange.settleDriipAsTrade(trade, trade.buyer.wallet, overrideOptions);

                        const clientFundTransferEvents = await provider.getLogs(await fromBlockTopicsFilter(
                            ethersClientFund.interface.events.TransferFromDepositedToSettledBalanceEvent.topics[0]
                        ));
                        clientFundTransferEvents.should.have.lengthOf(2);
                        const clientFundWithdrawEvents = await provider.getLogs(await fromBlockTopicsFilter(
                            ethersClientFund.interface.events.WithdrawFromDepositedBalanceEvent.topics[0]
                        ));
                        clientFundWithdrawEvents.should.have.lengthOf(2);
                        const revenueFundRecordEvents = await provider.getLogs(await fromBlockTopicsFilter(
                            ethersRevenueFund.interface.events.RecordDepositTokensEvent.topics[0]
                        ));
                        revenueFundRecordEvents.should.have.lengthOf(2);
                        const settleDriipEvents = await provider.getLogs(await fromBlockTopicsFilter(
                            ethersExchange.interface.events.SettleDriipAsTradeEvent.topics[0]
                        ));
                        settleDriipEvents.should.have.lengthOf(1);

                        const transfer0 = await ethersClientFund.transfers(0);
                        transfer0.source.should.equal(trade.seller.wallet);
                        transfer0.destination.should.equal(trade.buyer.wallet);
                        transfer0.amount.eq(trade.transfers.intended.net.sub(trade.buyer.netFees.intended)).should.be.true;
                        transfer0.currency.should.equal(trade.currencies.intended);

                        const transfer1 = await ethersClientFund.transfers(1);
                        transfer1.source.should.equal(trade.buyer.wallet);
                        transfer1.destination.should.equal(trade.seller.wallet);
                        transfer1.amount.eq(trade.transfers.conjugate.net.sub(trade.seller.netFees.conjugate)).should.be.true;
                        transfer1.currency.should.equal(trade.currencies.conjugate);

                        const withdrawal0 = await ethersClientFund.withdrawals(0);
                        withdrawal0.source.should.equal(trade.buyer.wallet);
                        withdrawal0.destination.should.equal(utils.getAddress(ethersRevenueFund.address));
                        withdrawal0.amount.eq(trade.buyer.netFees.intended).should.be.true;
                        withdrawal0.currency.should.equal(trade.currencies.intended);

                        const withdrawal1 = await ethersClientFund.withdrawals(1);
                        withdrawal1.source.should.equal(trade.seller.wallet);
                        withdrawal1.destination.should.equal(utils.getAddress(ethersRevenueFund.address));
                        withdrawal1.amount.eq(trade.seller.netFees.conjugate).should.be.true;
                        withdrawal1.currency.should.equal(trade.currencies.conjugate);

                        const nBuyerSettlements = await ethersExchange.walletSettlementsCount(trade.buyer.wallet);
                        const buyerSettlement = await ethersExchange.walletSettlement(trade.buyer.wallet, nBuyerSettlements - 1);
                        buyerSettlement.nonce.eq(trade.nonce).should.be.true;
                        buyerSettlement.driipType.should.equal(mocks.driipTypes.indexOf('Trade'));
                        buyerSettlement.sidedness.should.equal(mocks.sidednesses.indexOf('TwoSided'));
                        buyerSettlement.wallets.should.have.members([trade.buyer.wallet, trade.seller.wallet]);

                        const nSellerSettlements = await ethersExchange.walletSettlementsCount(trade.seller.wallet);
                        const sellerSettlement = await ethersExchange.walletSettlement(trade.seller.wallet, nSellerSettlements - 1);
                        sellerSettlement.should.deep.equal(buyerSettlement);
                    });
                });

                describe('if immediateSettlement is false', () => {
                    describe('if reserve fund does not support settlement', () => {
                        beforeEach(async () => {
                            trade = await mocks.mockTrade(glob.owner, {
                                immediateSettlement: false,
                                blockNumber: utils.bigNumberify(await provider.getBlockNumber())
                            });
                            await ethersDriipSettlementChallenge.setDriipSettlementChallengeStatus(
                                trade.buyer.wallet,
                                trade.nonce,
                                mocks.challengeResults.indexOf('Qualified'),
                                challenger,
                                overrideOptions
                            );
                            await ethersReserveFund.setMaxOutboundTransfer(trade.currencies.intended, 0, overrideOptions);
                            await ethersReserveFund.setMaxOutboundTransfer(trade.currencies.conjugate, 0, overrideOptions);
                        });

                        it('should settle both trade parties', async () => {
                            await ethersExchange.settleDriipAsTrade(trade, trade.buyer.wallet, overrideOptions);

                            const clientFundTransferEvents = await provider.getLogs(await fromBlockTopicsFilter(
                                ethersClientFund.interface.events.TransferFromDepositedToSettledBalanceEvent.topics[0]
                            ));
                            clientFundTransferEvents.should.have.lengthOf(2);
                            const clientFundWithdrawEvents = await provider.getLogs(await fromBlockTopicsFilter(
                                ethersClientFund.interface.events.WithdrawFromDepositedBalanceEvent.topics[0]
                            ));
                            clientFundWithdrawEvents.should.have.lengthOf(2);
                            const revenueFundRecordEvents = await provider.getLogs(await fromBlockTopicsFilter(
                                ethersRevenueFund.interface.events.RecordDepositTokensEvent.topics[0]
                            ));
                            revenueFundRecordEvents.should.have.lengthOf(2);
                            const settleDriipEvents = await provider.getLogs(await fromBlockTopicsFilter(
                                ethersExchange.interface.events.SettleDriipAsTradeEvent.topics[0]
                            ));
                            settleDriipEvents.should.have.lengthOf(1);

                            const transfer0 = await ethersClientFund.transfers(0);
                            transfer0.source.should.equal(trade.seller.wallet);
                            transfer0.destination.should.equal(trade.buyer.wallet);
                            transfer0.amount.eq(trade.transfers.intended.net.sub(trade.buyer.netFees.intended)).should.be.true;
                            transfer0.currency.should.equal(trade.currencies.intended);

                            const transfer1 = await ethersClientFund.transfers(1);
                            transfer1.source.should.equal(trade.buyer.wallet);
                            transfer1.destination.should.equal(trade.seller.wallet);
                            transfer1.amount.eq(trade.transfers.conjugate.net.sub(trade.seller.netFees.conjugate)).should.be.true;
                            transfer1.currency.should.equal(trade.currencies.conjugate);

                            const withdrawal0 = await ethersClientFund.withdrawals(0);
                            withdrawal0.source.should.equal(trade.buyer.wallet);
                            withdrawal0.destination.should.equal(utils.getAddress(ethersRevenueFund.address));
                            withdrawal0.amount.eq(trade.buyer.netFees.intended).should.be.true;
                            withdrawal0.currency.should.equal(trade.currencies.intended);

                            const withdrawal1 = await ethersClientFund.withdrawals(1);
                            withdrawal1.source.should.equal(trade.seller.wallet);
                            withdrawal1.destination.should.equal(utils.getAddress(ethersRevenueFund.address));
                            withdrawal1.amount.eq(trade.seller.netFees.conjugate).should.be.true;
                            withdrawal1.currency.should.equal(trade.currencies.conjugate);

                            const nBuyerSettlements = await ethersExchange.walletSettlementsCount(trade.buyer.wallet);
                            const buyerSettlement = await ethersExchange.walletSettlement(trade.buyer.wallet, nBuyerSettlements - 1);
                            buyerSettlement.nonce.eq(trade.nonce).should.be.true;
                            buyerSettlement.driipType.should.equal(mocks.driipTypes.indexOf('Trade'));
                            buyerSettlement.sidedness.should.equal(mocks.sidednesses.indexOf('TwoSided'));
                            buyerSettlement.wallets.should.have.members([trade.buyer.wallet, trade.seller.wallet]);

                            const nSellerSettlements = await ethersExchange.walletSettlementsCount(trade.seller.wallet);
                            const sellerSettlement = await ethersExchange.walletSettlement(trade.seller.wallet, nSellerSettlements - 1);
                            sellerSettlement.should.deep.equal(buyerSettlement);
                        });
                    });

                    describe('if reserve fund does support settlement', () => {
                        beforeEach(async () => {
                            trade = await mocks.mockTrade(glob.owner, {
                                immediateSettlement: false,
                                blockNumber: utils.bigNumberify(await provider.getBlockNumber())
                            });
                            await ethersDriipSettlementChallenge.setDriipSettlementChallengeStatus(
                                trade.buyer.wallet,
                                trade.nonce,
                                mocks.challengeResults.indexOf('Qualified'),
                                challenger,
                                overrideOptions
                            );
                            await ethersReserveFund.setMaxOutboundTransfer(trade.currencies.intended, utils.parseUnits('1000', 18), overrideOptions);
                            await ethersReserveFund.setMaxOutboundTransfer(trade.currencies.conjugate, utils.parseUnits('1', 18), overrideOptions);
                        });

                        it('should settle only provided party', async () => {
                            await ethersExchange.settleDriipAsTrade(trade, trade.buyer.wallet, overrideOptions);

                            const clientFundTransferEvents = await provider.getLogs(await fromBlockTopicsFilter(
                                ethersClientFund.interface.events.TransferFromDepositedToSettledBalanceEvent.topics[0]
                            ));
                            clientFundTransferEvents.should.be.empty;
                            const clientFundWithdrawEvents = await provider.getLogs(await fromBlockTopicsFilter(
                                ethersClientFund.interface.events.WithdrawFromDepositedBalanceEvent.topics[0]
                            ));
                            clientFundWithdrawEvents.should.be.empty;
                            const revenueFundRecordEvents = await provider.getLogs(await fromBlockTopicsFilter(
                                ethersRevenueFund.interface.events.RecordDepositTokensEvent.topics[0]
                            ));
                            revenueFundRecordEvents.should.be.empty;
                            const settleDriipEvents = await provider.getLogs(await fromBlockTopicsFilter(
                                ethersExchange.interface.events.SettleDriipAsTradeEvent.topics[0]
                            ));
                            settleDriipEvents.should.have.lengthOf(1);

                            const nBuyerSettlements = await ethersExchange.walletSettlementsCount(trade.buyer.wallet);
                            const buyerSettlement = await ethersExchange.walletSettlement(trade.buyer.wallet, nBuyerSettlements - 1);
                            buyerSettlement.nonce.eq(trade.nonce).should.be.true;
                            buyerSettlement.driipType.should.equal(mocks.driipTypes.indexOf('Trade'));
                            buyerSettlement.sidedness.should.equal(mocks.sidednesses.indexOf('OneSided'));
                            buyerSettlement.wallets.should.have.members([trade.buyer.wallet, mocks.address0]);

                            const nSellerSettlements = await ethersExchange.walletSettlementsCount(trade.seller.wallet);
                            nSellerSettlements.eq(utils.bigNumberify(0)).should.be.true;
                        });
                    });
                });
            });

            describe('if driip settlement challenge result is Disqualified', () => {
                let challenger;

                before(() => {
                    challenger = Wallet.createRandom().address;
                });

                beforeEach(async () => {
                    trade = await mocks.mockTrade(glob.owner, {
                        blockNumber: utils.bigNumberify(await provider.getBlockNumber())
                    });
                    await ethersDriipSettlementChallenge.setDriipSettlementChallengeStatus(
                        trade.buyer.wallet,
                        trade.nonce,
                        mocks.challengeResults.indexOf('Disqualified'),
                        challenger,
                        overrideOptions
                    );
                });

                it('should seize the wallet', async () => {
                    await ethersExchange.settleDriipAsTrade(trade, trade.buyer.wallet, overrideOptions);
                    const seized = await ethersExchange.isSeizedWallet(trade.buyer.wallet);
                    seized.should.be.true;
                    const seizure = await ethersClientFund.seizures(0);
                    seizure.source.should.equal(utils.getAddress(trade.buyer.wallet));
                    seizure.destination.should.equal(utils.getAddress(challenger));
                });
            });
        });

        describe('settleDriipAsPayment()', () => {
            let payment, overrideOptions;

            before(async () => {
                overrideOptions = {gasLimit: 5e6};
            });

            beforeEach(async () => {
                await ethersClientFund.reset(overrideOptions);
                await ethersCommunityVote.reset(overrideOptions);
                await ethersReserveFund.reset(overrideOptions);
                await ethersConfiguration.reset(overrideOptions);
                await ethersValidator.reset(overrideOptions);

                await ethersConfiguration.setPaymentFee(utils.bigNumberify(blockNumber10), utils.parseUnits('0.002', 18), [], [], overrideOptions);
                await ethersConfiguration.setPaymentMinimumFee(utils.bigNumberify(blockNumber10), utils.parseUnits('0.0002', 18), overrideOptions);
            });

            describe('if payment is not sealed', () => {
                beforeEach(async () => {
                    await ethersValidator.setGenuinePaymentSeals(false, overrideOptions);
                    payment = await mocks.mockPayment(glob.user_a);
                });

                it('should revert', async () => {
                    await ethersExchange.settleDriipAsPayment(payment, payment.sender.wallet, overrideOptions).should.be.rejected;
                });
            });

            describe('if wallet is not payment party', () => {
                beforeEach(async () => {
                    payment = await mocks.mockPayment(glob.owner);
                });

                it('should revert', async () => {
                    const address = Wallet.createRandom().address;
                    ethersExchange.settleDriipAsPayment(payment, address, overrideOptions).should.be.rejected;
                });
            });

            describe('if wallet is flagged as double spender', () => {
                beforeEach(async () => {
                    payment = await mocks.mockPayment(glob.owner);
                    await ethersCommunityVote.setDoubleSpenderWallet(payment.sender.wallet, true);
                });

                it('should revert', async () => {
                    ethersExchange.settleDriipAsPayment(payment, payment.sender.wallet, overrideOptions).should.be.rejected;
                });
            });

            describe('if driip settlement challenge result is Qualified', () => {
                let challenger;

                before(() => {
                    challenger = Wallet.createRandom().address;
                });

                describe('if operational mode is exit and payment nonce is higher than absolute driip nonce', () => {
                    beforeEach(async () => {
                        await ethersConfiguration.setOperationalModeExit();
                    });

                    it('should revert', async () => {
                        ethersExchange.settleDriipAsPayment(payment, payment.sender.wallet, overrideOptions).should.be.rejected;
                    });
                });

                describe('if data is unavailable and payment nonce is higher than absolute driip nonce', () => {
                    beforeEach(async () => {
                        await ethersCommunityVote.setDataAvailable(false);
                    });

                    it('should revert', async () => {
                        ethersExchange.settleDriipAsPayment(payment, payment.sender.wallet, overrideOptions).should.be.rejected;
                    });
                });

                describe('if immediateSettlement is true', () => {
                    beforeEach(async () => {
                        payment = await mocks.mockPayment(glob.owner, {
                            blockNumber: utils.bigNumberify(await provider.getBlockNumber())
                        });
                        await ethersDriipSettlementChallenge.setDriipSettlementChallengeStatus(
                            payment.sender.wallet,
                            payment.nonce,
                            mocks.challengeResults.indexOf('Qualified'),
                            challenger,
                            overrideOptions
                        );
                    });

                    it('should settle both payment parties', async () => {
                        await ethersExchange.settleDriipAsPayment(payment, payment.sender.wallet, overrideOptions);

                        const clientFundTransferEvents = await provider.getLogs(await fromBlockTopicsFilter(
                            ethersClientFund.interface.events.TransferFromDepositedToSettledBalanceEvent.topics[0]
                        ));
                        clientFundTransferEvents.should.have.lengthOf(1);
                        const clientFundWithdrawEvents = await provider.getLogs(await fromBlockTopicsFilter(
                            ethersClientFund.interface.events.WithdrawFromDepositedBalanceEvent.topics[0]
                        ));
                        clientFundWithdrawEvents.should.have.lengthOf(1);
                        const revenueFundRecordEvents = await provider.getLogs(await fromBlockTopicsFilter(
                            ethersRevenueFund.interface.events.RecordDepositTokensEvent.topics[0]
                        ));
                        revenueFundRecordEvents.should.have.lengthOf(1);
                        const settleDriipEvents = await provider.getLogs(await fromBlockTopicsFilter(
                            ethersExchange.interface.events.SettleDriipAsPaymentEvent.topics[0]
                        ));
                        settleDriipEvents.should.have.lengthOf(1);

                        const transfer = await ethersClientFund.transfers(0);
                        transfer.source.should.equal(payment.sender.wallet);
                        transfer.destination.should.equal(payment.recipient.wallet);
                        transfer.amount.eq(payment.transfers.net).should.be.true;
                        transfer.currency.should.equal(payment.currency);

                        const withdrawal = await ethersClientFund.withdrawals(0);
                        withdrawal.source.should.equal(payment.sender.wallet);
                        withdrawal.destination.should.equal(utils.getAddress(ethersRevenueFund.address));
                        withdrawal.amount.eq(payment.sender.netFee).should.be.true;
                        withdrawal.currency.should.equal(payment.currency);

                        const nSenderSettlements = await ethersExchange.walletSettlementsCount(payment.sender.wallet);
                        const senderSettlement = await ethersExchange.walletSettlement(payment.sender.wallet, nSenderSettlements - 1);
                        senderSettlement.nonce.eq(payment.nonce).should.be.true;
                        senderSettlement.driipType.should.equal(mocks.driipTypes.indexOf('Payment'));
                        senderSettlement.sidedness.should.equal(mocks.sidednesses.indexOf('TwoSided'));
                        senderSettlement.wallets.should.have.members([payment.sender.wallet, payment.recipient.wallet]);

                        const nRecipientSettlements = await ethersExchange.walletSettlementsCount(payment.recipient.wallet);
                        const recipientSettlement = await ethersExchange.walletSettlement(payment.recipient.wallet, nRecipientSettlements - 1);
                        recipientSettlement.should.deep.equal(senderSettlement);
                    });
                });

                describe('if immediateSettlement is false', () => {
                    describe('if reserve fund does not support settlement', () => {
                        beforeEach(async () => {
                            payment = await mocks.mockPayment(glob.owner, {
                                immediateSettlement: false,
                                recipient: {netFee: utils.parseUnits('0.1', 18)},
                                blockNumber: utils.bigNumberify(await provider.getBlockNumber())
                            });
                            await ethersDriipSettlementChallenge.setDriipSettlementChallengeStatus(
                                payment.recipient.wallet,
                                payment.nonce,
                                mocks.challengeResults.indexOf('Qualified'),
                                challenger,
                                overrideOptions
                            );
                            await ethersReserveFund.setMaxOutboundTransfer(payment.currency, 0, overrideOptions);
                        });

                        it('should settle both payment parties', async () => {
                            await ethersExchange.settleDriipAsPayment(payment, payment.recipient.wallet, overrideOptions);

                            const clientFundTransferEvents = await provider.getLogs(await fromBlockTopicsFilter(
                                ethersClientFund.interface.events.TransferFromDepositedToSettledBalanceEvent.topics[0]
                            ));
                            clientFundTransferEvents.should.have.lengthOf(1);
                            const clientFundWithdrawEvents = await provider.getLogs(await fromBlockTopicsFilter(
                                ethersClientFund.interface.events.WithdrawFromDepositedBalanceEvent.topics[0]
                            ));
                            clientFundWithdrawEvents.should.have.lengthOf(2);
                            const revenueFundRecordEvents = await provider.getLogs(await fromBlockTopicsFilter(
                                ethersRevenueFund.interface.events.RecordDepositTokensEvent.topics[0]
                            ));
                            revenueFundRecordEvents.should.have.lengthOf(2);
                            const settleDriipEvents = await provider.getLogs(await fromBlockTopicsFilter(
                                ethersExchange.interface.events.SettleDriipAsPaymentEvent.topics[0]
                            ));
                            settleDriipEvents.should.have.lengthOf(1);

                            const transfer = await ethersClientFund.transfers(0);
                            transfer.source.should.equal(payment.sender.wallet);
                            transfer.destination.should.equal(payment.recipient.wallet);
                            transfer.amount.eq(payment.transfers.net).should.be.true;
                            transfer.currency.should.equal(payment.currency);

                            const senderWithdrawal = await ethersClientFund.withdrawals(0);
                            senderWithdrawal.source.should.equal(payment.sender.wallet);
                            senderWithdrawal.destination.should.equal(utils.getAddress(ethersRevenueFund.address));
                            senderWithdrawal.amount.eq(payment.sender.netFee).should.be.true;
                            senderWithdrawal.currency.should.equal(payment.currency);

                            const recipientWithdrawal = await ethersClientFund.withdrawals(1);
                            recipientWithdrawal.source.should.equal(payment.recipient.wallet);
                            recipientWithdrawal.destination.should.equal(utils.getAddress(ethersRevenueFund.address));
                            recipientWithdrawal.amount.eq(payment.recipient.netFee).should.be.true;
                            recipientWithdrawal.currency.should.equal(payment.currency);

                            const nSenderSettlements = await ethersExchange.walletSettlementsCount(payment.sender.wallet);
                            const senderSettlement = await ethersExchange.walletSettlement(payment.sender.wallet, nSenderSettlements - 1);
                            senderSettlement.nonce.eq(payment.nonce).should.be.true;
                            senderSettlement.driipType.should.equal(mocks.driipTypes.indexOf('Payment'));
                            senderSettlement.sidedness.should.equal(mocks.sidednesses.indexOf('TwoSided'));
                            senderSettlement.wallets.should.have.members([payment.sender.wallet, payment.recipient.wallet]);

                            const nRecipientSettlements = await ethersExchange.walletSettlementsCount(payment.recipient.wallet);
                            const recipientSettlement = await ethersExchange.walletSettlement(payment.recipient.wallet, nRecipientSettlements - 1);
                            recipientSettlement.should.deep.equal(senderSettlement);
                        });
                    });

                    describe('if reserve fund does support settlement', () => {
                        beforeEach(async () => {
                            payment = await mocks.mockPayment(glob.owner, {
                                immediateSettlement: false,
                                blockNumber: utils.bigNumberify(await provider.getBlockNumber())
                            });
                            await ethersDriipSettlementChallenge.setDriipSettlementChallengeStatus(
                                payment.recipient.wallet,
                                payment.nonce,
                                mocks.challengeResults.indexOf('Qualified'),
                                challenger,
                                overrideOptions
                            );
                            await ethersReserveFund.setMaxOutboundTransfer(payment.currency, utils.parseUnits('1000', 18), overrideOptions);
                        });

                        it('should settle only provided party', async () => {
                            await ethersExchange.settleDriipAsPayment(payment, payment.recipient.wallet, overrideOptions);

                            const clientFundTransferEvents = await provider.getLogs(await fromBlockTopicsFilter(
                                ethersClientFund.interface.events.TransferFromDepositedToSettledBalanceEvent.topics[0]
                            ));
                            clientFundTransferEvents.should.be.empty;
                            const clientFundWithdrawEvents = await provider.getLogs(await fromBlockTopicsFilter(
                                ethersClientFund.interface.events.WithdrawFromDepositedBalanceEvent.topics[0]
                            ));
                            clientFundWithdrawEvents.should.be.empty;
                            const revenueFundRecordEvents = await provider.getLogs(await fromBlockTopicsFilter(
                                ethersRevenueFund.interface.events.RecordDepositTokensEvent.topics[0]
                            ));
                            revenueFundRecordEvents.should.be.empty;
                            const settleDriipEvents = await provider.getLogs(await fromBlockTopicsFilter(
                                ethersExchange.interface.events.SettleDriipAsPaymentEvent.topics[0]
                            ));
                            settleDriipEvents.should.have.lengthOf(1);

                            const nSenderSettlements = await ethersExchange.walletSettlementsCount(payment.sender.wallet);
                            nSenderSettlements.eq(0).should.be.true;

                            const nRecipientSettlements = await ethersExchange.walletSettlementsCount(payment.recipient.wallet);
                            const recipientSettlement = await ethersExchange.walletSettlement(payment.recipient.wallet, nRecipientSettlements - 1);
                            recipientSettlement.nonce.eq(payment.nonce).should.be.true;
                            recipientSettlement.driipType.should.equal(mocks.driipTypes.indexOf('Payment'));
                            recipientSettlement.sidedness.should.equal(mocks.sidednesses.indexOf('OneSided'));
                            recipientSettlement.wallets.should.have.members([payment.recipient.wallet, mocks.address0]);
                        });
                    });
                });
            });

            describe('if driip settlement challenge result is Disqualified', () => {
                let challenger;

                before(() => {
                    challenger = Wallet.createRandom().address;
                });

                beforeEach(async () => {
                    payment = await mocks.mockPayment(glob.owner, {
                        blockNumber: utils.bigNumberify(await provider.getBlockNumber())
                    });
                    await ethersDriipSettlementChallenge.setDriipSettlementChallengeStatus(
                        payment.sender.wallet,
                        payment.nonce,
                        mocks.challengeResults.indexOf('Disqualified'),
                        challenger,
                        overrideOptions
                    );
                });

                it('should seize the wallet', async () => {
                    await ethersExchange.settleDriipAsPayment(payment, payment.sender.wallet, overrideOptions);
                    const seized = await ethersExchange.isSeizedWallet(payment.sender.wallet);
                    seized.should.be.true;
                    const seizure = await ethersClientFund.seizures(0);
                    seizure.source.should.equal(utils.getAddress(payment.sender.wallet));
                    seizure.destination.should.equal(utils.getAddress(challenger));
                });
            });
        });
    });
};

const fromBlockTopicsFilter = async (...topics) => {
    return {
        fromBlock: await provider.getBlockNumber(),
        topics
    };
};
