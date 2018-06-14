/*!
 * Hubii - Omphalos
 *
 * Copyright (C) 2017-2018 Hubii AS
 */
const Migrations = artifacts.require("./Migrations.sol");

var helpers = require('./helpers.js');

// -----------------------------------------------------------------------------------------------------------------

module.exports = function(deployer, network, accounts) {
	var ownerAccount;

	if (helpers.isTestNetwork(network)) {
		ownerAccount = accounts[0];
	}
	else {
		ownerAccount = helpers.getOwnerAccountFromArgs();
		ownerAccountPassword = helpers.getPasswordFromArgs();
		helpers.unlockAddress(web3, ownerAccount, ownerAccountPassword, 600); //10 minutes
	}

	deployer.deploy(Migrations, {
		from : ownerAccount
	});
};
