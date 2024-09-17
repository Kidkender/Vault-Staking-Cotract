// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

pragma solidity ^0.8.20;
// Author: @DuckJHN


interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool); 
    function transferFrom(address spender, address recipient, uint256 amount) external returns (bool);
}

contract VaultStaking is Ownable, ReentrancyGuard {
    IERC20 public token;
 
    uint256 internal _minStake = 500 * 10 ** 18;
    uint256 internal constant BASIC_POINT = 10000;
 
    uint256 public timeLock;
    uint256 public tier;
    uint256 public currentPositionId;
    uint256 public amountStaked;
    uint256 public amountForReward;
 
    constructor(IERC20 _token, uint _timeLock, uint _tier) Ownable(msg.sender) {
        token = _token;
        timeLock = _timeLock;
        tier = _tier;
        amountForReward = 0;
        currentPositionId = 0;
    }
    struct Position {
        uint256 positionId;
        address walletAddress;
        uint256 createdDate;
        uint256 unlockDate;
        uint256 percentInterest;
        uint256 amountStaked;
        uint256 amountInterest;
        bool open;
    }
    // Mapping
    mapping (address => uint256[]) internal positionIds;
    mapping (uint256=> Position) public position;
 
    // Event
    event Staked(address indexed wallet, uint256 indexed positionId, uint256 amount);
    event ClaimReward(address indexed wallet, uint256[] positionId, uint256 amountReward);
    event Withdrawn(uint256 balance);
 
    // Modifier
    modifier onlyOpenPosition(uint256 _positionId) {
        require(position[_positionId].open, "Position not open");
        _;
    }
 
    modifier onlyStaker() {
        require(positionIds[msg.sender].length > 0, "No positions for staker");
        _;
    }
 
    function changeAddressStaking(address _token) external onlyOwner() {
        token = IERC20(_token);
    }
 
    function changeTimelock(uint256 _newTimelock) external onlyOwner() {
        timeLock = _newTimelock;
    }
 
    function getPostionByAddress(address _wallet) external view returns(uint256[] memory) {
        return positionIds[_wallet];
    }
 
    function getCurrentAmountPool() public view returns (uint256) {
        return token.balanceOf(address(this));
    }
 
    function _getRewardAmountOfPool() internal view returns (uint256) {
        return getCurrentAmountPool() - amountStaked;
    }
 
    function _restAvailableAmount() internal view returns (uint256) {
        uint rewardAmountOfPool = _getRewardAmountOfPool();
        return rewardAmountOfPool > amountForReward ? rewardAmountOfPool - amountForReward : 0;
    }
 
    function calculateReward(uint256 _amountStaking) internal view returns (uint256) {
        // Reward = (Amount x Percent) x DayNumber/365
        return (_amountStaking * tier * timeLock ) / (BASIC_POINT * 365);
    }
 
    function _poolCanStake( uint256 _amountReward) internal view returns (bool) {
        return _amountReward <= _restAvailableAmount();
    }

    function changeMinStake(uint256 _newMin) external onlyOwner {
        _minStake = _newMin;
    }
 
    function stake(uint256 _amountStaking) external nonReentrant {
        require(token.balanceOf(msg.sender) >= _amountStaking, "Insufficient balance");
        require(token.allowance(msg.sender, address(this)) >= _amountStaking, "Insufficient allowance");
        require(_amountStaking >= _minStake, "Amount too small");
        uint256 amountReward = calculateReward(_amountStaking);

        require(_poolCanStake(amountReward), "Pool is full");

        amountStaked += _amountStaking;
        amountForReward += amountReward;

        position[currentPositionId] = Position({
            positionId: currentPositionId,
            walletAddress: msg.sender,
            createdDate: block.timestamp,
            unlockDate: block.timestamp + (timeLock * 1 minutes),
            percentInterest: tier,
            amountStaked: _amountStaking,
            amountInterest: amountReward,
            open: true
        });

        positionIds[msg.sender].push(currentPositionId);
        emit Staked(msg.sender, currentPositionId, _amountStaking);

        require(token.transferFrom(msg.sender, address(this), _amountStaking), "Transfer token failed");

        ++currentPositionId;
    }

 
    function claimAll() external onlyStaker nonReentrant {
        uint256 totalAmountToClaim = 0;
        uint256 totalAmountReward = 0;
 
        uint256[] storage userPositions = positionIds[msg.sender];
        uint256 length = userPositions.length;
 
        uint256[] memory claimedPositionIds = new uint256[](length);
        uint256 claimedCount = 0;
 
        for (uint256 i = 0; i < length; i++) {
            uint256 positionId = userPositions[i];
            Position storage positionStaking = position[positionId];
            if (positionStaking.open && positionStaking.unlockDate <= block.timestamp) {
                uint256 amountClaim = positionStaking.amountStaked + positionStaking.amountInterest;
                positionStaking.open = false;
 
                claimedPositionIds[claimedCount] = positionId;
                claimedCount++;
 
                totalAmountToClaim += amountClaim;
                totalAmountReward += positionStaking.amountInterest;
                amountForReward -= positionStaking.amountInterest;
                amountStaked -= positionStaking.amountStaked;
            }
        }
 
        require(totalAmountToClaim > 0, "No positions eligible for claiming");
        require(token.transfer(msg.sender, totalAmountToClaim), "Token transfer failed");
 
        for (uint256 i = length; i > 0; i--) {
            uint256 positionId = userPositions[i - 1];
            if (!position[positionId].open) {
                userPositions[i - 1] = userPositions[userPositions.length - 1];
                userPositions.pop();
            }
        }
 
        uint256[] memory finalClaimedPositionIds = new uint256[](claimedCount);
        for (uint256 i = 0; i < claimedCount; i++) {
            finalClaimedPositionIds[i] = claimedPositionIds[i];
        }
 
        emit ClaimReward(msg.sender, finalClaimedPositionIds, totalAmountReward);
    }
 
    function withdraw() external onlyOwner nonReentrant {
        uint256 restAmount = _restAvailableAmount();
        require(token.transfer(msg.sender, restAmount), "Withdraw failed");
        emit Withdrawn(restAmount);
    }
}
