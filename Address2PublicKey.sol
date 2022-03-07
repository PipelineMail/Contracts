// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./utils/Address.sol";
import "./access/Ownable.sol";

contract PubllicKey is Ownable{

    using Address for address;
    
    mapping(address => string) pubKeys;
    
    /*bytes encryptData;
    
    constructor(){
        encryptData = new bytes(72);
        bytes28 prefix = 0x19457468657265756d205369676e6564204d6573736167653a0a3434;
        for(uint i=0;i<prefix.length;i++){
            encryptData[i] = prefix[i];
        }
    }
    //This way cost more gas.
    function storePubKey(string memory _pubKey,bytes calldata signature,address _keyOwner) public returns(bool){
        bytes memory pubKey = bytes(_pubKey);
        bytes memory _encryptData = encryptData;
        for(uint i=0;i<pubKey.length;i++){
            _encryptData[i+28] = pubKey[i];
        }
        bytes32 hash = keccak256(_encryptData);
        bytes32 r    = bytesToBytes32(signature[0:32]);
        bytes32 s    = bytesToBytes32(signature[32:64]);
        bytes1 bv    = signature[64:65][0];
        uint8 v      = uint8(bv);
        address addr=ecrecover(hash, v, r, s);
        assert(_keyOwner == addr);
        pubKeys[addr] = _pubKey;
        return true;
    }*/
    function storePubKey(bytes calldata _pubKey,bytes calldata signature,address _keyOwner) public returns(bool){
        bytes32 hash = keccak256(_pubKey);
        bytes32 r    = bytesToBytes32(signature[0:32]);
        bytes32 s    = bytesToBytes32(signature[32:64]);
        bytes1 bv    = signature[64:65][0];
        uint8 v      = uint8(bv);
        address addr=ecrecover(hash, v, r, s);
        assert(_keyOwner == addr);
        bytes memory pubKey = _pubKey[28:_pubKey.length];
        pubKeys[addr] = string(pubKey);
        return true;
    }
    
    function getPublicKey(address addr) view public returns(string memory){
        if(addr.isContract()) {

        }
        return pubKeys[addr];
    }
    
    function destruct(bytes32 hash,bytes calldata signature) public {
        bytes32 r    = bytesToBytes32(signature[0:32]);
        bytes32 s    = bytesToBytes32(signature[32:64]);
        bytes1 bv    = signature[64:65][0];
        uint8 v      = uint8(bv);
        address addr=ecrecover(hash, v, r, s);
        require(addr == owner());
        address payable executor = payable(addr);
        selfdestruct(executor);
    }
    
}
