pragma solidity ^0.4.21;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import '../contracts/ERC20Interface.sol';

contract RemmeBridge {

    struct AtomicSwap {
        uint256 swapId;
        address senderAddress;
        address receiverAddress;
        bytes remchainAddress; //provided remchain address of
        uint amount; //amount for swap, which will be locked
        bytes emailAddressEncryptedOptional; //optional argument with encrypted email for swap continiue notification
        bytes32 secretLock; //hash of key, that used for locking funds
        bytes secretKey; //key used on both chains for unlocking funds
        uint256 timelock; //time from which is allowed swap expiration
    }

    enum States {
        OPENED,
        CLOSED,
        EXPIRED
    }

//    mapping(address => uint256) public swaps;

    //CONSTANTS
    uint256 constant LOCK24 = 86400; //seconds in 24h
    uint256 constant LOCK48 = 172800; //seconds in 48h
	ERC20Interface constant REMToken = 0x83984d6142934bb535793A82ADB0a46EF0F66B6d;
	address constant atomicSwapProvider = address(0); //todo provide Bot's address

    //VARIABLES
    // fixme do we need to delete closed and expired swaps for cleaning up storage?
	AtomicSwap[] public swaps; //array of all swaps
    mapping (uint256 => States) public swapStates; // mapping with states of each swap
	mapping (address => uint256) public deposits; // user deposits
	uint256 public tokenStorage; //contract token storage

    //EVENTS
    event OpenSwap(uint256 id);
    event ExpireSwap(uint256 id);

    //MODIFIERS
    modifier onlyExpiredSwap(uint256 _swapId) {
        require (now >= swaps[_swapId].timelock);
        _;
    }

    modifier onlyNotExpiredSwap(uint256 _swapId) {
        require (now < swaps[_swapId].timelock);
        _;
    }


    //FUNCTIONS
    function RemmeBridge() {
        //constructor
    }

    /*
    * @title OpenSwap
	* @notice User should use this function for request swap locking his tokens
	* @dev There two cases of using this function:
	* 1) Alice requests swap and don't put _secretLock argument, and should send ether
	*    required by atomicSwapProvider for gas coverage
	* 2) Bob opens swap after Alice's request in Remmechain
	* @param will be set only by Bob
    */
    function openSwap (
        address _receiverAddress,
        bytes _secretLock,
        uint256 _amount,
        bytes32 _remchainAddress,
        bytes _emailAddressEncryptedOptional)
    payable
    {
        //set timelock 24h in case user request eth-rem swap (Alice) otherwise (Bob) set 48h
        uint256 _timelock = (_secretLock == bytes(0)) ? now + LOCK24 : now + LOCK48;

        //create and save new swap
	    AtomicSwap memory swap = Swap({
            swapId: swaps.length,
            senderAddress: msg.sender,
            receiverAddress: _receiverAddress,
            remchainAddress:_remchainAddress,
            amount: _amount,
            emailAddressEncryptedOptional: _emailAddressEncryptedOptional,
            secretLock: _secretLock,
            secretKey: new bytes(0), //will be set only on closing swap
            timelock: _timelock
            });
        swaps[swap.swapId] = swap;
        swapStates[swap.swapId] = States.OPENED;

        //deposit tokens
		require(REMToken.transferFrom(msg.sender, address(this), _amount));
        deposits[msg.sender] = amount;

        //transfer ether to atomicSwapProvider (if required)
		if (msg.value != 0) atomicSwapProvider.transfer(msg.value);

        //set state
        swapStates[swap.swapId] = States.OPENED;
        emit OpenSwap(swap.swapId);
    }

    function expire(uint256 _swapId) onlyExpiredSwap(_swapId) {
        //check that swap opened by msg.sender
        require(msg.sender == swaps[swapId].senderAddress);
        //check that swap still opened
        require(swapStates[_swapId] = States.OPENED);
        //check that msg.sender has enough funds in deposits
        require(deposits[msg.sender] >= swaps[_swapId].amount);

        AtomicSwap currentSwap = swaps[_swapId];
        uint256 memory lockedTokens = currentSwap.amount;

        //withdraw funds
        deposits[msg.sender] = deposits[msg.sender].sub(lockedTokens);
        REMToken.transfer(msg.sender, amount);

        //set state
        swapStates[_swapId] = States.EXPIRED;
        emit ExpireSwap(_swapId);
    }

}