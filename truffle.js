module.exports = {
    networks: {
        development: {
            host: "localhost",
            port: 8545,
            network_id: "*",
            gas: 6000000
        },
        ganache_for_test: {
            host: "localhost",
            port: 8456,
            network_id: "*",
            gas: 6000000
        },
        testnet: {
            host: "52.208.46.161",
            port: 8549,
            network_id: "3",
            gas: 6000000
        },
        mainnet: {
            host: "ethereum.hubii.com",
            port: 8545,
            network_id: "1",
            gas: 6000000
        },
        develop: {
            host: "localhost",
            port: 9545,
            network_id: "*",
            gas: 6000000
        },
        ganache: {
            host: "localhost",
            port: 7545,
            network_id: "*",
            gas: 6000000
        },
        ganachecli: {
            host: "localhost",
            port: 8545,
            network_id: "*",
            gas: 6000000
        }
    },
    solc: {
        optimizer: {
            enabled: true,
            runs: 0
        }
    }
};
