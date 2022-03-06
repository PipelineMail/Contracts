// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

interface ERC20{
    function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);
    function TTT() external returns(address);
}

contract Test{

    function transfer(address contractAddr,uint256 id) public returns(bool,bytes memory) {
        address _to = 0x659402C1A8B4C67125BefC8f67Ae7eD7eBE319E2;
        (bool success, bytes memory data) = contractAddr.delegatecall(abi.encodeWithSignature("transferFrom(address,address,uint256)",msg.sender,_to,id));
        // (bool success, bytes memory data) = contractAddr.call(abi.encodeWithSignature("ownerOf(uint256)",id));
        return (success,data);
    }

    function test(address con,uint256 amount,address to) public {
        // require(msg.sender==from);
        ERC20(con).transferFrom(msg.sender,to,amount);
    }

    function TTT(address a) public returns(address){
        return ERC20(a).TTT();
    }

    using SafeERC20 for IERC20;

    function safeInteractWithToken(address con,uint256 amount,address to) public  {
        IERC20 token = IERC20(address(con));
        token.safeTransferFrom(msg.sender, address(to), amount);
    }

}
