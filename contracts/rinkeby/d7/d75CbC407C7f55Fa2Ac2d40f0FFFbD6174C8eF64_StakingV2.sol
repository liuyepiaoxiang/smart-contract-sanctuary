// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import { Ownable } from "./abstract/Ownable.sol";
import { StableMath } from "./libraries/StableMath.sol";
import { SafeERC20, IERC20 } from "./libraries/SafeERC20.sol";
import { ReentrancyGuard } from "./external/openzeppelin/ReentrancyGuard.sol";

contract StakingV2 is Ownable, ReentrancyGuard {
    using StableMath for uint256;
    using SafeERC20 for IERC20;
    /**
     * @dev Error codes
     */
    string internal constant ERR_WITHDRAWING = "Not when withdrawing";
    string internal constant ERR_SUPER_STAKER = "Already super staker";
    string internal constant ERR_TRANSFER = "ERC20 transfer error";
    string internal constant ERR_TOO_SOON = "Too soon";
    string internal constant ERR_NO_STAKE = "Nothing staked";
    string internal constant ERR_NO_RESTAKE = "Nothing to restake";
    string internal constant ERR_NO_CLAIM = "Nothing to claim";
    string internal constant ERR_ZERO_AMOUNT = "Zero Amount";
    string internal constant ERR_REWARDER = "Exclude rewarder from fee";

    uint256 private constant WEEK = 7 days;
    uint256 private constant MONTH = 30 days;

    address internal constant ZERO = address(0);

    /// stake/reward token address
    address public immutable tokenAddress;
    /// LP stake token address
    address public immutable liquidityAddress;

    /// time to allow be Super Staker (30*24*60*60)
    uint256 public immutable timeToSuper;
    /// time to wait for unstake (7*24*60*60)
    uint256 public immutable timeToUnstake;
    /// @notice Timestamp for current period finish
    uint256 public periodFinish;
    /// @notice Timestamp for current super period finish
    uint256 public superPeriodFinish;

    struct Data {
        uint256 depositedTokens; // deposited tokens amount
        uint256 depositedLiquidity; // deposited lp amount
        uint256 totalRewardsAdded; // accumulated amount of rewards added to token and liquidity staking
        uint256 totalRewardsClaimed; // accumulated amount of rewards claimed
        uint256 totalRewardsFromFees; // accumulated amount of rewards collected from fee-on-transfer
    }

    Data public data;

    struct StakingData {
        uint256 rewardRate;
        uint256 superRewardRate;
        uint256 lastUpdateTime;
        uint256 lastSuperUpdateTime;
        uint256 rewardPerTokenStored; // accumulated per token reward since the beginning of time
        uint256 superRewardPerTokenStored; // super accumulated per token reward since the beginning of time
        uint256 stakedTokens; // amount of tokens that is used in reward per token calculation
        uint256 stakedSuperTokens; // amount of tokens that is used in super reward per token calculation
    }

    StakingData public tokenStaking;
    StakingData public lpStaking;

    // stake struct
    struct Stake {
        uint256 stakeStart; // timestamp of stake creation
        uint256 superStakerPossibleAt; // timestamp after which user can claim super staker status
        //
        uint256 rewardPerTokenPaid; // user accumulated per token rewards
        uint256 superRewardPerTokenPaid; // user accumulated per token super staker rewards
        //
        uint256 tokens; // total tokens staked by user snp or lp
        uint256 rewards; // current not-claimed rewards from last update
        //
        uint256 withdrawalPossibleAt; // timestamp after which stake can be removed
        bool isWithdrawing; // true = user call to remove stake
        bool isSuperStaker; // true = user is super staker
    }

    // each holder have one stake
    /// Token stakes storage
    mapping(address => Stake) public tokenStake;
    /// LP token stakes storage
    mapping(address => Stake) public liquidityStake;

    // events
    event Claimed(address indexed user, uint256 amount);
    event StakeAdded(address indexed user, uint256 amount);
    event StakeLiquidityAdded(address indexed user, uint256 amount);
    event StakeRemoveRequested(address indexed user);
    event StakeLiquidityRemoveRequested(address indexed user);
    event StakeRemoved(address indexed user, uint256 amount);
    event StakeLiquidityRemoved(address indexed user, uint256 amount);
    event Recalculation(uint256 reward, uint256 lpReward);
    event SuperRecalculation(uint256 superReward, uint256 superLpReward);

    constructor(
        address _token,
        address _liquidity,
        uint256 _timeToSuper,
        uint256 _timeToUnstake
    ) {
        tokenAddress = _token;
        liquidityAddress = _liquidity;
        timeToSuper = _timeToSuper;
        timeToUnstake = _timeToUnstake;
    }

    /** @dev Updates the reward and super rewards for a given address,
     * and all pools, before executing function
     */
    modifier updateRewards(address _account) {
        _updateReward(_account, false);
        _updateReward(_account, true);
        _;
    }

    /** @dev Updates the reward and super rewards for a given address,
     * and for given pool, before executing function
     */
    modifier updateReward(address _account, bool _lp) {
        _updateReward(_account, _lp);
        _;
    }

    /** @dev Updates the reward and super rewards for a given address,
     * and all pools, before executing function
     */
    modifier updateSuperRewards(address _account) {
        _updateSuperReward(_account, false);
        _updateSuperReward(_account, true);
        _;
    }

    /** @dev Updates the reward and super rewards for a given address,
     * and selected pool, before executing function
     */
    modifier updateSuperReward(address _account, bool _lp) {
        _updateSuperReward(_account, _lp);
        _;
    }

    /** @dev  */
    modifier hasPoolStake(address _account, bool _lp) {
        bool accountHasStake = _lp ? (liquidityStake[_account].tokens > 0) : (tokenStake[_account].tokens > 0);
        require(accountHasStake, ERR_NO_STAKE);
        _;
    }

    /** @dev  */
    modifier hasStake() {
        require((liquidityStake[msg.sender].tokens > 0) || (tokenStake[msg.sender].tokens > 0), ERR_NO_STAKE);
        _;
    }

    /** @dev  */
    modifier canBeSuper(address _account, bool _lp) {
        Stake memory s = _lp ? liquidityStake[_account] : tokenStake[_account];
        require(!s.isWithdrawing, ERR_WITHDRAWING);
        require(!s.isSuperStaker, ERR_SUPER_STAKER);
        require(block.timestamp >= s.superStakerPossibleAt, ERR_TOO_SOON);
        _;
    }

    /** @dev  */
    modifier canUnstake() {
        require(_canUnstake(), "Can't unstake");
        _;
    }

    /** @dev  */
    modifier cantUnstake() {
        require(!_canUnstake(), "Unstake first");
        _;
    }

    /***************************************
                    ACTIONS
    ****************************************/

    /** @dev Updates reward in selected pool */
    function _updateReward(address _account, bool _lp) internal {
        uint256 newRewardPerTokenStored = currentRewardPerTokenStored(_lp);
        // If statement protects against loss in initialization case
        if (newRewardPerTokenStored > 0) {
            StakingData storage sd = _lp ? lpStaking : tokenStaking;
            sd.rewardPerTokenStored = newRewardPerTokenStored;
            sd.lastUpdateTime = lastTimeRewardApplicable();

            // Setting of personal vars based on new globals
            if (_account != ZERO) {
                Stake storage s = _lp ? liquidityStake[_account] : tokenStake[_account];
                if (!s.isWithdrawing) {
                    s.rewards = _earned(_account, _lp);
                    s.rewardPerTokenPaid = newRewardPerTokenStored;
                }
            }
        }
    }

    /** @dev Updates super reward in selected pool */
    function _updateSuperReward(address _account, bool _lp) internal {
        Stake storage s = _lp ? liquidityStake[_account] : tokenStake[_account];
        // save gas for non super stakers
        if (s.isSuperStaker || _account == ZERO) {
            uint256 newSuperRewardPerTokenStored = currentSuperRewardPerTokenStored(_lp);
            // If statement protects against loss in initialization case
            if (newSuperRewardPerTokenStored > 0) {
                StakingData storage sd = _lp ? lpStaking : tokenStaking;
                sd.superRewardPerTokenStored = newSuperRewardPerTokenStored;
                sd.lastSuperUpdateTime = lastTimeSuperRewardApplicable();

                // Setting of personal vars based on new globals
                if (_account != ZERO) {
                    // Setting of personal vars based on new globals
                    if (!s.isWithdrawing) {
                        s.rewards = _earnedSuper(_account, _lp);
                        s.superRewardPerTokenPaid = newSuperRewardPerTokenStored;
                    }
                }
            }

            _calculateSuperRewardAmount();
        }
    }

    /**
    Add tokens for staking
    @param amount of tokens to stake
    */
    function addTokenStake(uint256 amount) external {
        _addStake(msg.sender, amount, false);
        emit StakeAdded(msg.sender, amount);
    }

    /**
    @notice Add tokens to staking using permit to set allowance
    @param amount of tokens to stake
    @param deadline of permit signature
    @param approveMax allowance for the token
    */
    function addTokenStakeWithPermit(
        uint256 amount,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        uint256 value = approveMax ? type(uint256).max : amount;
        IERC20(tokenAddress).permit(msg.sender, address(this), value, deadline, v, r, s);
        _addStake(msg.sender, amount, false);
        emit StakeAdded(msg.sender, amount);
    }

    /**
    Add liquidity tokens for staking
    @param amount of tokens to stake
    */
    function addLiquidityStake(uint256 amount) external {
        _addStake(msg.sender, amount, true);
        emit StakeLiquidityAdded(msg.sender, amount);
    }

    /**
    @notice Add liquidity tokens for staking
    @param amount of tokens to stake
    @param deadline of permit signature
    @param approveMax allowance for the token
    */
    function addLiquidityStakeWithPermit(
        uint256 amount,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        uint256 value = approveMax ? type(uint256).max : amount;
        IERC20(liquidityAddress).permit(msg.sender, address(this), value, deadline, v, r, s);
        _addStake(msg.sender, amount, true);
        emit StakeLiquidityAdded(msg.sender, amount);
    }

    // Internal add stake function
    function _addStake(
        address _account,
        uint256 _amount,
        bool _lp
    ) internal nonReentrant updateReward(_account, _lp) updateSuperReward(_account, _lp) {
        require(_amount > 0, ERR_ZERO_AMOUNT);
        Stake storage s = _lp ? liquidityStake[_account] : tokenStake[_account];
        require(!s.isWithdrawing, ERR_WITHDRAWING);

        address token = _lp ? liquidityAddress : tokenAddress;

        // check for fee-on-transfer and proceed with received amount
        _amount = _transferFrom(token, msg.sender, _amount);

        if (s.stakeStart == 0) {
            // new stake
            s.stakeStart = block.timestamp;
            s.superStakerPossibleAt = s.stakeStart + timeToSuper;
        }

        StakingData storage sd = _lp ? lpStaking : tokenStaking;

        // update account stake data
        s.tokens += _amount;

        // update pool staking data
        sd.stakedTokens += _amount;
        if (s.isSuperStaker) {
            sd.stakedSuperTokens += _amount;
        }

        // update global data
        if (_lp) {
            data.depositedLiquidity += _amount;
        } else {
            data.depositedTokens += _amount;
        }
    }

    /**
     * Restake earned tokens and add to token stake (instead of claiming)
     * If have LP stake but not token stake - token stake will be created.
     */
    function restake() external hasStake updateRewards(msg.sender) updateSuperRewards(msg.sender) {
        Stake storage ts = tokenStake[msg.sender];
        Stake storage ls = liquidityStake[msg.sender];
        require(!ts.isWithdrawing, ERR_WITHDRAWING);

        uint256 rewards = ts.rewards + ls.rewards;
        require(rewards > 0, ERR_NO_RESTAKE);

        delete ts.rewards;
        delete ls.rewards;

        if (ts.stakeStart == 0) {
            // new stake
            ts.stakeStart = block.timestamp;
            ts.superStakerPossibleAt = ts.stakeStart + timeToSuper;
        }

        // update account stake data
        ts.tokens += rewards;

        // update pool staking data
        tokenStaking.stakedTokens += rewards;
        if (ts.isSuperStaker) {
            tokenStaking.stakedSuperTokens += rewards;
        }

        data.totalRewardsClaimed += rewards;
        data.depositedTokens += rewards;

        emit Claimed(msg.sender, rewards);
        emit StakeAdded(msg.sender, rewards);
    }

    /**
     * Claim reward tokens
     */
    function claim() external {
        _claim(msg.sender, msg.sender);
    }

    /**
     * Claim reward tokens to address
     * @param _recipient address where claimed tokens should be sent
     */
    function claimTo(address _recipient) external {
        _claim(msg.sender, _recipient);
    }

    // internal claim function, update user stakes and
    function _claim(address _account, address _recipient) internal nonReentrant hasStake updateRewards(_account) updateSuperRewards(_account) {
        uint256 rewards = tokenStake[_account].rewards + liquidityStake[_account].rewards;

        require(rewards > 0, ERR_NO_CLAIM);

        delete tokenStake[_account].rewards;
        delete liquidityStake[_account].rewards;

        data.totalRewardsClaimed += rewards;
        require(_transfer(tokenAddress, _recipient, rewards), ERR_TRANSFER);

        emit Claimed(_account, rewards);
    }

    /**
    Request unstake tokens
    */
    function requestUnstake() external {
        _requestUnstake(msg.sender, false);
        emit StakeRemoveRequested(msg.sender);
    }

    /**
    Request unstake LP tokens
    */
    function requestUnstakeLp() external {
        _requestUnstake(msg.sender, true);
        emit StakeLiquidityRemoveRequested(msg.sender);
    }

    /**
     * Internal request unstake function
     * @param _account User address
     * @param _lp true=> it is LP stake
     */
    function _requestUnstake(address _account, bool _lp) internal hasPoolStake(_account, _lp) updateReward(_account, _lp) {
        Stake storage s = _lp ? liquidityStake[_account] : tokenStake[_account];
        require(!s.isWithdrawing, ERR_WITHDRAWING);
        StakingData storage sd = _lp ? lpStaking : tokenStaking;

        // update account stake data
        s.isWithdrawing = true;
        s.withdrawalPossibleAt = block.timestamp + timeToUnstake;

        // update pool staking data
        sd.stakedTokens -= s.tokens;
        if (s.isSuperStaker) {
            delete s.isSuperStaker;
            sd.stakedSuperTokens -= s.tokens;
        }
    }

    /**
     * Withdraw stake from both stakes (if possible)
     */
    function unstake() external nonReentrant hasStake canUnstake {
        bool success;
        uint256 reward;
        uint256 tokens;
        uint256 rewards;

        (reward, success) = _unstake(msg.sender, false);
        rewards += reward;
        if (success) {
            tokens += tokenStake[msg.sender].tokens;
            data.depositedTokens -= tokenStake[msg.sender].tokens;
            emit StakeRemoved(msg.sender, tokenStake[msg.sender].tokens);
            delete tokenStake[msg.sender];
        }

        (reward, success) = _unstake(msg.sender, true);
        rewards += reward;
        if (success) {
            delete liquidityStake[msg.sender];
        }

        if (tokens + rewards > 0) {
            require(_transfer(tokenAddress, msg.sender, tokens + rewards), ERR_TRANSFER);
            if (rewards > 0) {
                emit Claimed(msg.sender, rewards);
            }
        }
    }

    /**
     * Internal unstake function, withdraw staked LP tokens
     * @param _account address of account to transfer LP tokens
     * @param _lp true = LP stake
     * @return stake rewards amount
     * @return bool true if success
     */
    function _unstake(address _account, bool _lp) internal returns (uint256, bool) {
        Stake memory s = _lp ? liquidityStake[_account] : tokenStake[_account];
        if (!s.isWithdrawing) return (0, false);
        if (s.withdrawalPossibleAt > block.timestamp) return (0, false);

        data.totalRewardsClaimed += s.rewards;

        // only LP stake
        if (_lp && s.tokens > 0) {
            data.depositedLiquidity -= s.tokens;
            require(_transfer(liquidityAddress, _account, s.tokens), ERR_TRANSFER);
            emit StakeLiquidityRemoved(_account, s.tokens);
        }

        return (s.rewards, true);
    }

    /**
     * Unstake requested stake at any time accepting 10% penalty fee
     */
    function unstakeWithFee() external nonReentrant hasStake cantUnstake {
        Stake memory ts = tokenStake[msg.sender];
        Stake memory ls = liquidityStake[msg.sender];
        uint256 tokens;
        uint256 rewards;

        if (ls.isWithdrawing) {
            uint256 lpTokens = (ls.tokens * 9) / 10; //remaining tokens remain on the contract TODO: funkcja na wypłate LP.
            data.totalRewardsClaimed += ls.rewards;
            rewards += ls.rewards;

            // sanity check, it should be always true here, edge case l.tokens = 1e0
            if (lpTokens > 0) {
                data.depositedLiquidity -= ls.tokens;
                emit StakeLiquidityRemoved(msg.sender, ls.tokens);
                require(_transfer(liquidityAddress, msg.sender, lpTokens), ERR_TRANSFER);
            }

            delete liquidityStake[msg.sender];
        }

        if (ts.isWithdrawing) {
            tokens = (ts.tokens * 9) / 10; // remaining tokens goes to Super Stakers

            data.totalRewardsClaimed += ts.rewards;
            rewards += ts.rewards;

            // also always should be true
            if (tokens > 0) {
                data.depositedTokens -= ts.tokens;
                emit StakeRemoved(msg.sender, ts.tokens);
            }

            delete tokenStake[msg.sender];
        }

        if (tokens + rewards > 0) {
            require(_transfer(tokenAddress, msg.sender, tokens + rewards), ERR_TRANSFER);
            if (rewards > 0) {
                emit Claimed(msg.sender, rewards);
            }
        }
    }

    /**
     * Set Super Staker status for token pool stake if possible
     */
    function setSuperToken() external {
        _setSuper(msg.sender, false);
    }

    /**
     * Set Super Staker status for LP pool stake if possible
     */
    function setSuperLp() external {
        _setSuper(msg.sender, true);
    }

    /**
     * Set Super Staker status if possible for selected pool
     * Update super rewards pool
     * @param _account address of account to set super
     * @param _lp address of account to set super
     */
    function _setSuper(address _account, bool _lp) internal hasPoolStake(_account, _lp) canBeSuper(_account, _lp) updateSuperReward(ZERO, _lp) {
        Stake storage s = _lp ? liquidityStake[_account] : tokenStake[_account];
        StakingData storage sd = _lp ? lpStaking : tokenStaking;

        sd.stakedSuperTokens += s.tokens;

        s.isSuperStaker = true;
        s.superRewardPerTokenPaid = sd.superRewardPerTokenStored;
    }

    /***************************************
                    GETTERS
    ****************************************/

    /**
     * @dev Gets the last applicable timestamp for this reward period
     */
    function lastTimeRewardApplicable() public view returns (uint256) {
        return StableMath.min(block.timestamp, periodFinish);
    }

    /**
     * @dev Gets the last applicable timestamp for this reward period
     */
    function lastTimeSuperRewardApplicable() public view returns (uint256) {
        return StableMath.min(block.timestamp, superPeriodFinish);
    }

    /**
     * @dev Calculates the amount of unclaimed rewards per token since last update,
     * and sums with stored to give the new cumulative reward per token
     * @return 'Reward' per staked token
     */
    function currentRewardPerTokenStored(bool _lp) public view returns (uint256) {
        StakingData memory sd = _lp ? lpStaking : tokenStaking;
        uint256 stakedTokens = sd.stakedTokens;
        uint256 rewardPerTokenStored = sd.rewardPerTokenStored;
        // If there is no staked tokens, avoid div(0)
        if (stakedTokens == 0) {
            return (rewardPerTokenStored);
        }
        // new reward units to distribute = rewardRate * timeSinceLastUpdate
        uint256 timeDelta = lastTimeRewardApplicable() - sd.lastUpdateTime;
        uint256 rewardUnitsToDistribute = sd.rewardRate * timeDelta;
        // new reward units per token = (rewardUnitsToDistribute * 1e18) / stakedTokens
        uint256 unitsToDistributePerToken = rewardUnitsToDistribute.divPrecisely(stakedTokens);
        // return summed rate
        return (rewardPerTokenStored + unitsToDistributePerToken);
    }

    /**
     * @dev Calculates the amount of unclaimed rewards per token since last update,
     * and sums with stored to give the new cumulative reward per token
     * @return 'Reward' per staked token
     */
    function currentSuperRewardPerTokenStored(bool _lp) public view returns (uint256) {
        StakingData memory sd = _lp ? lpStaking : tokenStaking;
        uint256 stakedSuperTokens = sd.stakedSuperTokens;
        uint256 superRewardPerTokenStored = sd.superRewardPerTokenStored;
        // If there is no staked tokens, avoid div(0)
        if (stakedSuperTokens == 0) {
            return (superRewardPerTokenStored);
        }

        // new reward units to distribute = superRewardRate * timeSinceLastSuperUpdate
        uint256 timeDelta = lastTimeSuperRewardApplicable() - sd.lastSuperUpdateTime;
        uint256 rewardUnitsToDistribute = sd.superRewardRate * timeDelta;
        // new reward units per token = (rewardUnitsToDistribute * 1e18) / totalSuperTokens
        uint256 unitsToDistributePerToken = rewardUnitsToDistribute.divPrecisely(stakedSuperTokens);

        // return summed rate
        return (superRewardPerTokenStored + unitsToDistributePerToken);
    }

    /**
     * @dev Calculates the amount of unclaimed rewards a user has earned
     * @param _account User address
     * @param _lp User address
     * @return Total reward amount earned
     */
    function _earned(address _account, bool _lp) internal view returns (uint256) {
        Stake memory s = _lp ? liquidityStake[_account] : tokenStake[_account];
        if (s.isWithdrawing) return s.rewards;
        // current rate per token - rate user previously received
        uint256 rewardPerTokenStored = currentRewardPerTokenStored(_lp);
        uint256 userRewardDelta = rewardPerTokenStored - s.rewardPerTokenPaid;
        uint256 userNewReward = s.tokens.mulTruncate(userRewardDelta);
        // add to previous rewards
        return (s.rewards + userNewReward);
    }

    /**
     * @dev Calculates the amount of unclaimed super rewards a user has earned
     * @param _account User address
     * @param _lp User address
     * @return Total reward amount earned
     */
    function _earnedSuper(address _account, bool _lp) internal view returns (uint256) {
        Stake memory s = _lp ? liquidityStake[_account] : tokenStake[_account];
        if (!s.isSuperStaker || s.isWithdrawing) return s.rewards;
        // current rate per token - rate user previously received
        uint256 superRewardPerTokenStored = currentSuperRewardPerTokenStored(_lp);
        uint256 superRewardDelta = superRewardPerTokenStored - s.superRewardPerTokenPaid;
        uint256 userNewSuperReward = s.tokens.mulTruncate(superRewardDelta);
        // add to previous rewards
        return (s.rewards + userNewSuperReward);
    }

    function claimable(address _account) external view returns (uint256 token, uint256 lp) {
        token = _earned(_account, false) + _earnedSuper(_account, false) - tokenStake[_account].rewards;
        lp = _earned(_account, true) + _earnedSuper(_account, true) - liquidityStake[_account].rewards;
    }

    /**
     * Check if staker can set Super Staker status on token or LP stake
     * @param _account address to check
     * @return token true if can set SS on token stake
     * @return lp true if can set SS on LP stake
     */
    function canSetSuper(address _account) external view returns (bool token, bool lp) {
        Stake memory ts = tokenStake[_account];
        Stake memory ls = liquidityStake[_account];
        if (ts.tokens > 0 && block.timestamp >= ts.superStakerPossibleAt && !ts.isSuperStaker && !ts.isWithdrawing) token = true;
        if (ls.tokens > 0 && block.timestamp >= ls.superStakerPossibleAt && !ls.isSuperStaker && !ls.isWithdrawing) lp = true;
    }

    function _canUnstake() private view returns (bool) {
        return
            (liquidityStake[msg.sender].isWithdrawing && block.timestamp >= liquidityStake[msg.sender].withdrawalPossibleAt) ||
            (tokenStake[msg.sender].isWithdrawing && block.timestamp >= tokenStake[msg.sender].withdrawalPossibleAt);
    }

    /***************************************
                    ADMIN
    ****************************************/

    /**
     * @dev Notifies the contract that new rewards have been added.
     * Calculates an updated rewardRate based on the rewards in period.
     * @param _reward Units of SNP token that have been added to the token pool
     * @param _lpReward Units of SNP token that have been added to the lp pool
     */
    function notifyRewardAmount(uint256 _reward, uint256 _lpReward) external onlyOwner updateRewards(ZERO) {
        uint256 currentTime = block.timestamp;

        // pull tokens
        require(_transferFrom(tokenAddress, msg.sender, _reward + _lpReward) == _reward + _lpReward, ERR_REWARDER);

        // If previous period over, reset rewardRate
        if (currentTime >= periodFinish) {
            tokenStaking.rewardRate = _reward / WEEK;
            lpStaking.rewardRate = _lpReward / WEEK;
        }
        // If additional reward to existing period, calc sum
        else {
            uint256 remaining = periodFinish - currentTime;

            uint256 leftoverReward = remaining * tokenStaking.rewardRate;
            tokenStaking.rewardRate = (_reward + leftoverReward) / WEEK;

            uint256 leftoverLpReward = remaining * lpStaking.rewardRate;
            lpStaking.rewardRate = (_lpReward + leftoverLpReward) / WEEK;
        }

        tokenStaking.lastUpdateTime = currentTime;
        lpStaking.lastUpdateTime = currentTime;
        periodFinish = currentTime + WEEK;

        data.totalRewardsAdded += _reward + _lpReward;

        emit Recalculation(_reward, _lpReward);
    }

    /***************************************
                    SUPER STAKER
    ****************************************/

    /**
     * @dev Notifies the contract that new rewards have been added.
     * Calculates an updated superRewardRate based on the rewards in period.
     */
    function _calculateSuperRewardAmount() internal {
        uint256 currentTime = block.timestamp;
        // Do nothing if less then a day from last calculation, save gas
        uint256 lastTime = superPeriodFinish > 0 ? superPeriodFinish - (MONTH - 1 days) : 0;
        if (currentTime >= lastTime) {
            uint256 contractBalance = _balance(tokenAddress, address(this));
            uint256 feesCollected = contractBalance -
                data.depositedTokens -
                (data.totalRewardsAdded + data.totalRewardsFromFees - data.totalRewardsClaimed);
            data.totalRewardsFromFees += feesCollected;

            uint256 superRewards;
            unchecked {
                superRewards = feesCollected / 2;
            }

            // If previous period over, reset rewardRate
            if (currentTime >= superPeriodFinish) {
                tokenStaking.superRewardRate = superRewards / MONTH;
                lpStaking.superRewardRate = superRewards / MONTH;
            }
            // If additional reward to existing period, calc sum
            else {
                uint256 remaining = superPeriodFinish - currentTime;

                uint256 leftoverSuperReward = remaining * tokenStaking.superRewardRate;
                tokenStaking.superRewardRate = (superRewards + leftoverSuperReward) / MONTH;

                uint256 leftoverSuperLpReward = remaining * lpStaking.superRewardRate;
                lpStaking.superRewardRate = (superRewards + leftoverSuperLpReward) / MONTH;
            }

            tokenStaking.lastSuperUpdateTime = currentTime;
            lpStaking.lastSuperUpdateTime = currentTime;
            superPeriodFinish = currentTime + MONTH;

            emit SuperRecalculation(superRewards, superRewards);
        }
    }

    /***************************************
                    TOKEN
    ****************************************/

    //
    // internal ERC20 tools
    //

    function _balance(address token, address user) internal view returns (uint256) {
        return IERC20(token).balanceOf(user);
    }

    function _transferFrom(
        address token,
        address from,
        uint256 amount
    ) internal returns (uint256) {
        return IERC20(token).safeTransferFromDeluxe(from, amount);
    }

    function _transfer(
        address token,
        address to,
        uint256 amount
    ) internal returns (bool) {
        IERC20(token).safeTransfer(to, amount);
        return true;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

abstract contract OwnableData {
    address public owner;
    address public pendingOwner;
}

abstract contract Ownable is OwnableData {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice `owner` defaults to msg.sender on construction.
    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /// @notice Transfers ownership to `newOwner`. Either directly or claimable by the new pending owner.
    /// Can only be invoked by the current `owner`.
    /// @param newOwner Address of the new owner.
    /// @param direct True if `newOwner` should be set immediately. False if `newOwner` needs to use `claimOwnership`.
    function transferOwnership(address newOwner, bool direct) public onlyOwner {
        if (direct) {
            // Checks
            require(newOwner != address(0), "Ownable: zero address");

            // Effects
            emit OwnershipTransferred(owner, newOwner);
            owner = newOwner;
            pendingOwner = address(0);
        } else {
            // Effects
            pendingOwner = newOwner;
        }
    }

    /// @notice Needs to be called by `pendingOwner` to claim ownership.
    function claimOwnership() public {
        address _pendingOwner = pendingOwner;

        // Checks
        require(msg.sender == _pendingOwner, "Ownable: caller != pending owner");

        // Effects
        emit OwnershipTransferred(owner, _pendingOwner);
        owner = _pendingOwner;
        pendingOwner = address(0);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);

    // EIP 2612
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function nonces(address owner) external view returns (uint256);
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
    function transferWithPermit(address target, address to, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "../interfaces/IERC20.sol";

library SafeERC20 {
    function safeSymbol(IERC20 token) internal view returns (string memory) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(0x95d89b41));
        return success && data.length > 0 ? abi.decode(data, (string)) : "???";
    }

    function safeName(IERC20 token) internal view returns (string memory) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(0x06fdde03));
        return success && data.length > 0 ? abi.decode(data, (string)) : "???";
    }

    function safeDecimals(IERC20 token) internal view returns (uint8) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(0x313ce567));
        return success && data.length == 32 ? abi.decode(data, (uint8)) : 18;
    }

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0xa9059cbb, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: Transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, uint256 amount) internal {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0x23b872dd, from, address(this), amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: TransferFrom failed");
    }

    function safeTransferFromDeluxe(IERC20 token, address from, uint256 amount) internal returns (uint256) {
        uint256 preBalance = token.balanceOf(address(this));
        safeTransferFrom(token, from, amount);
        uint256 postBalance = token.balanceOf(address(this));
        return postBalance - preBalance;
    }
}

// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.6;

// Based on StableMath from mStable
// https://github.com/mstable/mStable-contracts/blob/master/contracts/shared/StableMath.sol

library StableMath {
    /**
     * @dev Scaling unit for use in specific calculations,
     * where 1 * 10**18, or 1e18 represents a unit '1'
     */
    uint256 private constant FULL_SCALE = 1e18;

    /**
     * @dev Provides an interface to the scaling unit
     * @return Scaling unit (1e18 or 1 * 10**18)
     */
    function getFullScale() internal pure returns (uint256) {
        return FULL_SCALE;
    }

    /**
     * @dev Scales a given integer to the power of the full scale.
     * @param x   Simple uint256 to scale
     * @return    Scaled value a to an exact number
     */
    function scaleInteger(uint256 x) internal pure returns (uint256) {
        return x * FULL_SCALE;
    }

    /***************************************
              PRECISE ARITHMETIC
    ****************************************/

    /**
     * @dev Multiplies two precise units, and then truncates by the full scale
     * @param x     Left hand input to multiplication
     * @param y     Right hand input to multiplication
     * @return      Result after multiplying the two inputs and then dividing by the shared
     *              scale unit
     */
    function mulTruncate(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulTruncateScale(x, y, FULL_SCALE);
    }

    /**
     * @dev Multiplies two precise units, and then truncates by the given scale. For example,
     * when calculating 90% of 10e18, (10e18 * 9e17) / 1e18 = (9e36) / 1e18 = 9e18
     * @param x     Left hand input to multiplication
     * @param y     Right hand input to multiplication
     * @param scale Scale unit
     * @return      Result after multiplying the two inputs and then dividing by the shared
     *              scale unit
     */
    function mulTruncateScale(
        uint256 x,
        uint256 y,
        uint256 scale
    ) internal pure returns (uint256) {
        // e.g. assume scale = fullScale
        // z = 10e18 * 9e17 = 9e36
        // return 9e36 / 1e18 = 9e18
        return (x * y) / scale;
    }

    /**
     * @dev Multiplies two precise units, and then truncates by the full scale, rounding up the result
     * @param x     Left hand input to multiplication
     * @param y     Right hand input to multiplication
     * @return      Result after multiplying the two inputs and then dividing by the shared
     *              scale unit, rounded up to the closest base unit.
     */
    function mulTruncateCeil(uint256 x, uint256 y) internal pure returns (uint256) {
        // e.g. 8e17 * 17268172638 = 138145381104e17
        uint256 scaled = x * y;
        // e.g. 138145381104e17 + 9.99...e17 = 138145381113.99...e17
        uint256 ceil = scaled + FULL_SCALE - 1;
        // e.g. 13814538111.399...e18 / 1e18 = 13814538111
        return ceil / FULL_SCALE;
    }

    /**
     * @dev Precisely divides two units, by first scaling the left hand operand. Useful
     *      for finding percentage weightings, i.e. 8e18/10e18 = 80% (or 8e17)
     * @param x     Left hand input to division
     * @param y     Right hand input to division
     * @return      Result after multiplying the left operand by the scale, and
     *              executing the division on the right hand input.
     */
    function divPrecisely(uint256 x, uint256 y) internal pure returns (uint256) {
        // e.g. 8e18 * 1e18 = 8e36
        // e.g. 8e36 / 10e18 = 8e17
        return (x * FULL_SCALE) / y;
    }

    /***************************************
                    HELPERS
    ****************************************/

    /**
     * @dev Calculates minimum of two numbers
     * @param x     Left hand input
     * @param y     Right hand input
     * @return      Minimum of the two inputs
     */
    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x > y ? y : x;
    }

    /**
     * @dev Calculated maximum of two numbers
     * @param x     Left hand input
     * @param y     Right hand input
     * @return      Maximum of the two inputs
     */
    function max(uint256 x, uint256 y) internal pure returns (uint256) {
        return x > y ? x : y;
    }

    /**
     * @dev Clamps a value to an upper bound
     * @param x           Left hand input
     * @param upperBound  Maximum possible value to return
     * @return            Input x clamped to a maximum value, upperBound
     */
    function clamp(uint256 x, uint256 upperBound) internal pure returns (uint256) {
        return x > upperBound ? upperBound : x;
    }
}

