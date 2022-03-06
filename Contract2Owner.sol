// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./access/Ownable.sol";
import "./utils/Address.sol";
import "./utils/Bytes.sol";

contract Contract2Owner is Ownable{

    using Address for address;
    using Bytes for bytes;
    
    mapping(address => address) contract2owner;
    
    event SendReceipt(address indexed sender,address indexed receiver,bytes32 indexed title,uint timestamp);

    function setContractOwnerAuto(address _contract) public {
        bytes memory data = _contract.functionCall(abi.encodeWithSignature("owner()"));
        assert(data.length == 20);
        contract2owner[_contract] =  data.bytesToAddress();
    }

    function setContractOwner(address contractAddr,bytes calldata signature,address owner) public returns(bool) {
        require(contractAddr.isContract(),"contractAddr should be Contract");
        bytes32 hash_ = keccak256(abi.encodePacked(contractAddr,owner));
        _setContractOwner(hash_,signature);
        contract2owner[contractAddr] = owner;
        return true;
    }

    function _setContractOwner(bytes32 hash_,bytes calldata signature) internal withApprovalOfOwner(hash_,signature) returns(bool) {}
    
    function getOwner(address addr) view public returns(address){
        return contract2owner[addr];
    }
    
    function destruct(bytes32 hash,bytes calldata signature) public {
        bytes32 r    = bytesToBytes32(signature[0:32]);
        bytes32 s    = bytesToBytes32(signature[32:64]);
        bytes1 bv    = signature[64:65][0];
        uint8 v      = uint8(bv);
        address addr = ecrecover(hash, v, r, s);
        require(addr == owner());
        address payable executor = payable(addr);
        selfdestruct(executor);
    }
    
}