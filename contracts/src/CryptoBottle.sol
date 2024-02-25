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
abstract contract CryptoCuvee is Initializable, UUPSUpgradeable, ERC721Upgradeable, OwnableUpgradeable, VRFConsumerBaseV2Upgradeable {
    /**
    * @dev Error messages for require statements
     */
    error InsufficientUSDCAllowance();
    error CategoryFullyMinted();
    error OwnerOfToken();

    /**
     * @dev The USDC token address
     */
    IERC20 public usdc;

    /**
     * @dev The fill rate, if the fill rate is 100, the contract will invest all the minted funds into crypto currencies for holders
     */
    uint256 public fillRate;

    /**
     * @dev The struct for NFT category
     */
    struct Category {
        string name;
        uint256 price;
        uint256 supply;
        uint256 minted;
        Token[] tokens;
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

    /**
     * @dev The struct for randomness request data
     */
    struct RandomnessRequestData {
        uint256 tokenId;
        string categoryType;
    }
    mapping(uint256 => RandomnessRequestData) private randomnessRequestData;


    /**
     * @dev The mapping for categories
     */
    mapping(string => Category) public categories;

    /**
     * @dev The initialize function for the contract
     * @param _usdc The USDC token address
     */
    function initialize(IERC20 _usdc, address vrfCoordinator,
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations,
        uint64 subscriptionId) public {
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

        // Initialize categories here with prices and supply limits
        // For example:
        categories["White"] = Category("White", 1e6, 100, 0, new Token[](0)); 
        categories["Red"] = Category("Red", 2e6, 100, 0, new Token[](0)); 
        categories["Rose"] = Category("Rose", 3e6, 100, 0, new Token[](0)); 
        categories["Champagne"] = Category("Champagne", 4e6, 100, 0, new Token[](0)); 
    }

    /**
     * @dev The function to upgrade the contract
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /**
     * @dev The function to add a list of tokens to a category
     * @param categoryType The category type
     * @param tokenNames The list of token names
     * @param tokenAddresses The list of token addresses
     */
    function addTokensToCategory(string memory categoryType, string[] memory tokenNames, address[] memory tokenAddresses) public onlyOwner {
        for (uint256 i = 0; i < tokenNames.length; i++) {
            categories[categoryType].tokens.push(Token(tokenNames[i], tokenAddresses[i], 0));
        }
    }

    /**
     * @dev The function to remove a list of tokens from a category
     * @param categoryType The category type
     * @param tokenNames The list of token names
     * @param tokenAddresses The list of token addresses
     */
     function removeTokensToCategory(string memory categoryType, string[] memory tokenNames, address[] memory tokenAddresses) public onlyOwner {
        for (uint256 i = 0; i < tokenNames.length; i++) {
            for (uint256 j = 0; j < categories[categoryType].tokens.length; j++) {
                if (keccak256(abi.encodePacked(categories[categoryType].tokens[j].name)) == keccak256(abi.encodePacked(tokenNames[i])) && categories[categoryType].tokens[j].tokenAddress == tokenAddresses[i]) {
                    delete categories[categoryType].tokens[j];
                }
            }
        }
    }

    /**
     * @dev The function to update the project rate
     * @param _fillRate The new project rate
     */
     function updatefillRate(uint256 _fillRate) public onlyOwner {
        fillRate = _fillRate;
    }

    /**
     * @dev The function to mint an NFT
     * @param categoryType The category type
     */
    function mint(string memory categoryType) public {
        // Check if the user has enough USDC allowance
        if (usdc.allowance(msg.sender, address(this)) < categories[categoryType].price) {
            revert InsufficientUSDCAllowance();
        }
        // Check if the category is fully minted
        if (categories[categoryType].minted >= categories[categoryType].supply) {
            revert CategoryFullyMinted();
        }

        // Transfer USDC from the user to the contract as payment
        usdc.transferFrom(msg.sender, address(this), categories[categoryType].price);

        // Mint the NFT using the ERC721 _safeMint function
        // The token ID could be calculated or generated based on different factors
        // For example:
        uint256 tokenId = categories[categoryType].minted + 1;
        _safeMint(msg.sender, tokenId);

        // Update minted supply
        categories[categoryType].minted += 1;

        // Here we could call a stub function that simulates the process
        // of investing the minted funds into crypto currencies using Uniswap
        // and the randomness from Chainlink VRF to decide allocation.
    }


    /**
     * @dev The function to randomely select repartition of the minted funds into different tokens
     * @param categoryType The category type
     * @param tokenId The token ID
     * @param randomValue The random value from Chainlink VRF
     */
    function _invest(string memory categoryType, uint256 tokenId, uint256 randomValue) internal {
        // Ensure the caller is the owner of the token
        if (ownerOf(tokenId) != msg.sender) {
            revert OwnerOfToken();
        }

        // Retrieve the category
        Category storage category = categories[categoryType];
        Token[] storage tokens = category.tokens;
        uint256 _fillRate = fillRate;
        uint256 totalAmount = (category.price * _fillRate) / 100;

        // The number of tokens determines how we will break down the random value
        uint256[] memory allocations = new uint256[](tokens.length);
        uint256 totalAllocations = 0;

        // Generate random allocations for each token based on randomValue
        for (uint256 i = 0; i < tokens.length; i++) {
            // Generate a pseudo-random allocation, ensuring that at least a minimal amount is allocated
            allocations[i] = (uint256(keccak256(abi.encode(randomValue, i))) % (totalAmount / tokens.length)) + 1;
            totalAllocations += allocations[i];
        }

        // Normalize allocations so they sum up to totalAmount
        for (uint256 i = 0; i < tokens.length; i++) {
            allocations[i] = (allocations[i] * totalAmount) / totalAllocations;
        }

        // Ensure that rounding errors don't cause us to go over/under the totalAmount
        uint256 distributedAmount = 0;
        for (uint256 i = 0; i < tokens.length - 1; i++) {
            distributedAmount += allocations[i];
        }
        allocations[tokens.length - 1] = totalAmount - distributedAmount;

        // Perform swaps based on the allocations
        for (uint256 i = 0; i < tokens.length; i++) {
            // Calculate the amount for the current token based on the allocation ratio
            uint256 amountForToken = allocations[i];

            _swap(usdc, tokens[i].tokenAddress, amountForToken);
        }

    }

    /**
     * @dev The function to swap USDC for a token
        * @param fromToken The token to swap from
        * @param toToken The token to swap to
        * @param amount The amount to swap
     */
    function _swap(IERC20 fromToken, address toToken, uint256 amount) internal {
        // Here we could call a stub function that simulates the process
        // of swapping the minted funds into crypto currencies using Uniswap
        // and the randomness from Chainlink VRF to decide allocation.
    }

    /**
    * @dev This function request random VRF words depending on the categoryType and tokenID
    * @param categoryType The category type
    * @param tokenId The token ID
    */
    function _requestRandomWords(string memory categoryType, uint256 tokenId) internal {
       uint256 requestId = coordinator.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            1 // Requesting 1 random value for simplicity
        );
        
        // Store the randomness request data
        randomnessRequestData[requestId] = RandomnessRequestData({
            tokenId: tokenId,
            categoryType: categoryType
        });
    }

    /**
     * @dev Fullfill the randomness request
        * @param requestId The request ID
        * @param randomWords memory randomWords The random words
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
       RandomnessRequestData memory requestData = randomnessRequestData[requestId];

        // Use `randomWords` and requestData to distribute funds
        uint256 randomValue = randomWords[0]; // Random value from Chainlink VRF

        _invest(requestData.categoryType, requestData.tokenId, randomValue);

        delete randomnessRequestData[requestId];
    }

        
}
