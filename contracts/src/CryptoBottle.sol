// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721EnumerableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {ERC721RoyaltyUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721RoyaltyUpgradeable.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {VRFConsumerBaseV2Upgradeable} from "./VRFConsumerBaseV2Upgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

//import {console} from "hardhat/console.sol";

/**
 * @title CryptoCuvee
 * @dev The CryptoCuvee contract is an UUPS upgradeable contract that allows users to mint NFTs which will vault a percentage of the minting price into crypto currencies.
 */
contract CryptoCuvee is
    Initializable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721RoyaltyUpgradeable,
    AccessControlUpgradeable,
    VRFConsumerBaseV2Upgradeable
{
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
     * @dev The random request data struct
     */
    struct RandomRequestData {
        CategoryType categoryType;
        uint256 quantity;
        address to;
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

    /**
     * @dev The Chainlink VRF coordinator address
     */
    IVRFCoordinatorV2Plus private coordinator;
    /**
     * @dev The key hash for the Chainlink VRF
     */
    bytes32 private keyHash;
    /**
     * @dev The fee for the Chainlink VRF
     */
    uint32 private callbackGasLimit; // Adjust the gas limit based on your callback function
    /**
     * @dev Request confirmations for the Chainlink VRF
     */
    uint16 private requestConfirmations;
    /**
     * @dev The subscription ID for the Chainlink VRF
     */
    uint256 private s_subscriptionId;

    uint256 public maxQuantityMintable;

    mapping(uint256 => RandomRequestData) private randomnessRequestData;

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
    event CryptoBottleCreated(
        address indexed to, uint256 indexed tokenId, uint256 cryptoBottleIndex, uint256 requestId
    );

    /**
     * @dev Gap for upgrade safety
     */
    uint256[49] __gap;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721RoyaltyUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev The initialize function for the contract
     * @param _usdc The USDC token address
     * @param _cryptoBottles The CryptoBottles array
     * @param admin The admin address
     * @param vrfCoordinator The Chainlink VRF coordinator address
     * @param _keyHash The key hash for the Chainlink VRF
     * @param _callbackGasLimit The fee for the Chainlink VRF
     * @param _requestConfirmations The request confirmations for the Chainlink VRF
     * @param subscriptionId The subscription ID for the Chainlink VRF
     */
    function initialize(
        IERC20 _usdc,
        CryptoBottle[] memory _cryptoBottles,
        string memory _baseUri,
        address systemWallet,
        address admin,
        address vrfCoordinator,
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations,
        uint256 subscriptionId
    ) public initializer {
        __ERC721_init("CryptoCuvee", "CCV");
        __VRFConsumerBaseV2Upgradeable_init(vrfCoordinator);

        // Init Admin Role
        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        // Init System Wallet Role
        _grantRole(SYSTEM_WALLET_ROLE, systemWallet);

        mintingClosed = false;
        usdc = _usdc;
        baseURI = _baseUri;
        // Initialize Chainlink VRF
        coordinator = IVRFCoordinatorV2Plus(vrfCoordinator);
        keyHash = _keyHash;
        callbackGasLimit = _callbackGasLimit;
        requestConfirmations = _requestConfirmations;
        s_subscriptionId = subscriptionId;
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

        // For all addresses in uniqueERC20TokenAddresses, check if the sender has enough balance
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

        // Add check to see if there are enough unclaimed bottles after subtracting pending mints
        if (unclaimedBottlesByCategory[_category].length < _quantity + pendingMintsByCategory[_category]) {
            revert CategoryFullyMinted();
        }

        // Increment pending mints
        pendingMintsByCategory[_category] += _quantity;

        if (!hasRole(SYSTEM_WALLET_ROLE, _msgSender())) {
            uint256 bottleIndex = unclaimedBottlesByCategory[_category][0];
            CryptoBottle storage cryptoBottle = cryptoBottles[bottleIndex];
            SafeERC20.safeTransferFrom(usdc, _msgSender(), address(this), cryptoBottle.price * _quantity);
        }

        _requestRandomWords(_category, _quantity, _to);
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
     * @dev The function to upgrade the contract
     */
    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /**
     * @dev The function to randomely select one token
     * @param _category The category type
     * @param _random The random value
     * @param _to The address to mint to
     * @param _requestId The request ID
     */
    function _invest(CategoryType _category, uint256 _random, address _to, uint256 _requestId) internal {
        uint256[] storage unclaimedTokens = unclaimedBottlesByCategory[_category];

        // Select a token ID based on randomness
        uint256 randomIndex = _random % unclaimedTokens.length;
        uint256 selectedTokenId = unclaimedTokens[randomIndex];

        // Remove the selected token from the unclaimed pool
        unclaimedTokens[randomIndex] = unclaimedTokens[unclaimedTokens.length - 1];
        unclaimedTokens.pop();

        uint256 tokenId = totalSupply() + 1;

        // Mint the NFT
        _safeMint(_to, tokenId);
        tokenToCryptoBottle[tokenId] = selectedTokenId;

        // Emit CryptoBottleCreated event
        emit CryptoBottleCreated(_to, tokenId, selectedTokenId, _requestId);
    }

    /**
     * @dev This function request random VRF words depending on the categoryType and tokenID
     * @param categoryType The category type
     * @param _quantity The quantity to mint
     * @param _to The address to mint to
     */
    function _requestRandomWords(CategoryType categoryType, uint32 _quantity, address _to) internal {
        uint256 requestId = coordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: _quantity,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );

        RandomRequestData memory randomRequestData =
            RandomRequestData({categoryType: categoryType, quantity: _quantity, to: _to});
        //console.log("Request ID: %d", requestId);
        // Store the randomness request data
        randomnessRequestData[requestId] = randomRequestData;
    }

    /**
     * @dev Fulfill the randomness request
     * @param requestId The request ID
     * @param randomWords memory randomWords The random words
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        RandomRequestData memory requestData = randomnessRequestData[requestId];

        for (uint256 i = 0; i < requestData.quantity; i++) {
            _invest(requestData.categoryType, randomWords[i], requestData.to, requestId);
        }

        // Decrement pending mints by the number of mints that have just been completed
        pendingMintsByCategory[requestData.categoryType] -= requestData.quantity;

        delete randomnessRequestData[requestId];
    }

    /**
     * @dev Override _update function from ERC721Upgradeable
     * @param to The address to mint to
     * @param tokenId The token ID
     * @param auth address The address to mint from
     */
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    /**
     * @dev Override _increaseBalance function from ERC721Upgradeable and ERC721EnumerableUpgradeable
     * @param account The account to increase the balance
     * @param value The value to increase
     */
    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._increaseBalance(account, value);
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view override(ERC721Upgradeable) returns (string memory) {
        return baseURI;
    }
}
