// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Bytes {

    function _uint2str(uint32 value) internal pure returns (bytes memory) {
        if (value == 0) return "0";
        uint32 temp = value;
        uint digits;
        while (temp != 0){
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0){
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + value % 10));
            value /= 10;
        }
        return buffer;
    }

    function _address2bytes(address a) internal pure returns (bytes memory b) {
        assembly {
            let m := mload(0x40)
            a := and(a, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            mstore(
                add(m, 20),
                xor(0x140000000000000000000000000000000000000000, a)
            )
            mstore(0x40, add(m, 52))
            b := m
        }
    }

    function bytesToAddress(bytes memory data) external pure returns (address addr) {
      assembly {
        addr := mload(add(data,20))
        }
    }

    function bytesToUint(bytes memory b) public pure returns (uint256){
        uint256 number;
        for(uint i= 0; i<b.length; i++){
            number = number + uint8(b[i])*(2**(8*(b.length-(i+1))));
        }
        return  number;
    }


    //bytes转换为bytes32
    function bytesToBytes32(bytes memory source) pure internal returns(bytes32 result){
        assembly{
            result :=mload(add(source,32))
        }
    }

}