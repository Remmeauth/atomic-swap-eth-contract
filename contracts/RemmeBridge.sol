pragma solidity ^0.4.21;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import '../contracts/ERC20Interface.sol';

/* @title RemmeBridge
*  <description>
*/
contract RemmeBridge {

    struct AtomicSwap {
        uint256 swapId;
        address senderAddress;
        address receiverAddress;
        address keyHolderAddress;
        bytes remchainAddress; //provided remchain address of
        uint amount; //amount for swap, which will be locked
        bytes emailAddressEncryptedOptional; //optional argument with encrypted email for swap continiue notification
        bytes32 secretLock; //hash of key, that used for locking funds
        bytes secretKey; //key used on both chains for unlocking funds
        uint256 timelock; //time from which is allowed swap expiration
    }

    enum State {
        OPENED,
        APPROVED,
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
    mapping (uint256 => State) public swapStates; // mapping with states of each swap
	mapping (address => uint256) public deposits; // user deposits
	uint public tokenStorage; //contract token storage

    //EVENTS
    event OpenSwap(uint256 id);
    event ExpireSwap(uint256 id);
    event ApproveSwap(uint256 id);
    event SetSecretLock(uint256 id);

    //MODIFIERS
    modifier onlyOverdueSwap(uint256 _swapId) {
        require(now >= swaps[_swapId].timelock);
        _;
    }

    modifier onlyNotOverdueSwap(uint256 _swapId) {
        require(now < swaps[_swapId].timelock);
        _;
    }

    modifier onlyOpenedState(uint256 _swapId) {
        require(swapStates[_swapId] == State.OPENED);
        _;
    }

	modifier onlyApprovedState(uint256 _swapId) {
		require(swapStates[_swapId] == State.APPROVED);
		_;
	}



    //FUNCTIONS
    function RemmeBridge() {
        //constructor
    }

    /*
	* @notice User should use this function for request swap locking his tokens
	* @dev There two cases of using this function:
	* 1) Alice requests swap and don't put _secretLock argument, and sends ether
	*    required by atomicSwapProvider for gas coverage
	* 2) Bob opens swap after Alice's request in Remmechain
	* @param _secretLock will be set only by Bob. Should be checked in client side during validation
    */
    function openSwap (
        //todo create separate function for initSwap() where receiverAddress will be set as msg.sender an so on
        address _receiverAddress,
        bytes32 _secretLock,
        uint256 _amount,
        bytes32 _remchainAddress,
        bytes _emailAddressEncryptedOptional)
    external
    payable
    {
        //set timelock 24h in case user request eth-rem swap (Alice) otherwise (Bob) set 48h
        //Bob set as keyHolder
        if (_secretLock == bytes32(0)) {
            uint256 lock = now + LOCK24;
            address keyHolder = _receiverAddress;
        } else {
            uint256 lock = now + LOCK48;
            address keyHolder = msg.sender;
        }

        //create and save new swap
	    AtomicSwap memory swap = Swap({
            swapId: swaps.length,
            senderAddress: msg.sender,
            receiverAddress: _receiverAddress,
            keyHolderAddress: keyHolder,
            remchainAddress:_remchainAddress,
            amount: _amount,
            emailAddressEncryptedOptional: _emailAddressEncryptedOptional,
            secretLock: _secretLock,
            secretKey: new bytes(0), //will be set only on closing swap
            timelock: lock
            });
        swaps[swap.swapId] = swap;

        //deposit tokens
		require(REMToken.transferFrom(msg.sender, address(this), _amount));
        deposits[msg.sender] = amount;

        //transfer ether to atomicSwapProvider (if required)
		if (msg.value != 0) atomicSwapProvider.transfer(msg.value);

        //set state
        swapStates[swap.swapId] = State.OPENED;
        emit OpenSwap(swap.swapId);
    }

    function expireSwap(uint256 _swapId) onlyOverdueSwap(_swapId) external {

        //check that swap opened by msg.sender
        require(msg.sender == swaps[swapId].senderAddress);
        //check that swap still opened or approved
        require(swapStates[_swapId] == State.OPENED || State.APPROVED);
        //check that msg.sender has enough funds in deposits
        require(deposits[msg.sender] >= swaps[_swapId].amount);

        AtomicSwap currentSwap = swaps[_swapId];
        uint256 memory lockedTokens = currentSwap.amount;

        //withdraw funds
        deposits[msg.sender] = deposits[msg.sender].sub(lockedTokens);
        REMToken.transfer(msg.sender, amount);

        swapStates[_swapId] = State.EXPIRED;
        emit ExpireSwap(_swapId);
    }

    /* @notice should be called only by Bob after opening swap by Alice, otherwise
    *  secretLock was set in openSwap()
    *  @param _secretLock secretKey hashed by Bob
    */
    function setSecretLock(uint256 _swapId, bytes32 _secretLock)
    onlyNotOverdueSwap(_swapId)
    onlyOpenedState(_swapId)
    external {

        //check that secretLock will set by keyHolder
        require(msg.sender == swaps[_swapId].keyHolderAddress);
        //check that secretLock exists
        require(_secretLock != bytes32(0));

        //set secretLock
        swaps[_swapId].secretLock = _secretLock;

        emit SetSecretLock(_swapId);
    }

    /* @notice should be called only by Alice after setting key
    */
    function approveSwap(uint256 _swapId) onlyNotOverdueSwap(_swapId) onlyOpenedState(_swapId) external payable {

        //check that secret lock is set
        require(swaps[_swapId].secretLock != bytes32(0));
        //check that swap is approving not by keyHolder
        require(msg.sender != swaps[_swapId].keyHolderAddress);

        swapStates[_swapId] = State.APPROVED;
        emit ApproveSwap(_swapId);
    }

    function closeSwap(uint256 _swapId, bytes _secretKey)
    onlyNotOverdueSwap(_swapId)
	onlyApprovedState(_swapId)
	external {

		//check that swap is closing by keyHolder
	    //check provided secret key
	    // withdraw funds
	    //set state
	    //emit event

    }


}