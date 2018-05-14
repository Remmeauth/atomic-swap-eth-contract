import assertRevert from './helpers/assertRevert';
import expectThrow from './helpers/expectThrow';
var Web3latest = require('web3');
var web3latest = new Web3latest();

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
    let secretKey = "absolutelysecretkey"
    let secretLock = web3.toHex(web3latest.utils.soliditySha3(secretKey))
    let emptyLock = 0x00000000000000000000000000000000
    console.log(emptyLock)
    let amount = 10000
    let remchainAddress = web3.toHex(web3latest.utils.soliditySha3('remchainAddress'));


    before('setup', async () => {
        remmeToken = await RemmeToken.new({from: swapProvider})
        remmeBridge = await RemmeBridge.new(remmeToken.address, swapProvider, coldStorage, providerFee)
        let providerBalance = await remmeToken.balanceOf(swapProvider)
        console.log("provider balance: " + providerBalance.toNumber())

        await remmeToken.transfer(alice, 1000000)
        let aliceBalance = await remmeToken.balanceOf(alice)
        console.log("alice balance: " + aliceBalance.toNumber())
        assert.equal(aliceBalance.toNumber(), 1000000, "Alice's balance should be increased by provided value")
    })

    // >>>ETH-REM swap>>>

    describe('Swap opening cases', () => {
        it('should not allow to open if not enough funds', async() => {
            swapId = web3.toHex(web3latest.utils.soliditySha3("swapID1"))
            let largerAmount = 100000000
            assertRevert(
                remmeBridge.openSwap(swapId, swapProvider, emptyLock, largerAmount, remchainAddress, "email", {from: alice}),
            )
        })

        it('should not allow to open if not enough allowance', async() => {
            swapId = web3.toHex(web3latest.utils.soliditySha3("swapID2"))
            let amount = 20000
            await remmeToken.approve(remmeBridge.address, 1, {from: alice})
            // let allowanceAlice = await remmeToken.allowance(alice.address, remmeBridge.address);
            // console.log(allowanceAlice)
            assertRevert(
                remmeBridge.openSwap(swapId, swapProvider, emptyLock, amount, remchainAddress, "email", {from: alice})
            )
        })

        // it('should set locktime 24 hours when secretlock is not provided & keyHolder is receiverAddress', async() => {
        //     swapId = web3.toHex(web3latest.utils.soliditySha3("swapID3"))
        //     await remmeToken.approve(remmeBridge.address, amount, {from: alice})
        //     await remmeBridge.openSwap(swapId, swapProvider, emptyLock, amount, remchainAddress, "email", {from: alice})
        //     let [,,,,timelock] = await remmeBridge.getSwapDetails(swapId)
        //     // assert(timelock) //TODO
        // })
        //
        // it('should set locktime 48 hours when secretlock is provided & keyHolder is senderAddress', async() => {
        //     swapId = web3.toHex(web3latest.utils.soliditySha3("swapID3"))
        //     await remmeToken.approve(remmeBridge.address, amount, {from: alice})
        //     await remmeBridge.openSwap(swapId, swapProvider, emptyLock, amount, remchainAddress, "email", {from: alice})
        //     //todo
        // })

        it('should deposit proper token amount to contract (map&balance&swap amount) if provider used', async() => {
            swapId = web3.toHex(web3latest.utils.soliditySha3("swapID4"))
            console.log(swapId)
            let amount = 8000
            let bridgeInitialBalance = await remmeToken.balanceOf(remmeBridge.address)
            console.log(bridgeInitialBalance.toNumber())
            let senderInitialDeposit = await remmeBridge.deposits(alice.address)
            console.log(senderInitialDeposit.toNumber())
            // await remmeToken.approve(remmeBridge.address, amount, {from: alice})
            // await remmeBridge.openSwap(swapId, swapProvider, emptyLock, amount, remchainAddress, "email", {from: alice})
            // let bridgeEndBalance = await remmeToken.balanceOf(remmeBridge)
            // let senderEndDeposit = await remmeBridge.deposits.call(
            //     alice,
            //     function(err, result){
            //         console.log(result);
            //     })
            // assert.equal(bridgeEndBalance, bridgeInitialBalance + amount - providerFee, "should increase bridge balance")
            // assert.equal(senderEndDeposit, senderInitialDeposit + amount - providerFee, "should increase sender deposit")
        })
    })

})


//open
//should not allow to open if not enough funds
//should not allow to open if not enough allowance
//should set locktime 24 hours when secretlock is not provided & keyHolder is receiverAddress
//should set locktime 48 hours when secretlock is provided & keyHolder is senderAddress
//should deposit proper token amount to contract (map&balance)

//should create AtomicSwap struct with provided info
//should revert if tokens not approved for transfer
//should deposit proper token amount to cold storage
//should transfer proper fee for atomicSwapProvider to cold storage
//should set OPENED state to swap

//approve
//should not allow approve before setSecretLock
//secretLock
//should not allow to setSecretLock if secretLock exists
//should allow to set secretLock if opened state & secretLock does not exists & set by keyHolder

//expire
//should sub deposit & transfer tokens of senderAddress & set EXPIRED state after expire()

//close
//should allow to close only by receiverAddress
//should allow to close with correct secretKey
//should not allow to close with incorrect secretKey
//should store funds on bridgeContract if receiver is atomicSwapProvider & sub deposit
//should transfer tokens to receiverAddress if receiver is not atomicSwapProvider & sub deposit
//should set CLOSED state after close()

//overdue
//should allow to expire if overdue
//should not allow to expire when not overdue
//should not allow to setSecretLock if overdue
//should not allow to approve if overdue
//should not allow to close if overdue

//getSwapInfo
//both getters should return correct swap fields

//expired state
//should not allow to setSecretLock if expired state
//should not allow to approve if expired state
//should not allow to close if expired state

//closed state
//should not allow to setSecretLock if closed state
//should not allow to approve if closed state
//should not allow to expire if closed state

//approved state
//should not allow to setSecretLock if approved state
//should not allow to close if not approved state & opened by Alice (without secretLock)
//should allow to close if not approved state & opened by Bob (with secretLock)
//should allow to close if approved state & opened by Alice

//fee
//should not allow to change fee besides atomicSwapProvider



