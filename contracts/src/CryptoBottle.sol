// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
pragma abicoder v2;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {VRFConsumerBaseV2Upgradeable} from "./VRFConsumerBaseV2Upgradeable.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title CryptoCuvee
 * @dev The CryptoCuvee contract is an UUPS upgradeable contract that allows users to mint NFTs which will vault a percentage of the minting price into crypto currencies.
 */
abstract contract CryptoCuvee is
    Initializable,
    UUPSUpgradeable,
    ERC721Upgradeable,
    OwnableUpgradeable,
    VRFConsumerBaseV2Upgradeable
{
    /**
     * @dev Error messages for require statements
     */
    error InsufficientTokenBalance();
    error CategoryFullyMinted();
    error OwnerOfToken();

    /**
     * @dev The USDC token address
     */
    IERC20 public usdc;

    /**
     * @dev The struct for a CryptoBottle
     */
    struct CryptoBottle {
        CategoryType categoryType;
        uint256 price; // The price in USDC
        uint256 minted;
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
     * @dev The Chainlink VRF coordinator address
     */
    VRFCoordinatorV2Interface private coordinator;
    /**
     * @dev The key hash for the Chainlink VRF
     */
    bytes32 private keyHash;
    /**
     * @dev The fee for the Chainlink VRF
     */
    uint32 private callbackGasLimit = 200000; // Adjust the gas limit based on your callback function
    /**
     * @dev Request confirmations for the Chainlink VRF
     */
    uint16 private requestConfirmations = 3;
    /**
     * @dev The subscription ID for the Chainlink VRF
     */
    uint64 private s_subscriptionId;

    mapping(uint256 => CategoryType) private randomnessRequestData;

    /**
     * @dev The mapping of all tokenId to CryptoBottle
     */
    mapping(uint256 => CryptoBottle) public cryptoBottles;

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
     * @dev The initialize function for the contract
     * @param _usdc The USDC token address
     * @param _cryptoBottles The CryptoBottles array
     * @param vrfCoordinator The Chainlink VRF coordinator address
     * @param _keyHash The key hash for the Chainlink VRF
     * @param _callbackGasLimit The fee for the Chainlink VRF
     * @param _requestConfirmations The request confirmations for the Chainlink VRF
     * @param subscriptionId The subscription ID for the Chainlink VRF
     */
    function initialize(
        IERC20 _usdc,
        CryptoBottle[] memory _cryptoBottles,
        address vrfCoordinator,
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations,
        uint64 subscriptionId
    ) public payable initializer {
        __ERC721_init("CryptoCuvee", "CCV");
        __Ownable_init(_msgSender());
        __VRFConsumerBaseV2Upgradeable_init(vrfCoordinator);
        usdc = _usdc;

        // Initialize Chainlink VRF
        coordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        keyHash = _keyHash;
        callbackGasLimit = _callbackGasLimit;
        requestConfirmations = _requestConfirmations;
        s_subscriptionId = subscriptionId;

        // Initialize CryptoBottles
        for (uint256 i = 0; i < _cryptoBottles.length; i++) {
            CryptoBottle memory cryptoBottle = _cryptoBottles[i];
            cryptoBottles[i] = cryptoBottle;
            for (uint256 j = 0; j < cryptoBottle.tokens.length; j++) {
                Token memory token = cryptoBottle.tokens[j];
                if (!tokenAddressExists[token.tokenAddress]) {
                    uniqueERC20TokenAddresses.push(token.tokenAddress);
                    tokenAddressExists[token.tokenAddress] = true;
                    totalTokenQuantity[token.tokenAddress] = 0;
                }
                totalTokenQuantity[token.tokenAddress] += token.quantity;
            }
        }

        // For all addresses in uniqueERC20TokenAddresses, check if the sender has enough balance
        for (uint256 i = 0; i < uniqueERC20TokenAddresses.length; i++) {
            address tokenAddress = uniqueERC20TokenAddresses[i];
            if (IERC20(tokenAddress).balanceOf(address(this)) < totalTokenQuantity[tokenAddress]) {
                revert InsufficientTokenBalance();
            }
            // Transfer the tokens to the contract
            IERC20(tokenAddress).transferFrom(
                _msgSender(),
                address(this),
                totalTokenQuantity[tokenAddress]
            );
        }
    }

    /**
     * @dev The function to upgrade the contract
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /**
     * @dev The function to mintTo an NFT
     * @param categoryType The category type
     */
    function mint(address recipient, uint256 quantity, string memory categoryType) public {}

    /**
     * @dev The function to randomely select one token
     * @param categoryType The category type
     * @param randomValue The random value
     */
    function _invest(CategoryType categoryType, uint256 randomValue) internal {}

    /**
     * @dev This function request random VRF words depending on the categoryType and tokenID
     * @param categoryType The category type
     */
    function _requestRandomWords(
        CategoryType categoryType
    ) internal {
        uint256 requestId = coordinator.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            1 // Requesting 1 random value for simplicity
        );

        // Store the randomness request data
        randomnessRequestData[requestId] = categoryType;
    }

    /**
     * @dev Fullfill the randomness request
     * @param requestId The request ID
     * @param randomWords memory randomWords The random words
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        CategoryType requestData = randomnessRequestData[requestId];

        // Use `randomWords` and requestData to distribute funds
        uint256 randomValue = randomWords[0]; // Random value from Chainlink VRF

        _invest(requestData, randomValue);

        delete randomnessRequestData[requestId];
    }
}
