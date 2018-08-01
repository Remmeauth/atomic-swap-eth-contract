pragma solidity ^0.4.23;

import 'openzeppelin-solidity/contracts/math/SafeMath.sol';
import '../contracts/ERC20Interface.sol';

/* @title RemmeBridge
*  Contract, that allows to perform p2p exchange ERC20 REM tokens to native REM tokens
*/
contract RemmeBridge {

    struct AtomicSwap {
        bytes32 swapId;
        bytes32 secretLock;
        bytes32 secretKey;
        address senderAddress;
        address receiverAddress;
        address keyHolderAddress;
        uint256 amount;
        uint256 timelock;
        bytes remchainAddress;
        bytes emailAddressEncryptedOptional;
        State state;
    }

    enum State {
        EMPTY,
        OPENED,
        SECRETED,
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
	ERC20Interface REMToken; //= 0x83984d6142934bb535793A82ADB0a46EF0F66B6d;
	address atomicSwapProvider;
	address coldStorage;
	mapping(bytes32 => AtomicSwap) public swaps;
    uint256 public providerFee; //fee for provider work

    //EVENTS
    event OpenSwap(bytes32 indexed swapId);
    event ExpireSwap(bytes32 indexed swapId);
	event SetSecretLock(bytes32 indexed swapId);
    event ApproveSwap(bytes32 indexed swapId);
	event CloseSwap(bytes32 indexed swapId);

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
        require(swaps[_swapId].state == State.OPENED);
        _;
    }

    modifier onlySecretedState(bytes32 _swapId) {
        require(swaps[_swapId].state == State.SECRETED);
        _;
    }

    modifier onlyAtomicSwapProvider {
        require(msg.sender == atomicSwapProvider);
        _;
    }

    //CONSTRUCTOR
    constructor(address _tokenAddress, address _atomicSwapProvider, address _coldStorage, uint256 _providerFee) {
        REMToken = ERC20Interface(_tokenAddress);
        atomicSwapProvider = _atomicSwapProvider;
        coldStorage = _coldStorage;
        providerFee = _providerFee;
    }

    //FUNCTIONS
    /// @notice Get swap main info (addresses, state)
    function getSwapInfo(bytes32 _swapId) view returns (
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
        state = swap.state;
    }

    /// @notice Get swap details info
    function getSwapDetails(bytes32 _swapId) view returns (
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
	    require(swaps[_swapId].swapId == 0);

        //Bob always set as keyHolder
	    uint256 lock;
	    address keyHolder;
	    uint256 amountToSwap = _amount;
        if (_secretLock == bytes32(0)) {
            lock = now + LOCK24;
            keyHolder = _receiverAddress;
            if (_receiverAddress == atomicSwapProvider) {
                require(REMToken.transferFrom(msg.sender, coldStorage, providerFee));
	            amountToSwap = _amount.sub(providerFee);
            }
        } else {
            lock = now + LOCK48;
            keyHolder = msg.sender;
        }

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
            timelock: lock,
            state: State.OPENED
            });
        swaps[swap.swapId] = swap;

	    require(REMToken.transferFrom(msg.sender, address(this), amountToSwap));

        emit OpenSwap(swap.swapId);
    }

	/* @notice should be called after timelock
	*/
    function expireSwap(bytes32 _swapId) onlyOverdueSwap(_swapId) external {

        require(msg.sender == swaps[_swapId].senderAddress);
        require(swaps[_swapId].state == State.OPENED || swaps[_swapId].state == State.SECRETED || swaps[_swapId].state == State.APPROVED);

        AtomicSwap storage currentSwap = swaps[_swapId];
        REMToken.transfer(msg.sender, currentSwap.amount);

        currentSwap.state = State.EXPIRED;
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

        require(swaps[_swapId].secretLock == bytes32(0));
        require(msg.sender == swaps[_swapId].keyHolderAddress);
        require(_secretLock != bytes32(0));

        swaps[_swapId].secretLock = _secretLock;
        swaps[_swapId].state = State.SECRETED;
        emit SetSecretLock(_swapId);
    }

    /* @notice should be called only by Alice after setting lock
    */
    function approveSwap(bytes32 _swapId) onlyNotOverdueSwap(_swapId) onlySecretedState(_swapId) external payable {

        require(swaps[_swapId].secretLock != bytes32(0));
        require(msg.sender == swaps[_swapId].senderAddress);

        swaps[_swapId].state = State.APPROVED;
        emit ApproveSwap(_swapId);
    }

	/* @notice should be called with provided secret key
    */
    function closeSwap(bytes32 _swapId, bytes32 _secretKey) onlyNotOverdueSwap(_swapId) external {

        require(swaps[_swapId].secretLock != bytes32(0));
        require(msg.sender == swaps[_swapId].receiverAddress);

	    if (swaps[_swapId].senderAddress == swaps[_swapId].keyHolderAddress) {
		    require(swaps[_swapId].state == State.OPENED);
	    } else {
		    require(swaps[_swapId].state == State.APPROVED);
        }
        require(keccak256(_secretKey) == swaps[_swapId].secretLock);

	    AtomicSwap storage currentSwap = swaps[_swapId];
	    if (currentSwap.receiverAddress == atomicSwapProvider) {
            REMToken.transfer(coldStorage, currentSwap.amount);
	    } else {
            REMToken.transfer(currentSwap.receiverAddress, currentSwap.amount);
	    }
	    currentSwap.state = State.CLOSED;
	    emit CloseSwap(_swapId);
    }

    function setFee(uint256 amount) onlyAtomicSwapProvider {
        providerFee = amount;
    }
}