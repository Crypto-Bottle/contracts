// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
//import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CryptoCuvee is Initializable, UUPSUpgradeable, ERC721Upgradeable, OwnableUpgradeable, VRFConsumerBaseV2 {
    // Define the USDC token interface
    IERC20 public usdc;

    // Struct to define NFT categories and pricing
    struct Category {
        string name;
        uint256 price;
        uint256 supply;
        uint256 minted;
    }

    // A mapping from category type to its corresponding data
    mapping(string => Category) public categories;

    // Initializer function in place of a constructor for upgradeable contracts
    function initialize(IERC20 _usdc) public initializer {
        __ERC721_init("CryptoCuvee", "CCV");
        __Ownable_init(_msgSender());
        usdc = _usdc;

        // Initialize categories here with prices and supply limits
        // For example:
        categories["White"] = Category("White", 1e6, 100, 0); // Example values
        categories["Red"] = Category("Red", 2e6, 100, 0); // Example values
        categories["Rose"] = Category("Rose", 3e6, 100, 0); // Example values
        categories["Champagne"] = Category("Champagne", 4e6, 100, 0); // Example values
    }

    // Implement the required function from UUPSUpgradeable
    function _authorizeUpgrade(address) internal override onlyOwner {}

    // The function for minting new NFTs with USDC payment
    function mint(string memory categoryType) public {
        require(usdc.allowance(msg.sender, address(this)) >= categories[categoryType].price, "Insufficient USDC allowance.");
        require(categories[categoryType].minted < categories[categoryType].supply, "Category fully minted.");

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
}
