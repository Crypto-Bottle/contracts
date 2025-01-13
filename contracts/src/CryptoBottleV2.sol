// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721Royalty} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {console} from "hardhat/console.sol";

/**
 * @title CryptoCuveeV2
 * @dev The CryptoCuveeV2 contract is a contract that allows users to mint NFTs which will vault a percentage of the minting price into crypto currencies.
 */
contract CryptoCuveeV2 is ReentrancyGuard, ERC721, ERC721Enumerable, ERC721Royalty, AccessControl {
    /**
     * @dev Error messages for require statements
     */
    error InsufficientTokenBalance(address tokenAddress, uint256 tokenBalance);
    error MintingClosed();
    error CategoryFullyMinted();
    error MaxQuantityReached();
    error BottleAlreadyOpened(uint256 tokenId);
    error QuantityMustBeGreaterThanZero();
    error MintingNotClosed();
    error NotOwnerBottle(uint256 tokenId);
    error AllTokensWithdrawn();
    error BottlesAlreadyFilled();

    /**
     * @dev The next token ID
     */
    uint256 private _nextTokenId;

    /**
     * @dev The USDC token address
     */
    IERC20 public usdc;

    /**
     * @dev Base URI for computing {tokenURI}
     */
    string private baseURI;

    /**
     * @dev The struct for a CryptoBottle
     */
    struct CryptoBottle {
        CategoryType categoryType;
        uint256 price; // The price in USDC
        Token[] tokens;
    }

    /**
     * @dev enum CategoryType
     */
    enum CategoryType {
        ROUGE,
        BLANC,
        ROSE,
        CHAMPAGNE
    }

    /**
     * @dev The struct for an ERC20 token link to a category
     */
    struct Token {
        string name;
        address tokenAddress;
        uint256 quantity;
    }

    /**
     * @dev Systel wallet role
     */
    bytes32 public constant SYSTEM_WALLET_ROLE = keccak256("SYSTEM_WALLET_ROLE");

    /**
     * @dev Admin full close the minting
     */
    bool private mintingClosed;

    /**
     * @dev Withdraw all tokens bool
     */
    bool private allTokensWithdrawn;

    uint256 public maxQuantityMintable;

    /**
     * @dev All the CryptoBottles
     */
    CryptoBottle[] public cryptoBottles;

    /**
     * @dev Map the token ID to the crypto bottle index
     */
    mapping(uint256 => uint256) public tokenToCryptoBottle;

    /**
     * @dev The mapping of all unique token addresses
     */
    address[] private uniqueERC20TokenAddresses;

    /**
     * @dev Mapping to check if a token address is already added to uniqueTokenAddresses
     */
    mapping(address => bool) private tokenAddressExists;

    /**
     * @dev Total quantity for a given token mapping
     */
    mapping(address => uint256) private totalTokenQuantity;

    /**
     * @dev Unclaimed tokens by category
     */
    mapping(CategoryType => uint256[]) private unclaimedBottlesByCategory;

    /**
     * @dev Pending mint by category
     */
    mapping(CategoryType => uint256) private pendingMintsByCategory;

    /**
     * @dev All Opened Bottles
     */
    mapping(uint256 => bool) public openedBottles;

    /**
     * @dev The CryptoBottle's open event
     */
    event CryptoBottleOpen(address indexed to, uint256 indexed tokenId);

    /**
     * @dev Withdaw amount
     */
    mapping(address => uint256) private withdrawAmountsERC20;

    /**
     * @dev The CryptoBottle's created event
     */
    event CryptoBottleCreated(address indexed to, uint256 indexed tokenId, uint256 cryptoBottleIndex);

    /**
     * @dev Track if bottles have been filled
     */
    bool private bottlesFilled;

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

    /**
     * @dev The initialize function for the contract
     * @param _usdc The USDC token address
     * @param _cryptoBottles The CryptoBottles array
     * @param admin The admin address
     */
    constructor(
        IERC20 _usdc,
        CryptoBottle[] memory _cryptoBottles,
        string memory _baseUri,
        address systemWallet,
        address admin
    ) ERC721("CryptoCuvee", "CCV") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(SYSTEM_WALLET_ROLE, systemWallet);

        _nextTokenId = 1;
        mintingClosed = true;
        usdc = _usdc;
        baseURI = _baseUri;
        maxQuantityMintable = 3;

        // Initialize CryptoBottles
        for (uint256 i = 0; i < _cryptoBottles.length; i++) {
            cryptoBottles.push();
            uint256 newIndex = cryptoBottles.length - 1;
            CryptoBottle storage newBottle = cryptoBottles[newIndex];

            newBottle.categoryType = _cryptoBottles[i].categoryType;
            newBottle.price = _cryptoBottles[i].price;

            // Explicitly copy each Token struct from memory to storage
            for (uint256 j = 0; j < _cryptoBottles[i].tokens.length; j++) {
                Token memory memToken = _cryptoBottles[i].tokens[j];
                newBottle.tokens.push(
                    Token({name: memToken.name, tokenAddress: memToken.tokenAddress, quantity: memToken.quantity})
                );

                if (!tokenAddressExists[memToken.tokenAddress]) {
                    uniqueERC20TokenAddresses.push(memToken.tokenAddress);
                    tokenAddressExists[memToken.tokenAddress] = true;
                    totalTokenQuantity[memToken.tokenAddress] = 0;
                }
                totalTokenQuantity[memToken.tokenAddress] += memToken.quantity;
            }
            unclaimedBottlesByCategory[_cryptoBottles[i].categoryType].push(i);
        }
    }

    /**
     * @dev Transfer initial token quantities to the contract and open mint
     */
    function fillBottles() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (bottlesFilled) {
            revert BottlesAlreadyFilled();
        }

        for (uint256 i = 0; i < uniqueERC20TokenAddresses.length; i++) {
            address tokenAddress = uniqueERC20TokenAddresses[i];
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
        mintingClosed = false; // Open mint
    }

    /**
     * @dev Open a crypto bottle and get the tokens inside
     * @param _tokenId The token ID
     */
    function openBottle(uint256 _tokenId) external nonReentrant {
        //_checkAuthorized(ownerOf(_tokenId), _msgSender(), _tokenId);

        if (ownerOf(_tokenId) != _msgSender()) {
            revert NotOwnerBottle(_tokenId);
        }

        uint256 cryptoBottleIndex = tokenToCryptoBottle[_tokenId];
        CryptoBottle storage cryptoBottle = cryptoBottles[cryptoBottleIndex];

        if (openedBottles[_tokenId]) {
            revert BottleAlreadyOpened(_tokenId);
        }

        openedBottles[_tokenId] = true;

        for (uint256 i = 0; i < cryptoBottle.tokens.length; i++) {
            Token memory token = cryptoBottle.tokens[i];
            SafeERC20.safeTransfer(IERC20(token.tokenAddress), _msgSender(), (token.quantity * 90) / 100);
            SafeERC20.safeTransfer(
                IERC20(token.tokenAddress),
                address(0xc0b05c33a6E568868A6423F0337b2914C374bfF9), // NFT Box Collection
                (token.quantity * 10) / 100
            );
        }

        emit CryptoBottleOpen(_msgSender(), _tokenId);
    }

    /**
     * @dev The function to mintTo an NFT
     * @param _to The address to mint to
     * @param _quantity The quantity to mint
     * @param _category The category type
     */
    function mint(address _to, uint32 _quantity, CategoryType _category) external nonReentrant {
        if (mintingClosed) {
            revert MintingClosed();
        }

        if (_quantity == 0) {
            revert QuantityMustBeGreaterThanZero();
        }

        if (_quantity > maxQuantityMintable) {
            revert MaxQuantityReached();
        }

        // Check if there are enough unclaimed bottles
        if (unclaimedBottlesByCategory[_category].length < _quantity) {
            revert CategoryFullyMinted();
        }

        // Handle USDC payment if not system wallet
        if (!hasRole(SYSTEM_WALLET_ROLE, _msgSender())) {
            uint256 bottleIndex = unclaimedBottlesByCategory[_category][0];
            CryptoBottle storage cryptoBottle = cryptoBottles[bottleIndex];
            SafeERC20.safeTransferFrom(usdc, _msgSender(), address(this), cryptoBottle.price * _quantity);
        }

        // Mint tokens (sequentially)
        for (uint32 i = 0; i < _quantity; i++) {
            uint256[] storage unclaimedTokens = unclaimedBottlesByCategory[_category];

            // Always select the first token in the array
            uint256 selectedTokenId = unclaimedTokens[0];

            // Remove the selected token from the unclaimed pool
            unclaimedTokens[0] = unclaimedTokens[unclaimedTokens.length - 1];
            unclaimedTokens.pop();

            // Mint the NFT
            uint256 tokenId = _nextTokenId++;

            _safeMint(_to, tokenId);
            tokenToCryptoBottle[tokenId] = selectedTokenId;

            // Emit CryptoBottleCreated event
            emit CryptoBottleCreated(_to, tokenId, selectedTokenId);
        }
    }

    /**
     * @dev Whitdraw the USDC from the contract
     */
    function withdrawUSDC() external onlyRole(DEFAULT_ADMIN_ROLE) {
        SafeERC20.safeTransfer(usdc, _msgSender(), usdc.balanceOf(address(this)));
    }

    /**
     * @dev Set the max quantity mintable
     */
    function setMaxQuantityMintable(uint256 _maxQuantityMintable) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxQuantityMintable = _maxQuantityMintable;
    }

    /**
     * @dev Close or Open the minting of the NFTs
     */
    function changeMintingStatus() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (allTokensWithdrawn) {
            revert AllTokensWithdrawn();
        }
        mintingClosed = !mintingClosed;
    }

    /**
     *
     * @dev Whithdraw all the tokens in the contract (require that all bottles are opened)
     */
    function withdrawAllTokens() external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Revert if minting is not closed
        if (!mintingClosed) {
            revert MintingNotClosed();
        }

        // If the tokens have already been withdrawn, revert
        if (allTokensWithdrawn) {
            revert AllTokensWithdrawn();
        }

        allTokensWithdrawn = true;

        for (uint256 categoryIndex = 0; categoryIndex < uint256(CategoryType.CHAMPAGNE) + 1; categoryIndex++) {
            CategoryType category = CategoryType(categoryIndex);

            uint256[] storage unclaimedBottles = unclaimedBottlesByCategory[category];

            for (uint256 i = 0; i < unclaimedBottles.length; i++) {
                CryptoBottle storage bottle = cryptoBottles[unclaimedBottles[i]];

                for (uint256 j = 0; j < bottle.tokens.length; j++) {
                    Token memory token = bottle.tokens[j];
                    withdrawAmountsERC20[token.tokenAddress] += token.quantity;
                }
            }
        }

        for (uint256 i = 0; i < uniqueERC20TokenAddresses.length; i++) {
            address tokenAddress = uniqueERC20TokenAddresses[i];
            uint256 amount = withdrawAmountsERC20[tokenAddress];
            if (amount > 0) {
                SafeERC20.safeTransfer(IERC20(tokenAddress), _msgSender(), amount);
            }
        }
    }

    /**
     * @dev Get the tokens of a specific CryptoBottle from tokenId
     * @param tokenId The index of the CryptoBottle in the array
     * @return tokens The array of Token structs
     */
    function getCryptoBottleTokens(uint256 tokenId) external view returns (Token[] memory) {
        uint256 cryptoBottleIndex = tokenToCryptoBottle[tokenId];
        return cryptoBottles[cryptoBottleIndex].tokens;
    }

    /**
     * @dev Set default royalty fee
     * @param _receiver The royalty fee
     * @param _feeNumerator The royalty fee
     */
    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) external onlyRole(SYSTEM_WALLET_ROLE) {
        _setDefaultRoyalty(_receiver, _feeNumerator);
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

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view override(ERC721) returns (string memory) {
        return baseURI;
    }
}
