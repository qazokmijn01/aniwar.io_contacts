// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10; 
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 { 
    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external; 
}

interface IERC20 {
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// File: contracts/Leverjbounty.sol

contract AniwarMarket is AccessControl, Pausable {
  mapping (address => mapping (uint256 => uint256)) public sellerToIdToAmount;
  mapping (uint256 => address) public idToSeller;
  mapping (uint256 => uint256) public idToIndex;
  uint256[] public nfts;

    IERC721 public immutable ANIWAR_NFT;
    IERC20 public immutable ANIWAR_TOKEN;
    uint256 public fee; // FEE of each transaction 1/1000

    // Create a new role identifier for the minter role
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    event AniwarNftListed(address indexed owner, uint256 indexed id, uint256 amount);
    event AniwarNftWithdrawn(address indexed owner, uint256 indexed id);
    event AniwarNftSold(address indexed oldOwner, address indexed newOwner, uint256 indexed id, uint256 amount);
    event AniwarNftAmountChanged(address indexed owner, uint256 indexed id, uint256 amount);
    event FeeChange(uint256 fee);
    event FeeWithdrawn(address indexed to, uint256 amount);
    constructor(address _ANIWAR_NFT, address _ANIWAR_TOKEN) {
        ANIWAR_TOKEN = IERC20(_ANIWAR_TOKEN);
        ANIWAR_NFT = IERC721(_ANIWAR_NFT);
        // Grant the minter role to a specified account
        _setupRole(PAUSE_ROLE, msg.sender);
        _setupRole(OPERATOR_ROLE, msg.sender);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        nfts.push(0);
    }

    function listNfts(uint256[] memory _nftIds, uint256[] memory _nftAmounts) public whenNotPaused {
        for (uint256 i = 0; i < _nftIds.length; i++) { 
            uint256 amount = _nftAmounts[i];
            require(amount > 0, "amount < 0!");
            uint256 id = _nftIds[i];
            ANIWAR_NFT.transferFrom(
                msg.sender,
                address(this),
                id
            );
            sellerToIdToAmount[msg.sender][id] = amount;
            idToSeller[id] = msg.sender;
            nfts.push(id);
            idToIndex[id] = nfts.length - 1;
            emit AniwarNftListed(msg.sender, id, amount);
        }
    }
    function buyNfts(uint256 _nftId) public whenNotPaused {
        require(idToIndex[_nftId] != 0, "Id not in the List!");
        address seller = idToSeller[_nftId];
        require(seller != msg.sender, "You are seller!");
        ANIWAR_NFT.transferFrom(
            address(this),
            msg.sender,
            _nftId
        );
        uint256 _amount = sellerToIdToAmount[seller][_nftId];
        uint256 _totalFee = (_amount * fee) / 1000;
        uint256 _totalAmount = _amount - _totalFee;
        ANIWAR_TOKEN.transferFrom(msg.sender, seller, _totalAmount);
        ANIWAR_TOKEN.transferFrom(msg.sender, address(this), _totalFee);
        uint256 _lastId = nfts[nfts.length-1];
        nfts[idToIndex[_nftId]] = _lastId;
        nfts.pop();
        idToIndex[_lastId] = idToIndex[_nftId];
        idToIndex[_nftId] = 0;
        idToSeller[_nftId] = address(0);
        sellerToIdToAmount[seller][_nftId] = 0;
        emit AniwarNftSold(seller, msg.sender, _nftId, _amount);
    }

    function withdrawNfts(uint256[] memory _nftIds) public whenNotPaused {
        for (uint256 i = 0; i < _nftIds.length; i++) {
            uint256 _id = _nftIds[i];
            require(idToIndex[_id] != 0, "Id not in the List");
            require(idToSeller[_id] == msg.sender, "You are not seller");
            ANIWAR_NFT.transferFrom(
                address(this),
                msg.sender,
                _id
            ); 
            sellerToIdToAmount[msg.sender][_id] = 0;
            idToSeller[_id] = address(0);
            uint256 _lastId = nfts[nfts.length-1];
            nfts[idToIndex[_id]] = _lastId;
            nfts.pop();
            idToIndex[_lastId] = idToIndex[_id];
            idToIndex[_id] = 0;
            emit AniwarNftWithdrawn(msg.sender, _id);
        }
    }

    function setPricesNfts(uint256[] memory _nftIds, uint256[] memory _nftAmounts) public whenNotPaused {
        for (uint256 i = 0; i < _nftIds.length; i++) {
            uint256 id = _nftIds[i];
            address seller = idToSeller[id];
            uint256 amount = _nftAmounts[i];
            require(amount > 0, "amount < 0!");
            require(seller == msg.sender, "You are not the seller!");
            sellerToIdToAmount[msg.sender][id] = amount;
            emit AniwarNftAmountChanged(msg.sender, id, amount);
        }
    }

    // Fee = fee * 1 / 1000
    function setFee(uint256 _fee) public {
        require(hasRole(OPERATOR_ROLE, msg.sender), "Caller is not authorize");
        fee = _fee;
        emit FeeChange(fee);
    }
    
    function withdrawFee(address to, uint256 amount) public {
        require(hasRole(OPERATOR_ROLE, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not authorize!");
        ANIWAR_TOKEN.transferFrom(address(this), to, amount);
        emit FeeWithdrawn(to, amount);
    }

    function pause() public onlyRole(PAUSE_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSE_ROLE) {
        _unpause();
    }
}