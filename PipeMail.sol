// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./utils/Bytes.sol";
import "./utils/Address.sol";
import "./access/Ownable.sol";
import "./token/ERC20/IERC20.sol";
import "./token/ERC721/IERC721.sol";
import "./token/ERC1155/IERC1155.sol";
import "./token/ERC20/utils/SafeERC20.sol";

contract PipelineMail is Ownable {

    using Bytes for *;
    using Address for address;
    using SafeERC20 for IERC20;

    bytes constant version = "beta";

    //userIndex[ADDRESS][0]:sender amount
    //userIndex[ADDRESS][1]:receive amount
    mapping(address => uint32[2]) userIndex;

    mapping(address => address) contractUser;

    uint256 amount;

    address public contract2owner;

    address public address2publicKey;

    event SendMail(bytes32 indexed sender,bytes32 indexed receiver,bytes32 mailHash,address stampContract,uint256 stampId,bool assert);

    struct _ERC20 {
        address addr;
        uint256 amount;
    }

    struct _ERC721 {
        address addr;
        uint256 id;
        bytes data;
    }

    struct _ERC1155 {
        address addr;
        uint256[] ids;
        uint256[] amounts;
        bytes data;
    }

    constructor(address contract2owner_,address address2publicKey_) Ownable() {
        require(contract2owner_.isContract(),"contract2owner should be Contract");
        require(address2publicKey_.isContract(),"address2publicKey should be Contract");
        contract2owner = contract2owner_;
        address2publicKey = address2publicKey_;
    }

    function Send(address receiver,bytes32 mailHash,address stampContract,uint256 stampId,_ERC20[] memory erc20s,_ERC721[] memory erc721s,_ERC1155[] memory erc1155s) public payable{
        address sender = _msgSender();
        _Send(sender,receiver,mailHash,stampContract,stampId,erc20s,erc721s,erc1155s);
    }

    function _Send(address sender,address receiver,bytes32 mailHash,address stampContract,uint256 stampId,_ERC20[] memory erc20s,_ERC721[] memory erc721s,_ERC1155[] memory erc1155s) internal{
        uint32[2] storage senderIndex = userIndex[sender];
        uint32[2] storage receiverIndex = userIndex[receiver];
        require(senderIndex[0] + 1 > senderIndex[0]);
        require(receiverIndex[1] + 1 > receiverIndex[1]);
        require(amount + 1 > amount);
        senderIndex[0] += 1;
        receiverIndex[1] += 1;
        amount += 1;
        if(_msgValue() != 0) {
            _transferEther(receiver);
        }
        if(erc20s.length !=0 ){
            _transferERC20(erc20s,receiver);
        }
        if(erc721s.length !=0 ){
            _transferERC721(erc721s,receiver);
        }
        if(erc1155s.length !=0 ){
            _transferERC1155(erc1155s,receiver);
        }
        emit SendMail(_userIndex(sender,senderIndex[0]),_userIndex(receiver,receiverIndex[1]),mailHash,stampContract,stampId,false);
    }

    function _getDappOwner(address dappAddr) internal returns(address){
        require(dappAddr.isContract(),"contractAddr should be Contract");
        bytes memory data = contract2owner.functionCall(abi.encodeWithSignature("getOwner(address)",dappAddr));
        assert(data.length == 20);
        address owner_ = data.bytesToAddress();
        assert(owner_ == _msgSender());
        return owner_;
    }

    function UserSendAmount(address user) view public returns (uint32) {
        return userIndex[user][0];
    }

    function UserReceiveAmount(address user) view public returns (uint32) {
        return userIndex[user][1];
    }

    function Version() pure public returns(string memory) {
        return string(version);
    }

    function _transferEther(address to_) internal {
        address payable _to = payable(to_);
        _to.transfer(msg.value);
    }

    function _transferERC20(_ERC20[] memory erc20s,address to) internal {
        for(uint8 i; i < erc20s.length; ++i) {
            IERC20 token = IERC20(erc20s[i].addr);
            token.safeTransferFrom(msg.sender,to,erc20s[i].amount);
        }
    }

    function _transferERC721(_ERC721[] memory erc721s,address to) internal {
        for(uint8 i; i < erc721s.length; ++i) {
            IERC721 token = IERC721(erc721s[i].addr);
            token.safeTransferFrom(msg.sender,to,erc721s[i].id,erc721s[i].data);
        }
    }

    function _transferERC1155(_ERC1155[] memory erc1155s,address to) internal {
        for(uint8 i; i < erc1155s.length; ++i) {
            IERC1155 token = IERC1155(erc1155s[i].addr);
            token.safeBatchTransferFrom(msg.sender,to,erc1155s[i].ids,erc1155s[i].amounts,erc1155s[i].data);
        }
    }
}