const RemmeTokenMock = artifacts.require('RemmeTokenMock');
const RemmeBridge = artifacts.require('RemmeBridge');

const providerFee = 1;

module.exports = async (deployer) => {

    /*
    * Warning! Script should be used just for development!
    * */

    deployer.deploy(RemmeTokenMock).then((remmeToken) => {
      const tokenAddress = remmeToken.address;
      const atomicSwapProvider = web3.eth.accounts[0];
      const aliceAddress = web3.eth.accounts[1];
      const coldStorage = web3.eth.accounts[2];
      deployer.deploy(RemmeBridge, tokenAddress, atomicSwapProvider, coldStorage, providerFee).then((remmeBridge) => {
        const remmeBridgeAddress = remmeBridge.address;
        
        RemmeTokenMock.at(tokenAddress).transfer(aliceAddress, 100000).then(() => {
          RemmeTokenMock.at(tokenAddress).approve(remmeBridgeAddress, 100000, {from: aliceAddress}).then(() => {
            console.log(`let remmeTokenAddress = "${tokenAddress}"`);
            console.log(`let remmeBridgeAddress ="${remmeBridgeAddress}"`);
            console.log(`let atomicSwapProvider = "${atomicSwapProvider}"`);
            console.log(`let aliceAddress = "${aliceAddress}"`);
          });
        })
      })
    })
  };
  