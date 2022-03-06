// contracts/GameItems.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./token/ERC1155/ERC1155.sol";
import "./access/Ownable.sol";

contract GameItems is ERC1155 {
    uint256 public constant GOLD = 0;
    uint256 public constant SILVER = 1;
    uint256 public constant THORS_HAMMER = 2;
    uint256 public constant SWORD = 3;
    uint256 public constant SHIELD = 4;

    constructor(address caller_) ERC1155(caller_) {
        _mint(msg.sender, 10**18, 123456789,1,0x05138716c6cf1f86890bf4d218ce6ad6091817bc3f9a5d85bd86401519e993e1,3,"");
        _mint(msg.sender, 10**27, 223456789,2,0x05138716c6cf1f86890bf4d218ce6ad6091817bc3f9a5d85bd86401519e993e1,3,"");
        _mint(msg.sender, 1, 323456789,3,0x05138716c6cf1f86890bf4d218ce6ad6091817bc3f9a5d85bd86401519e993e1,3,"");
        _mint(msg.sender, 10**9, 423456789,4,0x05138716c6cf1f86890bf4d218ce6ad6091817bc3f9a5d85bd86401519e993e1,3,"");
        _mint(msg.sender, 10**9, 523456789,5,0x05138716c6cf1f86890bf4d218ce6ad6091817bc3f9a5d85bd86401519e993e1,3,"");
    }
}