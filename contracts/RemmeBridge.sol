pragma solidity ^0.4.21;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import './contracts/ERC20Interface.sol';

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


}