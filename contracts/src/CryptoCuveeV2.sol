// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721Royalty} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title CryptoCuveeV2
 * @author RpGmAx (full remake based on original V1 SC created by Valentin Chmara)
 * @notice A contract for minting NFTs that vault ERC20 tokens, allowing users to "open" their bottles
 * to claim the underlying tokens. Features multiple categories of bottles with different token combinations.
 * @dev Implements ERC721 with Enumerable and Royalty extensions, plus access control and reentrancy protection
 */
contract CryptoCuveeV2 is ReentrancyGuard, ERC721, ERC721Enumerable, ERC721Royalty, AccessControl {
    /**
     * @dev Custom error messages
     */
    error InsufficientTokenBalance(address tokenAddress, uint256 tokenBalance);
    error MintClosed();
    error CategoryFullyMinted();
    error MaxQuantityReached();
    error BottleAlreadyOpened(uint256 tokenId);
    error QuantityMustBeGreaterThanZero();
    error MintNotClosed();
    error NotOwnerBottle(uint256 tokenId);
    error AllTokensWithdrawn();
    error BottlesAlreadyFilled();
    error InvalidCategory();
    error InvalidStableCoinAddress();
    error InvalidSystemWallet();
    error InvalidAdminAddress();
    error ParametersLengthMismatch();
    error InvalidPrice();
    error InvalidTotalBottles();
    error InvalidTokenQuantity();
    error InvalidTokenAddress();
    error InvalidNFTBoxAddress();

    /**
     * @dev The next mintable token ID
     */
    uint256 private _nextTokenId;

    /**
     * @dev The stable coin token address
     */
    IERC20 public stableCoin;

    /**
     * @dev Base URI for computing {tokenURI}
     */
    string private _uri;

    /**
     * @dev The user share of the tokens
     */
    uint256 private constant USER_SHARE = 90;

    /**
     * @dev The NFT box share of the tokens
     */
    uint256 private constant NFT_BOX_SHARE = 10;

    /**
     * @notice Represents a category of bottles with specific price, token allocations, and mint limits
     * @param price The stable coin price to mint a bottle in this category
     * @param tokens Array of ERC20 tokens included in this bottle category
     * @param totalBottles Maximum number of bottles that can be minted in this category
     * @param mintedBottles Current number of bottles minted in this category
     */
    struct Category {
        uint256 price;
        Token[] tokens;
        uint256 totalBottles;
        uint256 mintedBottles;
    }

    /**
     * @notice Represents an ERC20 token allocation within a bottle category
     * @param name Human-readable name of the token
     * @param tokenAddress Contract address of the ERC20 token
     * @param quantity Amount of tokens to be included per bottle
     */
    struct Token {
        string name;
        address tokenAddress;
        uint256 quantity;
    }

    /**
     * @dev System wallet role, can mint without stable coin payment
     */
    bytes32 public constant SYSTEM_WALLET_ROLE = keccak256("SYSTEM_WALLET_ROLE");

    /**
     * @dev Mint status
     */
    bool public mintClosed;

    /**
     * @dev All tokens withdrawn
     */
    bool private _allTokensWithdrawn;

    /**
     * @dev Max quantity mintable per transaction
     */
    uint256 public maxQuantityMintable;

    /**
     * @dev All the categories
     */
    Category[] public categories;

    /**
     * @dev Map the token ID to the category index
     */
    mapping(uint256 => uint256) public bottleToCategory;

    /**
     * @dev Mapping of all unique token addresses
     */
    address[] private _uniqueERC20TokenAddresses;

    /**
     * @dev Mapping to check if a token address already exists in uniqueTokenAddresses
     */
    mapping(address => bool) private _tokenAddressExists;

    /**
     * @dev Total quantity for a given token mapping
     */
    mapping(address => uint256) public totalTokenQuantity;

    /**
     * @dev Mapping of all opened bottles
     */
    mapping(uint256 => bool) public openedBottles;

    /**
     * @dev CryptoBottle's opened event
     */
    event CryptoBottleOpened(address indexed to, uint256 indexed tokenId);

    /**
     * @dev Withdraw amount for each token
     */
    mapping(address => uint256) private _withdrawAmountsERC20;

    /**
     * @dev CryptoBottle's minted event
     */
    event CryptoBottleMinted(address indexed to, uint256 indexed tokenId, uint256 categoryId);

    /**
     * @dev NFT Box Collection address updated event
     */
    event NFTBoxCollectionAddressUpdated(address indexed oldAddress, address indexed newAddress);

    /**
     * @dev Max quantity mintable updated event
     */
    event MaxQuantityMintableUpdated(uint256 newMaxQuantity);

    /**
     * @dev Track if bottles have been filled
     */
    bool public bottlesFilled;

    /**
     * @dev NFT Box Collection address that receives 10% of opened bottle tokens
     */
    address public nftBoxCollectionAddress;

    /**
     * @notice Initializes the CryptoBottle contract with category configurations and administrative settings
     * @param _stableCoin Address of the stable coin token used for payments
     * @param _prices Array of prices for each category
     * @param _totalBottles Array of total bottle limits for each category
     * @param _categoryTokens Nested array of token configurations for each category
     * @param _baseUri Base URI for token metadata
     * @param systemWallet Address of system wallet
     * @param admin Address to receive admin privileges
     */
    constructor(
        IERC20 _stableCoin,
        uint256[] memory _prices,
        uint256[] memory _totalBottles,
        Token[][] memory _categoryTokens,
        string memory _baseUri,
        address systemWallet,
        address admin
    ) ERC721("CryptoCuvee", "CCV") {
        if (address(_stableCoin) == address(0)) revert InvalidStableCoinAddress();
        if (systemWallet == address(0)) revert InvalidSystemWallet();
        if (admin == address(0)) revert InvalidAdminAddress();
        if (_prices.length != _totalBottles.length || _prices.length != _categoryTokens.length) {
            revert ParametersLengthMismatch();
        }

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(SYSTEM_WALLET_ROLE, systemWallet);

        _nextTokenId = 1;
        mintClosed = true;
        stableCoin = _stableCoin;
        _uri = _baseUri;
        maxQuantityMintable = 3;

        // Initialize Categories
        for (uint256 i = 0; i < _prices.length; i++) {
            if (_totalBottles[i] > 0 && _prices[i] <= 0) revert InvalidPrice();
            if (_totalBottles[i] <= 0 && _prices[i] > 0) revert InvalidTotalBottles();

            categories.push();
            Category storage newCategory = categories[i];

            newCategory.price = _prices[i];
            newCategory.totalBottles = _totalBottles[i];
            newCategory.mintedBottles = 0;

            // Copy tokens and track unique addresses
            for (uint256 j = 0; j < _categoryTokens[i].length; j++) {
                Token memory memToken = _categoryTokens[i][j];
                if (memToken.quantity <= 0) revert InvalidTokenQuantity();
                if (memToken.tokenAddress == address(0)) revert InvalidTokenAddress();
                newCategory.tokens.push(
                    Token({name: memToken.name, tokenAddress: memToken.tokenAddress, quantity: memToken.quantity})
                );

                if (!_tokenAddressExists[memToken.tokenAddress]) {
                    _uniqueERC20TokenAddresses.push(memToken.tokenAddress);
                    _tokenAddressExists[memToken.tokenAddress] = true;
                    totalTokenQuantity[memToken.tokenAddress] = 0;
                }
                totalTokenQuantity[memToken.tokenAddress] += memToken.quantity * _totalBottles[i];
            }
        }

        // Set default NFT Box Collection address
        nftBoxCollectionAddress = 0xc0b05c33a6E568868A6423F0337b2914C374bfF9;
    }

    /**
     * @notice Transfers initial token quantities to the contract and enables mint
     * @dev Can only be called once by admin. Requires admin to have approved sufficient token amounts
     */
    function fillBottles() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (bottlesFilled) {
            revert BottlesAlreadyFilled();
        }

        for (uint256 i = 0; i < _uniqueERC20TokenAddresses.length; i++) {
            address tokenAddress = _uniqueERC20TokenAddresses[i];
            uint256 tokenBalance = IERC20(tokenAddress).balanceOf(_msgSender());
            if (tokenBalance < totalTokenQuantity[tokenAddress]) {
                revert InsufficientTokenBalance(tokenAddress, tokenBalance);
            }
            // Transfer the tokens to the contract
            SafeERC20.safeTransferFrom(
                IERC20(tokenAddress), _msgSender(), address(this), totalTokenQuantity[tokenAddress]
            );
        }

        bottlesFilled = true;
    }

    /**
     * @notice Mints new bottles to a specified address
     * @dev System wallet can mint without stable coin payment
     * @param _to Address to receive the minted bottles
     * @param _quantity Number of bottles to mint
     * @param _categoryId Category index of bottles to mint
     */
    function mint(address _to, uint32 _quantity, uint256 _categoryId) external nonReentrant {
        if (_categoryId >= categories.length) revert InvalidCategory();
        if (mintClosed) {
            revert MintClosed();
        }

        if (_quantity == 0) {
            revert QuantityMustBeGreaterThanZero();
        }

        if (_quantity > maxQuantityMintable) {
            revert MaxQuantityReached();
        }

        Category storage category = categories[_categoryId];
        if (category.mintedBottles + _quantity > category.totalBottles) {
            revert CategoryFullyMinted();
        }

        // Update state
        uint256[] memory tokenIds = new uint256[](_quantity);
        for (uint32 i = 0; i < _quantity; i++) {
            tokenIds[i] = _nextTokenId++;
            bottleToCategory[tokenIds[i]] = _categoryId;
            category.mintedBottles++;
        }

        // Handle stable coin payment if not system wallet
        if (!hasRole(SYSTEM_WALLET_ROLE, _msgSender())) {
            SafeERC20.safeTransferFrom(stableCoin, _msgSender(), address(this), category.price * _quantity);
        }

        // Mint tokens
        for (uint32 i = 0; i < _quantity; i++) {
            _safeMint(_to, tokenIds[i]);
            emit CryptoBottleMinted(_to, tokenIds[i], _categoryId);
        }
    }

    /**
     * @notice Allows bottle owner to claim the underlying tokens
     * @dev Transfers 90% of tokens to owner and 10% to NFT Box Collection address
     * @param _tokenId ID of the bottle to open
     */
    function openBottle(uint256 _tokenId) external nonReentrant {
        _openBottle(_tokenId);
    }

    /**
     * @notice Allows multiple bottles to be opened at once
     * @param tokenIds Array of token IDs to open
     */
    function openBottles(uint256[] calldata tokenIds) external nonReentrant {
        uint256 length = tokenIds.length;
        for (uint256 i; i < length;) {
            _openBottle(tokenIds[i]);
            ++i;
        }
    }

    /**
     * @dev Whitdraw the stable coin from the contract
     */
    function withdrawStableCoin() external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        SafeERC20.safeTransfer(stableCoin, _msgSender(), stableCoin.balanceOf(address(this)));
    }

    /**
     * @dev Set the max quantity mintable
     */
    function setMaxQuantityMintable(uint256 _maxQuantityMintable) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxQuantityMintable = _maxQuantityMintable;
        emit MaxQuantityMintableUpdated(_maxQuantityMintable);
    }

    /**
     * @dev Close or Open the mint of the NFTs
     */
    function changeMintStatus() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_allTokensWithdrawn) {
            revert AllTokensWithdrawn();
        }
        mintClosed = !mintClosed;
    }

    /**
     *
     * @dev Whithdraw all tokens in the contract for non minted bottles only - requires a closed mint
     */
    function withdrawAllTokens() external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!mintClosed) revert MintNotClosed();
        if (_allTokensWithdrawn) revert AllTokensWithdrawn();

        uint256 categoriesLength = categories.length;

        for (uint256 categoryId; categoryId < categoriesLength;) {
            Category storage category = categories[categoryId];
            uint256 unclaimedBottles = category.totalBottles - category.mintedBottles;
            uint256 tokensLength = category.tokens.length;

            for (uint256 j; j < tokensLength;) {
                Token memory token = category.tokens[j];
                _withdrawAmountsERC20[token.tokenAddress] += token.quantity * unclaimedBottles;
                ++j;
            }
            ++categoryId;
        }

        // Transfer all remaining tokens
        for (uint256 i = 0; i < _uniqueERC20TokenAddresses.length; i++) {
            address tokenAddress = _uniqueERC20TokenAddresses[i];
            uint256 amount = _withdrawAmountsERC20[tokenAddress];
            if (amount > 0) {
                SafeERC20.safeTransfer(IERC20(tokenAddress), _msgSender(), amount);
            }
        }

        _allTokensWithdrawn = true;
    }

    /**
     * @dev Set default royalty fee
     * @param _receiver The royalty fee
     * @param _feeNumerator The royalty fee
     */
    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    /**
     * @notice Updates the NFT Box Collection address
     * @param _newAddress New address to receive 10% of opened bottle tokens
     */
    function setNFTBoxCollectionAddress(address _newAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_newAddress == address(0)) revert InvalidNFTBoxAddress();
        address oldAddress = nftBoxCollectionAddress;
        nftBoxCollectionAddress = _newAddress;
        emit NFTBoxCollectionAddressUpdated(oldAddress, _newAddress);
    }

    /**
     * @dev Sets the base URI for token metadata
     * @param uri_ New base URI
     */
    function setBaseURI(string memory uri_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _uri = uri_;
    }

    /**
     * @dev Get the tokens of a specific CryptoBottle from tokenId
     * @param tokenId The index of the CryptoBottle in the array
     * @return tokens The array of Token structs
     */
    function getCryptoBottleTokens(uint256 tokenId) external view returns (Token[] memory) {
        if (ownerOf(tokenId) == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }

        uint256 categoryId = bottleToCategory[tokenId];
        return categories[categoryId].tokens;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable, ERC721Royalty, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // Internal function to handle the bottle opening logic
    function _openBottle(uint256 _tokenId) internal {
        if (ownerOf(_tokenId) != _msgSender()) {
            revert NotOwnerBottle(_tokenId);
        }

        if (openedBottles[_tokenId]) {
            revert BottleAlreadyOpened(_tokenId);
        }

        uint256 categoryId = bottleToCategory[_tokenId];
        Category storage category = categories[categoryId];
        openedBottles[_tokenId] = true;

        uint256 tokenLength = category.tokens.length;
        for (uint256 i; i < tokenLength;) {
            Token memory token = category.tokens[i];
            SafeERC20.safeTransfer(IERC20(token.tokenAddress), _msgSender(), (token.quantity * USER_SHARE) / 100);
            SafeERC20.safeTransfer(
                IERC20(token.tokenAddress), nftBoxCollectionAddress, (token.quantity * NFT_BOX_SHARE) / 100
            );
            ++i;
        }

        emit CryptoBottleOpened(_msgSender(), _tokenId);
    }

    /**
     * @dev Override _update function from ERC721
     * @param to The address to mint to
     * @param tokenId The token ID
     * @param auth address The address to mint from
     */
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    /**
     * @dev Override _increaseBalance function from ERC721 and ERC721Enumerable
     * @param account The account to increase the balance
     * @param value The value to increase
     */
    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    /// @notice Returns the base URI for token metadata
    function _baseURI() internal view override returns (string memory) {
        return _uri;
    }
}
