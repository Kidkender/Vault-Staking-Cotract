// SPDX-License-Identifier: UNLICENSED
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool); 
    function transferFrom(address spender, address recipient, uint256 amount) external returns (bool);
}

contract StakingTerrabet is Ownable, ReentrancyGuard {
    IERC20 public token;

    uint private constant MIN_STAKE = 50_000 * 10 ** 18;
    uint private constant INITIAL_POOL_AMOUNT = 2_500_000 * 10 ** 18;

    struct Position {
        uint positionId;
        address walletAddress;
        uint256 createdDate;
        uint256 unlockDate;
        uint dayStaking;
        uint percentInterest;
        uint amountStaked;
        uint amountInterest;
        bool open;
    }

    struct YieldStaking {
        uint numDays;
        uint tier;
        uint amountPool;
    }

    Position position;
    YieldStaking[] public yields;
    uint public currentPositionId;
    uint public amountForReward;

    // Mapping
    mapping (uint => Position) public positions;
    mapping (address => uint[]) private positionIds;
    mapping (uint => YieldStaking) public yieldMapping;
    mapping (uint => uint) public amountPoolStaked;

    uint[] private validStakingDays = [1, 7, 30, 90];

    // Events
    event Staked(address indexed wallet, uint256 time, uint indexed positionId, uint amount);
    event ClaimStaking(address indexed wallet, uint256 time, uint indexed positionId, uint amount);
    event Withdrawn(uint256 time, uint balance);
    event YieldStakingUpdated(uint indexed numDays, uint newTier, uint newAmountPool);

    constructor(IERC20 _token) Ownable(msg.sender) {
        token = _token;
        currentPositionId = 0;
        amountForReward = 0;

        yields.push(YieldStaking(1, 800, INITIAL_POOL_AMOUNT));
        yields.push(YieldStaking(7, 1100, INITIAL_POOL_AMOUNT));
        yields.push(YieldStaking(30, 1500, INITIAL_POOL_AMOUNT));
        yields.push(YieldStaking(90, 2300, INITIAL_POOL_AMOUNT));
    }

    // Modifier
    modifier onlyOpenPosition(uint _positionId) {
        require(positions[_positionId].open, "Position not open");
        _;
    }

    modifier onlyStaker() {
        require(positionIds[msg.sender].length > 0, "No positions for staker");
        _;
    }

    function getCurrentAmountPool() public view returns (uint) {
        return token.balanceOf(address(this));
    }

    function getAmountPoolStaked(uint poolDays) public view returns (uint) {
        return amountPoolStaked[poolDays];
    }

    function getPositionByAddress(address _wallet) public view returns (uint[] memory) {
        return positionIds[_wallet];
    }


    function updateYieldStaking(uint _numDays, uint _newTier, uint _newAmountPool) external onlyOwner {
        YieldStaking storage yield = getYieldStakingFromDay(_numDays);
        yield.tier = _newTier;
        yield.amountPool = _newAmountPool;

        emit YieldStakingUpdated(_numDays, _newTier, _newAmountPool);
    }

    function getTotalAmountStaked() private view returns (uint) {
        uint totalAmountReward = 0;
        for (uint i = 0; i < validStakingDays.length; i++) {
            totalAmountReward += amountPoolStaked[validStakingDays[i]];
        }
        return totalAmountReward;
    }

    function originalAmountPool() public view returns (uint) {
        return getCurrentAmountPool() - getTotalAmountStaked();
    }

    function isValidStakingDay(uint numDayStake) internal view returns (bool) {
        for (uint i = 0; i < validStakingDays.length; i++) {
            if (validStakingDays[i] == numDayStake) {
                return true;
            }
        }
        return false;
    }

    function calculateReward(uint _tier, uint _amountStaking) private pure returns (uint) {
        return (_tier * _amountStaking) / 10000;
    }

    function restAvailableAmount() private view returns (uint) {
        return originalAmountPool() - amountForReward;
    }

    function getYieldStakingFromDay(uint _numDays) private view returns (YieldStaking storage) {
        for (uint i = 0; i < yields.length; i++) {
            if (yields[i].numDays == _numDays) {
                return yields[i];
            }
        }
        revert("YieldStaking not found for the given number of days");
    }

    function poolCanStake(uint _amountPool, uint _amountReward) private view returns (bool) {
        return _amountReward < _amountPool && _amountReward < (originalAmountPool() - amountForReward);
    }

    function stake(uint _numDayStake, uint _amount) external nonReentrant returns (bool) {
        require(_amount >= MIN_STAKE, "Amount stake must be larger than the minimum required");
        require(token.balanceOf(msg.sender) >= _amount, "Insufficient balance for staking");
        require(isValidStakingDay(_numDayStake), "Invalid staking period");

        YieldStaking storage fitYield = getYieldStakingFromDay(_numDayStake);
        uint unlockDays = block.timestamp + (_numDayStake * 1 days);
        uint amountReward = calculateReward(fitYield.tier, _amount);
        require(poolCanStake(fitYield.amountPool, amountReward), "Pool has insufficient balance");

        // Transfer tokens from user to contract
        require(token.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");

        // Update state variables
        positions[currentPositionId] = Position({
            positionId: currentPositionId,
            walletAddress: msg.sender,
            createdDate: block.timestamp,
            unlockDate: unlockDays,
            dayStaking: _numDayStake,
            percentInterest: fitYield.tier,
            amountStaked: _amount,
            amountInterest: amountReward,
            open: true
        });

        fitYield.amountPool -= _amount;
        amountPoolStaked[_numDayStake] += _amount;
        amountForReward += amountReward;
        positionIds[msg.sender].push(currentPositionId);

        emit Staked(msg.sender, block.timestamp, currentPositionId, _amount);
        currentPositionId++;
        return true;
    }

    function removePosition(address wallet, uint positionId) internal returns (bool) {
        uint[] storage positionArray = positionIds[wallet];
        uint length = positionArray.length;

        for (uint i = 0; i < length; i++) {
            if (positionArray[i] == positionId) {
                if (i != length - 1) {
                    positionArray[i] = positionArray[length - 1];
                }
                positionArray.pop();
                break;
            }
        }
        return true;
    }

    function claim(uint _positionId) external onlyStaker onlyOpenPosition(_positionId) nonReentrant {
        Position storage positionStaking = positions[_positionId];
        require(positionStaking.unlockDate <= block.timestamp, "It's not time to unlock the token yet");
        
        uint amountClaim = positionStaking.amountStaked + positionStaking.amountInterest;
        positionStaking.open = false;

        // Transfer tokens from contract to user
        require(token.transfer(msg.sender, amountClaim), "Token transfer failed");
        
        amountPoolStaked[positionStaking.dayStaking] -= positionStaking.amountStaked;
        amountForReward -= positionStaking.amountInterest;

        removePosition(msg.sender, _positionId);
        emit ClaimStaking(msg.sender, block.timestamp, _positionId, amountClaim);
    }

    function withdrawn() external onlyOwner nonReentrant {
        uint restAmount = restAvailableAmount();
        require(token.transfer(msg.sender, restAmount), "Withdraw failed");
        emit Withdrawn(block.timestamp, restAmount);
    }

}