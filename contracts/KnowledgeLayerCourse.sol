// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

import {IKnowledgeLayerID} from "./interfaces/IKnowledgeLayerID.sol";

contract KnowledgeLayerCourse is ERC1155, Ownable {
    using Counters for Counters.Counter;

    /**
     * @dev Course struct
     * @param ownerId KnowledgeLayer ID of the teacher
     * @param price Price of the course
     * @param dataUri URI of the course data
     */
    struct Course {
        uint256 ownerId;
        uint256 price;
        string dataUri;
    }

    // Course id to course
    mapping(uint256 => Course) public courses;

    // Course id counter
    Counters.Counter nextCourseId;

    // Protocol fee per sale (percentage per 10,000, upgradable)
    uint16 public protocolFee;

    // Divider used for fees
    uint16 private constant FEE_DIVIDER = 10000;

    // KnowledgeLayerID contract
    IKnowledgeLayerID private knowledgeLayerId;

    // =========================== Events ==============================

    /**
     * @dev Emitted when a new course is created
     */
    event CourseCreated(uint256 indexed courseId, address indexed seller, uint256 price, string dataUri);

    /**
     * @dev Emitted when a course is bought
     */
    event CourseBought(uint256 indexed courseId, address indexed buyer, uint256 price, uint256 fee);

    /**
     * @dev Emitted when the price of a course is updated
     */
    event CoursePriceUpdated(uint256 indexed courseId, uint256 price);

    /**
     * @dev Emitted when the protocol fee is updated
     */
    event ProtocolFeeUpdated(uint256 fee);

    // =========================== Modifiers ==============================

    /**
     * @notice Check if the given address is either the owner of the delegate of the given user
     * @param _profileId The TalentLayer ID of the user
     */
    modifier onlyOwnerOrDelegate(uint256 _profileId) {
        require(knowledgeLayerId.isOwnerOrDelegate(_profileId, _msgSender()), "Not owner or delegate");
        _;
    }

    // =========================== Constructor ==============================

    /**
     * @param _knowledgeLayerIdAddress Address of the KnowledgeLayerID contract
     */
    constructor(address _knowledgeLayerIdAddress) ERC1155("") {
        knowledgeLayerId = IKnowledgeLayerID(_knowledgeLayerIdAddress);
        setProtocolFee(500);
        nextCourseId.increment();
    }

    // =========================== User functions ==============================

    /**
     * @dev Creates a new course
     * @param _profileId The KnowledgeLayer ID of the user owner of the service
     * @param _price Price of the course in EURe tokens
     * @param _dataUri URI of the course data
     */
    function createCourse(
        uint256 _profileId,
        uint256 _price,
        string memory _dataUri
    ) public onlyOwnerOrDelegate(_profileId) {
        uint256 id = nextCourseId.current();
        Course memory course = Course(_profileId, _price, _dataUri);
        courses[id] = course;
        nextCourseId.increment();

        emit CourseCreated(id, msg.sender, _price, _dataUri);
    }

    /**
     * @dev Updates the price of the course
     * @param _profileId The KnowledgeLayer ID of the user owner of the service
     * @param _courseId Id of the course
     * @param _price New price of the course
     */
    function updateCoursePrice(
        uint256 _profileId,
        uint256 _courseId,
        uint256 _price
    ) public onlyOwnerOrDelegate(_profileId) {
        Course storage course = courses[_courseId];
        require(course.ownerId == _profileId, "Not the owner");
        course.price = _price;

        emit CoursePriceUpdated(_courseId, _price);
    }

    /**
     * @dev Buys the course by paying the price
     * @param _courseId Id of the course
     */
    function buyCourse(uint256 _courseId) public payable {
        Course memory course = courses[_courseId];
        require(msg.value == course.price, "Not enough ETH sent");

        _mint(msg.sender, _courseId, 1, "");

        uint256 fee = (protocolFee * msg.value) / FEE_DIVIDER;

        (bool sentSeller, ) = payable(knowledgeLayerId.ownerOf(course.ownerId)).call{value: msg.value - fee}("");
        require(sentSeller, "Failed to send Ether to seller");

        (bool sentOwner, ) = payable(owner()).call{value: fee}("");
        require(sentOwner, "Failed to send Ether to owner");

        emit CourseBought(_courseId, msg.sender, msg.value, fee);
    }

    // =========================== Owner functions ==============================

    /**
     * @dev Sets the protocol fee per sale
     * @param _protocolFee Protocol fee per sale (percentage per 10,000)
     */
    function setProtocolFee(uint16 _protocolFee) public onlyOwner {
        protocolFee = _protocolFee;

        emit ProtocolFeeUpdated(_protocolFee);
    }

    // =========================== Overrides ==============================

    /**
     * @dev Blocks token transfers
     */
    function safeTransferFrom(address, address, uint256, uint256, bytes memory) public virtual override {
        revert("Token transfer is not allowed");
    }

    /**
     * @dev Blocks token transfers
     */
    function safeBatchTransferFrom(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override {
        revert("Token transfer is not allowed");
    }
}
