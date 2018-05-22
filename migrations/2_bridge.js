const RemmeTokenMock = artifacts.require('RemmeTokenMock');
const RemmeBridge = artifacts.require('RemmeBridge');

module.exports = async (deployer, network, accounts) => {
    let token;
    let providerFee = 4000;

    return deployer
        .then(_ => deployer.deploy(RemmeTokenMock))
        .then(_ => RemmeTokenMock.deployed())
        .then(t => {
            token = t;
            deployer.deploy(RemmeBridge, token, accounts[0], accounts[2], providerFee)
        })
        .catch(console.error);
};