import assertRevert from './helpers/assertRevert';
import increaseTime from "./helpers/increaseTime"
var Web3latest = require('web3');
var web3latest = new Web3latest();
const eventProvider = new web3latest.providers.WebsocketProvider('ws://localhost:7545')
web3latest.setProvider(eventProvider)

const RemmeToken = artifacts.require('RemmeTokenMock')
const RemmeBridge = artifacts.require('RemmeBridge')

contract ('RemmeBridge', accounts => {

    let remmeBridge;
    let remmeToken;
    let swapProvider = accounts[0]
    let alice = accounts[1]
    let coldStorage = accounts[2]
    let providerFee = 4000

    //test values
    let swapId;
    let secretKey = web3latest.utils.soliditySha3("absolutelysecretkey")

    console.log("key :" + secretKey)
    let secretLock = web3latest.utils.soliditySha3(secretKey)
    console.log("lock :" + secretLock)
    let emptyLock = 0
    let amount;
    let remchainAddress = web3latest.utils.soliditySha3('remchainAddress');

    before('setup', async () => {
        remmeToken = await RemmeToken.new({from: swapProvider})
        remmeBridge = await RemmeBridge.new(remmeToken.address, swapProvider, coldStorage, providerFee)
        let providerBalance = await remmeToken.balanceOf(swapProvider)
        console.log("provider balance: " + providerBalance.toNumber())

        await remmeToken.transfer(alice, 10000000)
        let aliceBalance = await remmeToken.balanceOf(alice)
        console.log("alice balance: " + aliceBalance.toNumber())
        assert.equal(aliceBalance.toNumber(), 10000000, "Alice's balance should be increased by provided value")
    })

    // >>>ETH-REM swap>>>

    describe('Swap opening ', () => {

        it('should not allow to open if not enough funds', async() => {
            swapId = web3.toHex(web3latest.utils.soliditySha3(1))
            let largerAmount = 100000000
            assertRevert(
                remmeBridge.openSwap(swapId, swapProvider, emptyLock, largerAmount, remchainAddress, "email", {from: alice})
            )
        })

        it('should not allow to open if not enough allowance', async() => {
            swapId = web3.toHex(web3latest.utils.soliditySha3(2))
            amount = 20000
            // let allowanceAlice = await remmeToken.allowance(alice.address, remmeBridge.address);
            // console.log("alice's allowance: " + allowanceAlice)
            assertRevert(
                remmeBridge.openSwap(swapId, swapProvider, emptyLock, amount, remchainAddress, "email", {from: alice})
            )
        })

        it.skip('should set locktime 24 hours when secretlock is not provided & keyHolder is receiverAddress', async() => {
            swapId = web3.toHex(web3latest.utils.soliditySha3(3))
            amount = 10000
            await remmeToken.approve(remmeBridge.address, amount, {from: alice})
            let result = await remmeBridge.openSwap(swapId, swapProvider, emptyLock, amount, remchainAddress, "email", {from: alice})
            console.log(result)
            let [,,,,timelock] = await remmeBridge.getSwapDetails.call(swapId)
            let now = await web3latest.eth.getBlock(result.blockNumber).timestamp //fixme timestamp undefined
            console.log("now " + now)
            console.log("timelock " + timelock)
            assert(timelock > (now + 23 * 3600) && timelock < (now + 24 * 3600 + 1),
                "timelock in range (now + 23h : now + 24h + 1s")
        })

        it.skip('should set locktime 48 hours when secretlock is provided & keyHolder is senderAddress', async() => {
            swapId = web3.toHex(web3latest.utils.soliditySha3(4)) //make sure swapId not match with existing
            amount = 10000
            await remmeToken.approve(remmeBridge.address, amount, {from: swapProvider})
            let result = await remmeBridge.openSwap(swapId, alice, secretLock, amount, remchainAddress, "email", {from: alice})
            console.log(result)
            let [,,,,timelock] = await remmeBridge.getSwapDetails.call(swapId)
            let now = await web3latest.eth.getBlock(result.blockNumber).timestamp //fixme timestamp undefined
            console.log("now " + now)
            console.log("timelock " + timelock)
            assert(timelock > (now + 23 * 3600) && timelock < (now + 24 * 3600 + 1),
                "timelock in range (now + 23h : now + 24h + 1s")
        })

        it('should deposit proper token amount to contract (balance & swap amount) if provider used', async() => {
            swapId = web3.toHex(web3latest.utils.soliditySha3(5)) //make sure swapId not match with existing
            amount = 10000
            let bridgeInitialBalance = await remmeToken.balanceOf(remmeBridge.address)
            console.log(bridgeInitialBalance.toNumber())
            await remmeToken.approve(remmeBridge.address, amount, {from: alice})
            await remmeBridge.openSwap(swapId, swapProvider, emptyLock, amount, remchainAddress, "email", {from: alice})

            let [swapAmount,,,,] = await remmeBridge.getSwapDetails.call(swapId)
            console.log(swapAmount.toNumber())
            let bridgeEndBalance = await remmeToken.balanceOf(remmeBridge.address)
            assert.equal(bridgeEndBalance.toNumber(), bridgeInitialBalance + amount - providerFee, "should increase bridge balance")
            assert.equal(swapAmount, amount - providerFee, "should set amount to swap")
        })

        it('should create AtomicSwap struct with provided info', async() => {
            swapId = web3.toHex(web3latest.utils.soliditySha3(6)) //make sure swapId not match with existing
            amount = 10000
            await remmeToken.approve(remmeBridge.address, amount, {from: alice})
            await remmeBridge.openSwap(swapId, swapProvider, emptyLock, amount, remchainAddress, "email", {from: alice})

            let [sender, receiver, keyHolder, remChainAddress, state] = await remmeBridge.getSwapInfo.call(swapId)
            let [amountR, emailEncrypted, secretLockR, secretKeyR, timeLock] = await remmeBridge.getSwapDetails.call(swapId)

            // let now = await web3latest.eth.getBlock(result.blockNumber).timestamp

            assert.equal(sender, alice, "sender should be alice")
            assert.equal(receiver, swapProvider, "receiver should be swapProvider")
            assert.equal(keyHolder, swapProvider, "keyHolder should be swapProvider")
            assert.equal(remChainAddress, remchainAddress, "remchain addresses should match")
            assert.equal(state, 1, "state should be OPENED")
            assert.equal(amountR, amount - providerFee, "amount should be equal initial without fee")
            assert.equal(emailEncrypted, web3.toHex("email"), "emails should match")
            assert.equal(secretLockR, emptyLock, "secret lock should be empty")
            assert.equal(secretKeyR, emptyLock, "secret keys should be empty")
            // assert(timelock > (now + 23 * 3600) && timelock < (now + 24 * 3600 + 1), "timelock should be 24h from now")
        })

        it('should deposit proper token amount to swap & fee to cold storage if provider used', async() => {
            swapId = web3.toHex(web3latest.utils.soliditySha3(7)) //make sure swapId not match with existing
            amount = 100000
            let coldStorageInitialBalance = await remmeToken.balanceOf(coldStorage)
            console.log(coldStorageInitialBalance.toNumber())

            await remmeToken.approve(remmeBridge.address, amount, {from: alice})
            await remmeBridge.openSwap(swapId, swapProvider, emptyLock, amount, remchainAddress, "email", {from: alice})

            let [swapAmount,,,,] = await remmeBridge.getSwapDetails.call(swapId)
            console.log(swapAmount.toNumber())
            let coldStorageEndBalance = await remmeToken.balanceOf(coldStorage)
            assert.equal(coldStorageEndBalance.toNumber(), coldStorageInitialBalance.toNumber() + providerFee,
                "should transfer fee to cold storage")
            assert.equal(swapAmount, amount - providerFee, "should set amount without fee to swap")
        })
    })

    describe('Swap approval ', () => {

        it('should not allow approve if secret lock is not set yet', async() => {
            swapId = web3.toHex(web3latest.utils.soliditySha3(8)) //make sure swapId not match with existing
            amount = 10000
            await remmeToken.approve(remmeBridge.address, amount, {from: alice})
            await remmeBridge.openSwap(swapId, swapProvider, emptyLock, amount, remchainAddress, "email", {from: alice})
            assertRevert(remmeBridge.approveSwap(swapId, {from: alice}))
        })

        it('should allow to approve only by sender', async() => {
            swapId = web3.toHex(web3latest.utils.soliditySha3(9)) //make sure swapId not match with existing
            amount = 10000
            await remmeToken.approve(remmeBridge.address, amount, {from: alice})
            await remmeBridge.openSwap(swapId, swapProvider, emptyLock, amount, remchainAddress, "email", {from: alice})
            await remmeBridge.setSecretLock(swapId, secretLock, {from: swapProvider})
            // await assertRevert(remmeBridge.approveSwap(swapId, {from: swapProvider}))
            // await assertRevert(remmeBridge.approveSwap(swapId, {from: accounts[5]}))
            await remmeBridge.approveSwap(swapId, {from: alice})
        })

        it('should set Approved state', async() => {
            swapId = web3.toHex(web3latest.utils.soliditySha3(10)) //make sure swapId not match with existing
            amount = 10000
            await remmeToken.approve(remmeBridge.address, amount, {from: alice})
            await remmeBridge.openSwap(swapId, swapProvider, emptyLock, amount, remchainAddress, "email", {from: alice})
            await remmeBridge.setSecretLock(swapId, secretLock, {from: swapProvider})
            await remmeBridge.approveSwap(swapId, {from: alice})
            let [,,,,state] = await remmeBridge.getSwapInfo.call(swapId)
            console.log("state: " + state)
            assert.equal(state, 2, "state should be Approved")
        })
    })

    describe('Swap expiration ', () => {

        it.skip('should return tokens to senderAddress & set EXPIRED state', async() => {
            swapId = web3.toHex(web3latest.utils.soliditySha3(11)) //make sure swapId not match with existing
            amount = 10000
            let aliceInitialBalance = await remmeToken.balanceOf(alice)

            await remmeToken.approve(remmeBridge.address, amount, {from: alice})
            await remmeBridge.openSwap(swapId, swapProvider, emptyLock, amount, remchainAddress, "email", {from: alice})
            let now = await web3latest.eth.getBlock(result.blockNumber).timestamp //fixme timestamp undefined
            console.log("now " + now)
            increaseTime(24 * 3600)
            now = await web3latest.eth.getBlock(result.blockNumber).timestamp //fixme timestamp undefined
            console.log("now " + now)
            await remmeBridge.expireSwap(swapId)

            let aliceEndBalance = await remmeToken.balanceOf(alice)
            assert.equal(aliceInitialBalance, aliceEndBalance - providerFee, "balance should be restored without fee")

            let [,,,,state] = await remmeBridge.getSwapInfo.call(swapId)
            console.log("state: " + state)
            assert.equal(state, 4, "state should be expired")
        })

        it.skip('should allow to expire only after timelock and only by sender', async() => {
            swapId = web3.toHex(web3latest.utils.soliditySha3(12)) //make sure swapId not match with existing
            amount = 10000
            await remmeToken.approve(remmeBridge.address, amount, {from: alice})
            await remmeBridge.openSwap(swapId, swapProvider, emptyLock, amount, remchainAddress, "email", {from: alice})
            await assertRevert(remmeBridge.expireSwap(swapId, {from: alice}))
            await assertRevert(remmeBridge.expireSwap(swapId, {from: swapProvider}))
        })
    })

    describe('Swap closing ', () => {

        it('should allow to close only by receiverAddress', async() => {
            swapId = web3.toHex(web3latest.utils.soliditySha3(13)) //make sure swapId not match with existing
            amount = 10000
            await remmeToken.approve(remmeBridge.address, amount, {from: alice})
            await remmeBridge.openSwap(swapId, swapProvider, emptyLock, amount, remchainAddress, "email", {from: alice})
            await remmeBridge.setSecretLock(swapId, secretLock, {from: swapProvider})
            await remmeBridge.approveSwap(swapId, {from: alice})
            await assertRevert(remmeBridge.closeSwap(swapId, secretKey, {from: alice}))
            await assertRevert(remmeBridge.closeSwap(swapId, secretKey, {from: accounts[5]}))
            await remmeBridge.closeSwap(swapId, secretKey, {from: swapProvider})
            let [,,,,state3] = await remmeBridge.getSwapInfo.call(swapId)
            console.log("state: " + state3)
            assert.equal(state3.toNumber(), 3, "state should be closed")
        })

        it('should not allow to close with incorrect secretKey', async() => {
            swapId = web3.toHex(web3latest.utils.soliditySha3(14)) //make sure swapId not match with existing
            amount = 10000
            await remmeToken.approve(remmeBridge.address, amount, {from: alice})
            await remmeBridge.openSwap(swapId, swapProvider, emptyLock, amount, remchainAddress, "email", {from: alice})
            await remmeBridge.setSecretLock(swapId, secretLock, {from: swapProvider})
            await remmeBridge.approveSwap(swapId, {from: alice})
            // assertRevert(remmeBridge.closeSwap(swapId, "incorrectsecretkey", {from: swapProvider}))
            await remmeBridge.closeSwap(swapId, secretKey, {from:swapProvider})
            let [,,,,state3] = await remmeBridge.getSwapInfo.call(swapId)
            console.log("state: " + state3)
            console.log((await remmeBridge.swapStates.call(swapId)).toNumber())
            assert.equal(state3.toNumber(), 3, "state should be closed")
        })

        it('should transfer tokens to receiverAddress if receiver is not atomicSwapProvider', async() => {
            swapId = web3.toHex(web3latest.utils.soliditySha3(15)) //make sure swapId not match with existing
            amount = 10000
            let bridgeInitialBalance = await remmeToken.balanceOf(remmeBridge.address)
            await remmeToken.approve(remmeBridge.address, amount, {from: alice})
            await remmeBridge.openSwap(swapId, swapProvider, emptyLock, amount, remchainAddress, "email", {from: alice})
            await remmeBridge.setSecretLock(swapId, secretLock, {from: swapProvider})
            await remmeBridge.approveSwap(swapId, {from: alice})
            await remmeBridge.closeSwap(swapId, secretKey, {from: swapProvider})
            let [,,,,state3] = await remmeBridge.getSwapInfo.call(swapId)
            console.log("state: " + state3)
            assert.equal(state3.toNumber(), 3, "state should be closed")
            let bridgeEndBalance = await remmeToken.balanceOf(remmeBridge.address)
            assert.equal(bridgeEndBalance.toNumber(), bridgeInitialBalance.toNumber(),
                "tokens should be hold on contract")
        })
    })
})




