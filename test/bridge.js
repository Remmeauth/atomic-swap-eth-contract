import "zeppelin-solidity/test/helpers/assertRevert.js"
import assertRevert from "./helpers/assertRevert"

const RemmeToken = artifacts.require('RemmeTokenMock')
const RemmeBridge = artifacts.require('RemmeBridge')

contract ('RemmeBridge', accounts => {

    let remmeBridge;
    let remmeToken;
    let swapProvider = accounts[0]
    let alice = accounts[1]
    let coldStorage = accounts[2]
    let providerFee = 40000

    before('setup', async () => {
        remmeToken = await RemmeToken.deployed()
        assertEqual(remmeToken.balanceOf(swapProvider), remmeToken.totalSupply)
        remmeBridge = await RemmeBridge.deploy(remmeToken, swapProvider, coldStorage, providerFee)
        remmeToken.transfer(alice, 1000000)
        assertEqual(alice.balanceOf(alice), 10000000)
    })

    // >>>ETH-REM swap>>>

    it('openSwap function - should not allow to open if not enough funds', async() => {
        let secretKey = "absolutelysecretkey"
        let secretLock = web3.utils.toHex(web3.utils.keccak256(secretKey))
        let largeAmount = 100000000
        let remchainAddress = web3.utils.toHex(web3.utils.keccak256("remchainAddress"));
        assertRevert(open(swapProvider, secretLock, largeAmount, remchainAddress, "email", providerFee, {from: alice}))

    })
})


//open
//should not allow to open if not enough funds
//should set locktime 48 hours when secretlock is provided & keyHolder is senderAddress
//should set locktime 24 hours when secretlock is not provided & keyHolder is receiverAddress
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



