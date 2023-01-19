//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
 
import "@openzeppelin/contracts/access/Ownable.sol";


interface IAniwarNft {
    function createManyAniwarItem(uint8 _count, address _owner, string memory _aniwarType) external;
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function decimals() external view returns (uint8);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

contract AniwarNftController is Ownable {
    IAniwarNft public immutable ANIWAR_NFT_CONTRACT;
    IERC20 public immutable ANI_TOKEN;
    uint256 public nftMintableLeft = 5000;

    string public ANIWAR_TYPE;
    
    uint256 public mintFee = 200; // Aniwar nft mint fee: mintFee * 10 ** decimals
    event MintFeeChange(string aniwarType, uint256 fee);
    event NftMintableLeftChange(string aniwarType, uint256 number);


    constructor(string memory _aniwarType, address _aniwar_nft_contract, address _aniwar_token) {
        ANIWAR_NFT_CONTRACT = IAniwarNft(_aniwar_nft_contract);
        ANI_TOKEN = IERC20(_aniwar_token);
        ANIWAR_TYPE = _aniwarType; 
    } 

    function createManyAniwarItem(uint8 _count) public {
        require(nftMintableLeft >= _count, "Reached Limit!");
        ANIWAR_NFT_CONTRACT.createManyAniwarItem( _count, msg.sender, ANIWAR_TYPE); 
        uint256 _totalFee = _count * mintFee *  10 ** ANI_TOKEN.decimals();
        ANI_TOKEN.transferFrom(msg.sender, address(this), _totalFee);
        nftMintableLeft -= _count;
    }     
    
    function setMintFee(uint256 _fee) external onlyOwner {
        mintFee = _fee;
        emit MintFeeChange(ANIWAR_TYPE, _fee);
    }

    function setMaxNftMintable(uint256 _number) public onlyOwner {
        nftMintableLeft = _number;
        emit NftMintableLeftChange(ANIWAR_TYPE, _number);
    } 
    
    function withdrawToken(address _token, address _to, uint256 _amount) public onlyOwner {
        IERC20(_token).transferFrom(address(this), _to, _amount);
    }

    function aniwarType() public view returns(string memory) {
        return ANIWAR_TYPE;
    }
}
