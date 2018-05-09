pragma solidity ^0.4.21;

import 'openzeppelin-solidity/contracts/math/SafeMath.sol';
import '../contracts/ERC20Interface.sol';

/* @title RemmeBridge
*  Contract, that allows to perform p2p exchange Ethereum REM tokens to native REM tokens
*/
contract RemmeBridge {

    struct AtomicSwap {
        bytes32 swapId;
        address senderAddress;
        address receiverAddress;
        address keyHolderAddress; //Bob's address
        bytes remchainAddress; //provided remchain address
        uint256 amount; //amount for swap, which will be locked
        bytes emailAddressEncryptedOptional; //optional argument with encrypted email for swap continiue notification
        bytes32 secretLock; //hash of key, that used for locking funds
        bytes32 secretKey; //key used on both chains for unlocking funds
        uint256 timelock; //time from which is allowed swap expiration
    }

    enum State {
        OPENED,
        APPROVED,
        CLOSED,
        EXPIRED
    }

	//LIBRARIES
	using SafeMath for uint256;

    //CONSTANTS
    uint256 constant LOCK24 = 86400; //seconds in 24h
    uint256 constant LOCK48 = 172800; //seconds in 48h

    //VARIABLES
    // fixme do we need to delete closed and expired swaps for cleaning up storage?
	// fixme do we need match swaps in remme and ethereum? (suggestion to use simple id in ascending order)
	ERC20Interface REMToken; //= 0x83984d6142934bb535793A82ADB0a46EF0F66B6d;
	address atomicSwapProvider;
	address coldStorage;
	mapping(bytes32 => AtomicSwap) public swaps;
    mapping (bytes32 => State) public swapStates; // mapping with states of each swap
	mapping (address => uint256) public deposits; // user deposits
    uint256 public providerFee; //fee for provider work

    //EVENTS
    event OpenSwap(bytes32 _swapId);
    event ExpireSwap(bytes32 _swapId);
	event SetSecretLock(bytes32 _swapId);
    event ApproveSwap(bytes32 _swapId);
	event CloseSwap(bytes32 _swapId);

    //MODIFIERS
    modifier onlyOverdueSwap(bytes32 _swapId) {
        require(now >= swaps[_swapId].timelock);
        _;
    }

    modifier onlyNotOverdueSwap(bytes32 _swapId) {
        require(now < swaps[_swapId].timelock);
        _;
    }

    modifier onlyOpenedState(bytes32 _swapId) {
        require(swapStates[_swapId] == State.OPENED);
        _;
    }

    modifier onlyAtomicSwapProvider {
        require(msg.sender == atomicSwapProvider);
        _;
    }

    //CONSTRUCTOR
    function RemmeBridge(ERC20Interface _token, address _atomicSwapProvider, address _coldStorage, uint256 _providerFee) {
        REMToken = _token;
        atomicSwapProvider = _atomicSwapProvider;
        coldStorage = _coldStorage;
        providerFee = _providerFee;
    }

    //FUNCTIONS
    /// @notice Get swap main info (addresses, state)
    function getSwapInfo(bytes32 _swapId) returns (
        address sender,
        address receiver,
        address keyHolder,
        bytes remChainAddress,
        State state)
    {
        AtomicSwap storage swap = swaps[_swapId];
        sender = swap.senderAddress;
        receiver = swap.receiverAddress;
        keyHolder = swap.keyHolderAddress;
        remChainAddress = swap.remchainAddress;
        state = swapStates[_swapId];
    }

    /// @notice Get swap details info
    function getSwapDetails(bytes32 _swapId) returns (
        uint amount,
        bytes emailEncrypted,
        bytes32 secretLock,
        bytes32 secretKey,
        uint timelock)
    {
	    AtomicSwap storage swap = swaps[_swapId];
        amount = swap.amount;
        emailEncrypted = swap.emailAddressEncryptedOptional;
        secretLock = swap.secretLock;
        secretKey = swap.secretKey;
        timelock = swap.timelock;
    }

    /*
	* @notice User should use this function for request swap locking his tokens
	* @dev There are two cases of using this function:
	* 1) Alice requests swap and don't put _secretLock argument, and sends ether
	*    required by atomicSwapProvider for gas coverage
	* 2) Bob opens swap after Alice's request in Remmechain and set _secretLock
	* @param _secretLock (!) will be set only by Bob. Should be checked in client side during validation
    */
    function openSwap (
        bytes32 _swapId,
        address _receiverAddress,
        bytes32 _secretLock,
        uint256 _amount,
        bytes _remchainAddress,
        bytes _emailAddressEncryptedOptional)
    external
    {
	    //swapId shouldn't exist
	    require(swaps[_swapId].swapId == 0);

        //set timelock 24h in case user request eth-rem swap (Alice - without key) otherwise (Bob) set 48h
        //Bob always set as keyHolder
	    uint256 lock;
	    address keyHolder;
        if (_secretLock == bytes32(0)) {
            lock = now + LOCK24;
            keyHolder = _receiverAddress;
            //get fee if used atomicSwapProvider
            if (_receiverAddress == atomicSwapProvider) {
                require(REMToken.transferFrom(msg.sender, coldStorage, providerFee));
            }
        } else {
            lock = now + LOCK48;
            keyHolder = msg.sender;
        }

        //create and save new swap
	    uint256 amountToSwap = _amount - providerFee;
	    AtomicSwap memory swap = AtomicSwap({
            swapId: _swapId,
            senderAddress: msg.sender,
            receiverAddress: _receiverAddress,
            keyHolderAddress: keyHolder,
            remchainAddress: _remchainAddress,
            amount: amountToSwap,
            emailAddressEncryptedOptional: _emailAddressEncryptedOptional,
            secretLock: _secretLock,
            secretKey: "", //will be set only on closing swap
            timelock: lock
            });
        swaps[swap.swapId] = swap;

        //deposit tokens
		require(REMToken.transferFrom(msg.sender, address(this), amountToSwap));
        deposits[msg.sender] = amountToSwap;

        //set state
        swapStates[swap.swapId] = State.OPENED;
        emit OpenSwap(swap.swapId);
    }

    function expireSwap(bytes32 _swapId) onlyOverdueSwap(_swapId) external {

        //check that swap opened by msg.sender
        require(msg.sender == swaps[_swapId].senderAddress);
        //check that swap still opened or approved
        require(swapStates[_swapId] == State.OPENED || swapStates[_swapId] == State.APPROVED);

        AtomicSwap storage currentSwap = swaps[_swapId];

        //withdraw funds
        deposits[msg.sender] = deposits[msg.sender].sub(currentSwap.amount);
        REMToken.transfer(msg.sender, currentSwap.amount);

        swapStates[_swapId] = State.EXPIRED;
        emit ExpireSwap(_swapId);
    }

    /* @notice should be called only by Bob after opening swap by Alice, otherwise
    *  secretLock was set in openSwap()
    *  @param _secretLock secretKey hashed by Bob
    */
    function setSecretLock(bytes32 _swapId, bytes32 _secretLock)
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

    /* @notice should be called only by Alice after setting lock
    */
    function approveSwap(bytes32 _swapId) onlyNotOverdueSwap(_swapId) onlyOpenedState(_swapId) external payable {

        //check that secret lock is set
        require(swaps[_swapId].secretLock != bytes32(0));
        //check that swap is approving not by keyHolder
        require(msg.sender != swaps[_swapId].keyHolderAddress);

        swapStates[_swapId] = State.APPROVED;
        emit ApproveSwap(_swapId);
    }

    function closeSwap(bytes32 _swapId, bytes _secretKey) onlyNotOverdueSwap(_swapId) external {

		//check that swap is closing by receiverAddress
        require(msg.sender == swaps[_swapId].receiverAddress);

	    //require approval only if swap opened by Alice
	    if (swaps[_swapId].senderAddress != swaps[_swapId].keyHolderAddress) {
		    require(swapStates[_swapId] == State.APPROVED);
	    } else {
            require(swapStates[_swapId] == State.OPENED);
        }
	    //check provided secret key
        require(keccak256(_secretKey) == swaps[_swapId].secretLock);

	    AtomicSwap storage currentSwap = swaps[_swapId];

	    // withdraw funds
	    deposits[currentSwap.senderAddress] = deposits[currentSwap.senderAddress].sub(currentSwap.amount);
        // transfer to receiver address
	    if (currentSwap.receiverAddress == atomicSwapProvider) {
            REMToken.transfer(coldStorage, currentSwap.amount);
	    } else {
            REMToken.transfer(currentSwap.receiverAddress, currentSwap.amount);
	    }

	    swapStates[_swapId] == State.CLOSED;
	    emit CloseSwap(_swapId);
    }

    function setFee(uint256 amount) onlyAtomicSwapProvider {
        providerFee = amount;
    }
}