// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC1155/ERC1155.sol)

pragma solidity ^0.8.0;

import "./IERC1155.sol";
import "./IERC1155Receiver.sol";
import "./extensions/IERC1155MetadataURI.sol";
import "../../utils/Address.sol";
import "../../utils/Context.sol";
import "../../utils/introspection/ERC165.sol";
import "../../access/Ownable.sol";

/**
 * @dev Implementation of the basic standard multi-token.
 * See https://eips.ethereum.org/EIPS/eip-1155
 * Originally based on code by Enjin: https://github.com/enjin/erc-1155
 *
 * _Available since v3.1._
 */
contract ERC1155 is Context, ERC165, IERC1155, IERC1155MetadataURI, Ownable {
    using Address for address;

    uint8 private _used = 0;
    uint8 private _unused = 1;

    struct BaseData {
        uint256 price;
        uint8 saveType;
        bytes32 uri;
        uint8 usedForNew;
    }

    // Mapping from token ID to account used-balances
    mapping(uint256 => BaseData) private _baseData;

    // Mapping from token ID to account balances. balances[0] is usedBalances,and balances[1] is unusedBalances.
    mapping(uint256 => mapping(address => uint256[2])) private _balances;

    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Start index is 1
    uint256 private _currentId;

    address private _caller;

    /**
     * @dev See {_setURI}.
     */
    constructor(address caller_) {
        _setCaller(caller_);
    }

    receive() external payable {}

    function tempUsedBalanceForTest(address user,uint256 id,uint256 amount,uint8 ifUsed) public {
        _balances[id][user][ifUsed] += amount;
    }

    function etherBalance() public view onlyOwner returns(uint256) {
        return address(this).balance;
    }

    function buy(address to,uint256 id,uint256 amount) payable public {
        uint256 newWorth = _newWorth(id,amount);
        assert(_msgValue()>=newWorth);
        address payable _this = payable(this);
        _this.transfer(_msgValue());
        _balances[id][to][_unused] += amount;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     *
     * This implementation returns the same URI for *all* token types. It relies
     * on the token type ID substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * Clients calling this function must replace the `\{id\}` substring with the
     * actual token type ID.
     */
    function uri(uint256 id) public view override returns (uint8,bytes32) {
        return (_baseData[id].saveType,_baseData[id].uri);
    }

    function caller() public view onlyOwner returns (address) {
        return _caller;
    }

    function _setCaller(address caller_) internal onlyOwner{
        _caller = caller_;
    }

    function price(uint256 id) public view returns(uint256) {
        return _baseData[id].price;
    }

    function _price(uint256 id) internal view returns(uint256) {
        return _baseData[id].saveType!=0?_baseData[id].price:2**256-1;
    }

    function setPrice(uint256 id,uint256 price_) public onlyOwner {
        require(_baseData[id].saveType!=0,"This stamp is not exist");
        _baseData[id].price = price_;
    }

    function usedForNewSingle(address from_,uint256 usedId,uint256 usedAmount,uint256 newId,uint256 newAmount,bool flexibly,address to_) public {
        require(from_ == _msgSender() || isApprovedForAll(from_,_msgSender()),"ERC1155 caller is not owner nor approved");
        require(to_ != address(0), "ERC1155: mint to the zero address");
        uint256 usedWorth = _usedWorth(usedId,usedAmount);
        uint256 newWorth = _newWorth(newId,newAmount);
        if(!flexibly){
            assert(usedWorth>=newWorth);
        }else{
            newAmount = usedWorth>=newWorth?newAmount:usedWorth/_baseData[newId].price;
        }
        _safeTransferFrom(from_,owner(),usedId,usedAmount,_ifUsed(_used));
        _safeTransferFrom(owner(),to_,newId,newAmount,_ifUsed(_unused));
    }

    function usedForNewMulti(address[] memory froms,uint256[] memory usedIds,uint256[] memory usedAmounts,uint256[] memory newIds,uint256[] memory newAmounts,bool flexibly,address to) public {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(froms.length==usedIds.length||froms.length==1,"ERC1155:from is necessary");
        require(usedIds.length == usedAmounts.length, "ERC1155: ids and amounts length mismatch");
        require(usedIds.length != 0, "ERC1155: ids and amounts length mismatch");
        require(newIds.length == newAmounts.length, "ERC1155: amounts and prices length mismatch");
        require(newIds.length != 0, "ERC1155: amounts and prices length mismatch");
        uint256 usedWorth;
        uint256 newWorth;
        for(uint8 i; i < usedIds.length; ++i) {
            address from_ = froms.length==1?froms[0]:froms[i];
            require(from_ == _msgSender() || isApprovedForAll(from_,_msgSender()),"ERC1155 caller is not owner nor approved");
            usedWorth += _usedWorth(usedIds[i],usedAmounts[i]);
            _safeTransferFrom(from_,owner(),usedIds[i],usedAmounts[i],_ifUsed(_used));
        }
        for(uint8 i; i < newIds.length; ++i) {
            newWorth += _newWorth(newIds[i],newAmounts[i]);
        }
        if(!flexibly){
            assert(usedWorth>=newWorth);
        }else{
            if(usedWorth<newWorth) {
                uint256 _tempId = newAmounts[0];
                newIds = new uint256[](1);
                newIds[0] = _tempId;
                newAmounts = new uint256[](1);
                newAmounts[0] = usedWorth/_price(_tempId);
            }
        }
        _safeBatchTransferFrom(owner(),to,newIds,newAmounts,_ifUsed(_unused));

    }

    function _ifUsed(uint8 _flag) internal pure returns(bytes memory){
            bytes memory _data = new bytes(1);
        if(_flag==0){
            _data[0] = 0x00;
        }else {
            _data[0] = 0x01;
        }
        return _data;
    }

    function _usedWorth(uint256 usedId,uint256 usedAmount) internal view returns(uint256){
        require(_baseData[usedId].saveType!=0,"This stamp is not exist");
        require(usedAmount!=0,"ERC1155: usedAmount can not be zero");
        // uint256 usedWorth = usedId * usedAmount;
        return _baseData[usedId].price * usedAmount / _baseData[usedId].usedForNew;
    }

    function _newWorth(uint256 newId,uint256 newAmount) internal view returns(uint256){
        require(_baseData[newId].saveType!=0,"This stamp is not exist");
        return _baseData[newId].price * newAmount;
    }

    /**
     * @dev See {IERC1155-balanceOf}.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) public view override returns (uint256) {
        require(account != address(0), "ERC1155: balance query for the zero address");
        return _balances[id][account][_used]+_balances[id][account][_unused];
    }

    /**
     * @dev See {IERC1155-balanceOfBatch}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        override
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(address account, address operator) public view override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: transfer caller is not owner nor approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal {
        require(to != address(0), "ERC1155: transfer to the zero address");
        require(data.length == 1, "ERC1155: data is too long");
        address operator = _msgSender();
        uint8 ifUsed = uint8(data[0]);

        _beforeTokenTransfer(operator, from, to, _asSingletonArray(id), _asSingletonArray(amount), data);
        

        uint256 fromBalance = _balances[id][from][ifUsed];
        require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
        unchecked {
            _balances[id][from][ifUsed] = fromBalance - amount;
        }
        _balances[id][to][ifUsed] += amount;

        // emit TransferSingle(operator, from, to, id, amount,ifUsed);
        emit TransferSingle(operator, from, to, id, amount);

        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal {
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(to != address(0), "ERC1155: transfer to the zero address");
        require(data.length == 1, "ERC1155: data is too long");

        address operator = _msgSender();
        uint8 ifUsed = uint8(data[0]);

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from][ifUsed];
            require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
            unchecked {
                _balances[id][from][ifUsed] = fromBalance - amount;
            }
            _balances[id][to][ifUsed] += amount;
        }

        // emit TransferBatch(operator, from, to, ids, amounts, ifUsed);
        emit TransferBatch(operator, from, to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
    }

    function mint(
        address to,
        uint256 amount,
        uint256 price_,
        uint8 saveType_,
        bytes32 uri_,
        uint8 usedForNew_,
        bytes memory data
    ) public onlyOwner {
        _mint(to,amount,price_,saveType_,uri_,usedForNew_,data);
    }

    /**
     * @dev Creates `amount` tokens of token type `id`, and assigns them to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _mint(
        address to,
        uint256 amount,
        uint256 price_,
        uint8 saveType_,
        bytes32 uri_,
        uint8 usedForNew_,
        bytes memory data
    ) internal {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(saveType_ != 0, "ERC1155: mint the invalid saveType");

        address operator = _msgSender();
        _currentId++;

        _beforeTokenTransfer(operator, address(0), to, _asSingletonArray(_currentId), _asSingletonArray(amount), data);

        _balances[_currentId][to][_unused] += amount;
        // emit TransferSingle(operator, address(0), to, _currentId, amount, 1);
        emit TransferSingle(operator, address(0), to, _currentId, amount);

        _baseData[_currentId].price = price_;
        _baseData[_currentId].saveType = saveType_;
        _baseData[_currentId].uri = uri_;
        _baseData[_currentId].usedForNew = usedForNew_;

        _doSafeTransferAcceptanceCheck(operator, address(0), to, _currentId, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] memory amounts,
        uint256[] memory prices,
        uint8[] memory saveTypes,
        bytes32[] memory uris,
        uint8[] memory usedForNews,
        bytes memory data
    ) public onlyOwner{
        require(amounts.length == prices.length, "ERC1155: amounts and prices length mismatch");
        require(prices.length == saveTypes.length, "ERC1155: prices and saveTypes length mismatch");
        require(saveTypes.length == uris.length, "ERC1155: saveTypes and uris length mismatch");
        require(uris.length == usedForNews.length, "ERC1155: uris and usedForNews length mismatch");
        uint256[] memory ids = new uint[](amounts.length);
        for (uint256 i = 0; i < amounts.length; i++) {
            ids[i] = _currentId+i+1;
        }
        _mintBatch(to,ids,amounts,prices,saveTypes,uris,usedForNews,data);
        _currentId += amounts.length;
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_mint}.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        uint256[] memory prices,
        uint8[] memory saveTypes,
        bytes32[] memory uris,
        uint8[] memory usedForNews,
        bytes memory data
    ) internal {
        require(to != address(0), "ERC1155: mint to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to][_unused] += amounts[i];
            _baseData[ids[i]].price = prices[i];
            _baseData[ids[i]].saveType = saveTypes[i];
            _baseData[ids[i]].uri = uris[i];
            _baseData[ids[i]].usedForNew = usedForNews[i];
        }

        // emit TransferBatch(operator, address(0), to, ids, amounts, 1);
        emit TransferBatch(operator, address(0), to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);
    }

    function burn(
        address from,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public onlyOwner {
        _burn(from,id,amount,data);
    }

    /**
     * @dev Destroys `amount` tokens of token type `id` from `from`
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `from` must have at least `amount` tokens of token type `id`.
     */
    function _burn(
        address from,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal {
        require(from != address(0), "ERC1155: burn from the zero address");
        require(data.length == 1, "ERC1155: data is too long");

        address operator = _msgSender();
        uint8 ifUsed = uint8(data[0]);

        _beforeTokenTransfer(operator, from, address(0), _asSingletonArray(id), _asSingletonArray(amount), "");

        uint256 fromBalance = _balances[id][from][ifUsed];
        require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
        unchecked {
            _balances[id][from][ifUsed] = fromBalance - amount;
        }

        // emit TransferSingle(operator, from, address(0), id, amount, ifUsed);
        emit TransferSingle(operator, from, address(0), id, amount);
    }

    function burnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public onlyOwner {

        _burnBatch(from,ids,amounts,data);

    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     */
    function _burnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal {
        require(from != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(data.length == 1, "ERC1155: data is too long");

        address operator = _msgSender();
        uint8 ifUsed = uint8(data[0]);

        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from][ifUsed];
            require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
            unchecked {
                _balances[id][from][ifUsed] = fromBalance - amount;
            }
        }
        // emit TransferBatch(operator, from, address(0), ids, amounts, ifUsed);
        emit TransferBatch(operator, from, address(0), ids, amounts);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits a {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal {
        require(owner != operator, "ERC1155: setting approval status for self");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning, as well as batched variants.
     *
     * The same hook is called on both single and batched variants. For single
     * transfers, the length of the `id` and `amount` arrays will be 1.
     *
     * Calling conditions (for each `id` and `amount` pair):
     *
     * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * of token type `id` will be  transferred to `to`.
     * - When `from` is zero, `amount` tokens of token type `id` will be minted
     * for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
     * will be burned.
     * - `from` and `to` are never both zero.
     * - `ids` and `amounts` have the same, non-zero length.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal {}

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }
}
