//SourceUnit: Auction.sol

pragma solidity ^0.5.8;

import "./SafeMath.sol";
import "./IERC20.sol";
import "./TransferHelper.sol";
import "./WhitelistAdminRole.sol";
import "./Ownable.sol";

contract Auction is Ownable, WhitelistAdminRole {
    using SafeMath for uint256;

    enum AuctionStatus {
        NONE,
        FINISHED,
        DEAL,
        MINING,
        FAILED
    }

    address public bee;

    uint256 public totalBurnedBEE;

    uint256 public BID_AMOUNT_DELTA = 5 * (10 ** 18);

    // duration before next round
    uint256 public DURATION_BETWEEN_ROUNDS = 24 hours;
    // duration before withdraw
    uint256 public DURATION_BEFORE_WITHDRAW = 24 hours;


    uint256 public DELTA_PRICE_PERCENT = 2200;

    // reward percent
    uint256 public PLAYER_PERCENT = 2272;
    uint256 public INVITE_PERCENT = 3636;
    uint256 public GUAR_POOL_PERCENT = 2272;
    uint256 public BURN_POOL_PERCENT = 1363;
    uint256 public FIXED_WALLET_PERCENT = 454;

    uint256 public layer20BeeAuctionAmount = 5000 * (10 ** 18);
    uint256 public layer10BeeAuctionAmount = 4000 * (10 ** 18);
    uint256 public layer5BeeAuctionAmount = 2000 * (10 ** 18);
    uint256 public layer1BeeAuctionAmount = 1000 * (10 ** 18);

    // auction duration each round
    uint256 public AUCTION_DURATION = 2 days;

    // auction token id
    uint256 public auctionTokenId;

    // current round
    uint256 public currentRound;

    // tokenid => round
    mapping(uint256 => uint256) public roundInfo;

    /////////////////////////// reward pool

    // guarantee pool
    // tokenId => amount
    mapping(uint256 => uint256) public guarPoolBalances;

    // burn pool
    address public burnPool = 0x891cdb91d149f23B1a45D9c5Ca78a88d0cB44C18;

    // fixed address
    address public fixedWallet = 0x9262dd60FBfACB0884295A7369f7EbD9d5B49d58;

    struct AuctionRoundItem {
        uint256 auctionStartTime;  // auction start time
        uint256 auctionEndTime; // auction end time
        uint256 auctionCurrentPrice; // current auction price
        uint256 extraAuctionAmount; // 20% of auction price from prev round
        uint256 playersReward; // players reward
        uint256 inviteReward; // invite reward
        uint256 auctionCurrentAmount; // total amount for bid
        AuctionStatus status; // current round status
        uint256 rewardClaimStartTime; // reward claim start time
        uint256 nftMiningStartTime; // nft mining start time
        uint256 nftMiningEndTime; // nft mining end time
    }

    struct UserGlobal {
        uint256 id;
        address owner;
        address inviter;
        address[] inviteList;
    }
    uint256 uid = 1;
    mapping (address => UserGlobal) public userMapping;
    mapping (uint256 => address) public indexMapping;

    struct User {
        uint256 beeBalance;
        uint256 shares;
        uint256[20] invitePowers;
        uint256 nftMiningRewardReleased;
        bool inviteRewardClaimed;
        bool auctionRewardClaimed;
        bool guarPoolRewardClaimed;
    }

    // auction info
    // tokenId => (round => AuctionRoundItem)
    mapping(uint256 => mapping(uint256 => AuctionRoundItem)) public auctionInfo;

    // user auction balance
    // tokenId -> ( round -> ( address -> User))
    mapping(uint256 => mapping(uint256 => mapping(address => User))) public userInfo;

    // user auction rewards
    mapping(uint256 => mapping(address => uint256)) public userAuctionRewards;

    // user invite rewards
    mapping(uint256 => mapping(address => uint256)) public userInviteRewards;

    // init BEE token address
    constructor(address _bee) public {
        bee = _bee;
    }

    function auctionRound(uint256 tokenId) public view returns (uint256) {
        return roundInfo[tokenId];
    }

    function auctionRounds(uint256[] memory tokenIds) public view returns (uint256[] memory) {
        uint256 len = tokenIds.length;
        uint256[] memory rounds = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            rounds[i] = roundInfo[tokenIds[i]];
        }
        return rounds;
    }

    function removeWhitelistAdmin(address account) public onlyOwner {
        _removeWhitelistAdmin(account);
    }

    function beeBalances(uint256 tokenId, uint256 round, address usr) public view returns (uint256) {
        return userInfo[tokenId][round][usr].beeBalance;
    }

    function beeBalancesTotal(uint256 tokenId, address usr) public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 1; i <= currentRound; i++) {
            total = total.add(userInfo[tokenId][i][usr].beeBalance);
        }
        return total;
    }

    function usrAuctionBeeTotal(uint256 tokenId, uint256 round, address usr) public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 1; i <= round; i++) {
            total = total.add(userInfo[tokenId][i][usr].shares);
        }
        return total;
    }

    function startNFTAuction(uint256 tokenId, uint256 startTime, uint256 startPrice) public onlyWhitelistAdmin {
        if (auctionTokenId != 0) {
            require(auctionInfo[auctionTokenId][currentRound].status == AuctionStatus.DEAL
                    || auctionInfo[auctionTokenId][currentRound].status == AuctionStatus.FAILED, "current round not end");
            require(roundInfo[tokenId] == 0, "tokenId auction end");
        }
    
        auctionTokenId = tokenId;
        currentRound = 1;

        AuctionRoundItem storage item = auctionInfo[tokenId][currentRound];
        item.auctionStartTime = startTime;
        item.auctionEndTime = startTime.add(AUCTION_DURATION);
        item.auctionCurrentPrice = startPrice;

        // reset total burned bee
        totalBurnedBEE = 0;
    }

    function updateExpiredAuction(uint256 tokenId) public {
        require(auctionInfo[tokenId][currentRound].status == AuctionStatus.NONE, "current round is end");
        require(block.timestamp >= auctionInfo[tokenId][currentRound].auctionEndTime, "auction end time not come");

        AuctionRoundItem storage item1 = auctionInfo[tokenId][currentRound];
        if (item1.auctionCurrentPrice > 0 && item1.auctionCurrentAmount >= item1.auctionCurrentPrice) { // enter next round
            if (currentRound == 1) {
                // transfer BEE to fixed wallet， only round 1
                TransferHelper.safeTransfer(bee, fixedWallet, item1.auctionCurrentPrice);
            }

            // set previoud round end
            item1.status = AuctionStatus.FINISHED;

            // dispatch reward(20% * base)
            // 3% -> players of prev round
            uint256 preRound = currentRound.sub(1);
            uint256 extraAuctionAmount = item1.extraAuctionAmount;
            // => prev round player reward
            auctionInfo[tokenId][preRound].playersReward = extraAuctionAmount.mul(PLAYER_PERCENT).div(10000);
            // 10% invite reward of pre round
            auctionInfo[tokenId][preRound].inviteReward = extraAuctionAmount.mul(INVITE_PERCENT).div(10000);
            // 5% -> guarPool
            guarPoolBalances[tokenId] = guarPoolBalances[tokenId].add(extraAuctionAmount.mul(GUAR_POOL_PERCENT).div(10000));
            // 2% -> burn pool
            uint256 burnShares = extraAuctionAmount.mul(BURN_POOL_PERCENT).div(10000);
            totalBurnedBEE = totalBurnedBEE.add(burnShares);
            TransferHelper.safeTransfer(bee, burnPool, burnShares);
            // 1% -> fixed wallet
            uint256 fixedShares = extraAuctionAmount.mul(FIXED_WALLET_PERCENT).div(10000);
            TransferHelper.safeTransfer(bee, fixedWallet, fixedShares);

            // start next round auction
            currentRound = currentRound.add(1);

            // min(block.timestamp,  item1.auctionEndTime)
            uint256 prevEndTime = item1.auctionEndTime;
            if (block.timestamp < prevEndTime) {
                prevEndTime = block.timestamp;
            }

            // set next round info
            AuctionRoundItem storage item2 = auctionInfo[tokenId][currentRound];
            item2.auctionStartTime = prevEndTime.add(DURATION_BETWEEN_ROUNDS); // 12 hours later
            item2.auctionEndTime = item2.auctionStartTime.add(AUCTION_DURATION); // 3 days later
            item2.extraAuctionAmount = item1.auctionCurrentPrice.mul(DELTA_PRICE_PERCENT).div(10000); // 20% * base
            item2.auctionCurrentPrice = item1.auctionCurrentPrice.add(item2.extraAuctionAmount); // 120% * base

            // update pre-pre round claim time
            if (currentRound >= 3) {
                uint256 preRoundx = currentRound.sub(1);
                uint256 prePreRoundx = currentRound.sub(2);
                auctionInfo[tokenId][prePreRoundx].rewardClaimStartTime = auctionInfo[tokenId][preRoundx].auctionEndTime.add(DURATION_BEFORE_WITHDRAW);
            }
        } else { // auction end
            uint256 preRound = currentRound.sub(1);
            AuctionRoundItem storage prevItem = auctionInfo[tokenId][preRound];

            // update pre-round
            prevItem.rewardClaimStartTime = item1.auctionEndTime;
            prevItem.status = AuctionStatus.FAILED;

            // update current round
            item1.rewardClaimStartTime = item1.auctionEndTime;
            item1.status = AuctionStatus.FAILED;

            // update round info
            roundInfo[tokenId] = currentRound;
        }
    }

    function submitInviter(address owner, address inviter) public {
        require(owner == msg.sender, "not owner");
        // register user
        UserGlobal storage userGlobal = userMapping[owner];
        if (userGlobal.id == 0) {
            registerUser(owner, inviter);
        }
    }

    function registerUser(address owner, address inviter) internal {
        require(owner != inviter, "can't invite yourself");
        require(inviter != address(0), "zero address");

        address referer = getInviter(inviter);
        for (uint256 i = 0; i < 18; i++) {
            address tmp = referer;
            if (tmp == address(0)) {
                break;
            }
            require(tmp != owner, "inviter loop");
            referer = getInviter(tmp);
        }

        UserGlobal storage userGlobal = userMapping[owner];
        userGlobal.id = uid;
        userGlobal.owner = owner;
        userGlobal.inviter = inviter;
        uid = uid.add(1);
        indexMapping[uid] = owner;

        UserGlobal storage userInviter = userMapping[inviter];
        userInviter.inviteList.push(owner);
    }

    function bid(uint256 tokenId, uint256 amount, address inviter) public {
        address sender = msg.sender;
        AuctionRoundItem storage item = auctionInfo[tokenId][currentRound];
        require(block.timestamp >= item.auctionStartTime, "auction not start");
        require(block.timestamp <= item.auctionEndTime, "auction end");
        require(item.auctionCurrentAmount.add(amount) <= item.auctionCurrentPrice.add(BID_AMOUNT_DELTA), "bid amount too high");

        // register user
        UserGlobal storage userGlobal = userMapping[sender];
        if (userGlobal.id == 0) {
            registerUser(sender, inviter);
        }

        // transfer BT
        TransferHelper.safeTransferFrom(bee, sender, address(this), amount);

        User storage usr = userInfo[tokenId][currentRound][sender];
        usr.beeBalance = usr.beeBalance.add(amount);
        usr.shares = usr.beeBalance;

        // update inviter power
        address inviterAddr = getInviter(sender);
        for (uint256 i = 0; i < 20; i++) {
            address tmpAddr = inviterAddr;
            if (tmpAddr == address(0)) {
                break;
            }

            // update inviter invitePowers
            User storage usrInviter = userInfo[tokenId][currentRound][tmpAddr];
            usrInviter.invitePowers[i] = usrInviter.invitePowers[i].add(amount);

            inviterAddr = getInviter(tmpAddr);
        }

        item.auctionCurrentAmount = item.auctionCurrentAmount.add(amount);
        if (item.auctionCurrentAmount >= item.auctionCurrentPrice) {
            // auction success, enter next round
            item.auctionEndTime = block.timestamp;
            // enter next round
            updateExpiredAuction(tokenId);
        }
    }

    function withdrawable(uint256 tokenId, uint256 round, address usr) public view returns (uint256) {
        if (round == 0) {
            return 0;
        }

        AuctionRoundItem storage item = auctionInfo[tokenId][round];
        // check claim start time
        if (block.timestamp < item.rewardClaimStartTime || item.rewardClaimStartTime == 0) {
            return 0;
        }

        return userInfo[tokenId][round][usr].beeBalance;
    }

    function withdrawableAll(uint256 tokenId, address usr) public view returns (uint256) {
        uint256 round = auctionRound(tokenId);
        if (round < currentRound) {
            round = currentRound;
        }

        uint256 total = 0;
        for (uint256 i = 1; i <= round; i++) {
            total = total.add(withdrawable(tokenId, i, usr));
        }
        return total;
    }

    function withdraw(uint256 tokenId, uint256 round) public {
        address sender = msg.sender;
        uint256 amount = withdrawable(tokenId, round, sender);
        if (amount > 0) {
            userInfo[tokenId][round][sender].beeBalance = 0;
            TransferHelper.safeTransfer(bee, sender, amount);
        }
    }

    function withdrawAll(uint256 tokenId) public {
        uint256 round = auctionRound(tokenId);
        if (round < currentRound) {
            round = currentRound;
        }
        for (uint256 i = 1; i <= round; i++) {
            withdraw(tokenId, i);
        }
    }

    function guarPoolReward(uint256 tokenId, address usr, bool lastRound) internal view returns (uint256) {
        uint256 round = auctionRound(tokenId);
        uint256 percent = 60;
        if (!lastRound) { // pre-last round
            round = round.sub(1);
            percent = 40;
        }

        // claimed
        if (userInfo[tokenId][round][usr].guarPoolRewardClaimed) {
            return 0;
        }

        // 0
        uint256 totalShares = auctionInfo[tokenId][round].auctionCurrentAmount;
        if (totalShares == 0) {
            return 0;
        }

        uint256 shares = userInfo[tokenId][round][usr].shares;
        uint256 guarPoolbalance = guarPoolBalances[tokenId];
        return shares.mul(guarPoolbalance).mul(percent).div(100).div(totalShares);
    }

    function guarPoolRewards(uint256 tokenId, address usr) public view returns (uint256) {
        uint256 round = auctionRound(tokenId);
        if (round <= 2) {
            return 0;
        }

        uint256 lastRoundReward = guarPoolReward(tokenId, usr, true);
        uint256 preRoundReward = guarPoolReward(tokenId, usr, false);
        return lastRoundReward.add(preRoundReward);
    }

    function getGuarPoolRewards(uint256 tokenId) public {
        address sender = msg.sender;
        uint256 amount = guarPoolRewards(tokenId, sender);
        if (amount == 0) {
            return;
        }

        uint256 round = auctionRound(tokenId);
        uint256 preRound = round.sub(1);
        userInfo[tokenId][round][sender].guarPoolRewardClaimed = true;
        userInfo[tokenId][preRound][sender].guarPoolRewardClaimed = true;
        TransferHelper.safeTransfer(bee, sender, amount);
    }

    function invitePowers(uint256 tokenId, uint256 round, address owner) public view returns (uint256[20] memory) {
        return userInfo[tokenId][round][owner].invitePowers;
    }

    function calcInviteReward(uint256 tokenId, uint256 round, address owner, uint256 layers) public view returns (uint256 reward) {
        if (layers > 20) {
            layers = 20;
        }

        uint256[20] memory powers = userInfo[tokenId][round][owner].invitePowers;
        // layer 1
        if (layers >= 1) { // 2%
            reward = reward.add(powers[0].mul(2).div(100));
        }

        // layer 2 - 4
        if (layers >= 2) { // 0.4%
            for (uint256 i = 1; i < 4; i++) {
                reward = reward.add(powers[i].mul(4).div(1000));
            }
        }

        // layer 5
        if (layers >= 5) { // 0.3%
            reward = reward.add(powers[4].mul(3).div(1000));
        }

        // layer 6 - 10
        if (layers >= 6) { // 0.3%
            for (uint256 i = 5; i < 10; i++) {
                reward = reward.add(powers[i].mul(3).div(1000));
            }
        }

        // layer 11 - 20
        if (layers >= 11) { // 0.3%
            for (uint256 i = 10; i < 20; i++) {
                reward = reward.add(powers[i].mul(3).div(1000));
            }
        }
    }

    function pendingInviteReward(uint256 tokenId, uint256 round, address owner) public view returns (uint256) {
        if (0 == auctionInfo[tokenId][round].rewardClaimStartTime) {
            return 0;
        }

        if (block.timestamp < auctionInfo[tokenId][round].rewardClaimStartTime) {
            return 0;
        }

        User storage info = userInfo[tokenId][round][owner];
        if (info.inviteRewardClaimed) { // has claimed
            return 0;
        }

        // for auction failed
        if (auctionInfo[tokenId][round].inviteReward == 0) {
            return 0;
        }

        uint256 pending;
        uint256 beeAmount = usrAuctionBeeTotal(tokenId, round, owner);
        if (beeAmount >= layer20BeeAuctionAmount) {
            // 20 layers
            pending = calcInviteReward(tokenId, round, owner, 20);
        } else if (beeAmount >= layer10BeeAuctionAmount) {
            // 10 layers
            pending = calcInviteReward(tokenId, round, owner, 10);
        } else if (beeAmount >= layer5BeeAuctionAmount) {
            // 5 layers
            pending = calcInviteReward(tokenId, round, owner, 5);
        } else if (beeAmount >= layer1BeeAuctionAmount) {
            // 1 layers
            pending = calcInviteReward(tokenId, round, owner, 1);
        }
        return pending;
    }

    function pendingInviteRewardAll(uint256 tokenId, address usr) public view returns (uint256) {
        uint256 round = auctionRound(tokenId);
        if (round < currentRound) {
            round = currentRound;
        }

        uint256 total = 0;
        for (uint256 i = 1; i <= round; i++) {
            total = total.add(pendingInviteReward(tokenId, i, usr));
        }
        return total;
    }

    function getInviteReward(uint256 tokenId, uint256 round) public {
        address sender = msg.sender;
        uint256 amount = pendingInviteReward(tokenId, round, sender);
        if (amount == 0) {
            return;
        }

        userInfo[tokenId][round][sender].inviteRewardClaimed = true;
        userInviteRewards[tokenId][sender] = userInviteRewards[tokenId][sender].add(amount);
        TransferHelper.safeTransfer(bee, sender, amount);
    }

    function getInviteRewardAll(uint256 tokenId) public {
        uint256 round = auctionRound(tokenId);
        if (round < currentRound) {
            round = currentRound;
        }
        for (uint256 i = 1; i <= round; i++) {
            getInviteReward(tokenId, i);
        }
    }

    function pendingAuctionReward(uint256 tokenId, uint256 round, address usr) public view returns (uint256) {
        if (0 == auctionInfo[tokenId][round].rewardClaimStartTime) {
            return 0;
        }

        if (block.timestamp < auctionInfo[tokenId][round].rewardClaimStartTime) {
            return 0;
        }

        User storage info = userInfo[tokenId][round][usr];
        if (info.auctionRewardClaimed) { // reclaimed
            return 0;
        }

        AuctionRoundItem storage item = auctionInfo[tokenId][round];
        if (item.auctionCurrentAmount == 0) {
            return 0;
        }
        uint256 reward = info.shares.mul(item.playersReward).div(item.auctionCurrentAmount);
        return reward;
    }

    function pendingAuctionRewardAll(uint256 tokenId, address usr) public view returns (uint256) {
        uint256 round = auctionRound(tokenId);
        if (round < currentRound) {
            round = currentRound;
        }

        uint256 total = 0;
        for (uint256 i = 1; i <= round; i++) {
            total = total.add(pendingAuctionReward(tokenId, i, usr));
        }
        return total;
    }

    function getAuctionReward(uint256 tokenId, uint256 round) public {
        address sender = msg.sender;
        uint256 amount = pendingAuctionReward(tokenId, round, sender);
        if (amount == 0) {
            return;
        }

        userInfo[tokenId][round][sender].auctionRewardClaimed = true;
        userAuctionRewards[tokenId][sender] = userAuctionRewards[tokenId][sender].add(amount);
        TransferHelper.safeTransfer(bee, sender, amount);
    }

    function getAuctionRewardAll(uint256 tokenId) public {
        uint256 round = auctionRound(tokenId);
        if (round < currentRound) {
            round = currentRound;
        }
        for (uint256 i = 1; i <= round; i++) {
            getAuctionReward(tokenId, i);
        }
    }

    function teamAuctionAmount(uint256 tokenId, uint256 round, address owner) public view returns (uint256 amount) {
        User memory info = userInfo[tokenId][round][owner];
        for (uint256 i = 0; i < 20; i++) {
            amount = amount.add(info.invitePowers[i]);
        }
    }

    function teamAuctionAmountAll(uint256 tokenId, address owner) public view returns (uint256 amount) {
        uint256 round = auctionRound(tokenId);
        if (round < currentRound) {
            round = currentRound;
        }
        for (uint256 i = 1; i <= round; i++) {
            amount = amount.add(teamAuctionAmount(tokenId, i, owner));
        }
    }

    function queryStats(uint256 tokenId, address owner)
        public view returns 
        (uint256 pendingAuctionRewardAllx, uint256 pendingInviteRewardAllx, uint256 withdrawableAllx, uint256 guarPoolRewardsx,
            uint256 pendingMiningRewardsx, uint256 beeBalancesTotalx, uint256 userAuctionRewardsx, uint256 userInviteRewardsx, uint256 teamAuctionAmountAllx) {

        pendingAuctionRewardAllx = pendingAuctionRewardAll(tokenId, owner);
        pendingInviteRewardAllx = pendingInviteRewardAll(tokenId, owner);
        withdrawableAllx = withdrawableAll(tokenId, owner);
        guarPoolRewardsx = guarPoolRewards(tokenId, owner);
        pendingMiningRewardsx = 0;
        beeBalancesTotalx = beeBalancesTotal(tokenId, owner);
        userAuctionRewardsx = userAuctionRewards[tokenId][owner];
        userInviteRewardsx = userInviteRewards[tokenId][owner];
        teamAuctionAmountAllx = teamAuctionAmountAll(tokenId, owner);
    }

    function getInviter(address owner) public view returns (address) {
        return userMapping[owner].inviter;
    }

    function getInviteList(address owner) public view returns (address[] memory) {
        return userMapping[owner].inviteList;
    }

    ///////////////////////////////////////////////////////////
    // admin operations
    function updateAuctionStartTime(uint256 tokenId) public onlyWhitelistAdmin {
        AuctionRoundItem storage item = auctionInfo[tokenId][currentRound];
        item.auctionStartTime = block.timestamp;
        item.auctionEndTime = block.timestamp.add(AUCTION_DURATION);
    }

    function updateAuctionEndTime(uint256 tokenId) public onlyWhitelistAdmin {
        AuctionRoundItem storage item = auctionInfo[tokenId][currentRound];
        item.auctionEndTime = block.timestamp;
        item.rewardClaimStartTime = block.timestamp;
    }

    function stopAuction(uint256 tokenId) public onlyWhitelistAdmin {
        AuctionRoundItem storage item = auctionInfo[tokenId][currentRound];
        roundInfo[tokenId] = currentRound;
        auctionTokenId = 0;
        currentRound = 1;
        item.status = AuctionStatus.DEAL;
        item.rewardClaimStartTime = item.auctionEndTime;
    }

    function updateAuctionClaimTime(uint256 tokenId) public onlyWhitelistAdmin {
        AuctionRoundItem storage item = auctionInfo[tokenId][currentRound];
        item.rewardClaimStartTime = block.timestamp;
    }

    function setFixedWallet(address account) public onlyWhitelistAdmin {
        fixedWallet = account;
    }

    function setBurnPool(address account) public onlyWhitelistAdmin {
        burnPool = account;
    }

    function setBEE(address _bee) public onlyWhitelistAdmin {
        bee = _bee;
    }

    function setLayer20BeeAuctionAmount(uint256 value) public onlyWhitelistAdmin {
        layer20BeeAuctionAmount = value;
    }

    function setLayer10BeeAuctionAmount(uint256 value) public onlyWhitelistAdmin {
        layer10BeeAuctionAmount = value;
    }

    function setLayer5BeeAuctionAmount(uint256 value) public onlyWhitelistAdmin {
        layer5BeeAuctionAmount = value;
    }

    function setLayer1BeeAuctionAmount(uint256 value) public onlyWhitelistAdmin {
        layer1BeeAuctionAmount = value;
    }

    function setBidAmountDelta(uint256 value) public onlyWhitelistAdmin {
        BID_AMOUNT_DELTA = value;
    }

    function setDeltaPricePercent(uint256 value) public onlyWhitelistAdmin {
        DELTA_PRICE_PERCENT = value;
    }

    function setPlayerPercent(uint256 value) public onlyWhitelistAdmin {
        PLAYER_PERCENT = value;
    }

    function setInvitePercent(uint256 value) public onlyWhitelistAdmin {
        INVITE_PERCENT = value;
    }

    function setGuarPoolPercent(uint256 value) public onlyWhitelistAdmin {
        GUAR_POOL_PERCENT = value;
    }

    function setBurnPoolPercent(uint256 value) public onlyWhitelistAdmin {
        BURN_POOL_PERCENT = value;
    }

    function setFixedWalletPercent(uint256 value) public onlyWhitelistAdmin {
        FIXED_WALLET_PERCENT = value;
    }

    function setDurationBetweenRounds(uint256 value) public onlyWhitelistAdmin {
        // 1440
        DURATION_BETWEEN_ROUNDS = value;
    }

    function setDurationBeforeWithdraw(uint256 value) public onlyWhitelistAdmin {
        // 2880
        DURATION_BEFORE_WITHDRAW = value;
    }

    function setAuctionDuration(uint256 value) public onlyWhitelistAdmin {
        // 3660
        AUCTION_DURATION = value;
    }

    function withdrawTRX(uint256 amount) public onlyOwner returns (bool) {
        msg.sender.transfer(amount);
        return true;
    }

    function withdrawBEE(uint256 amount) public onlyOwner returns (bool) {
        TransferHelper.safeTransfer(bee, owner(), amount);
        return true;
    }

    function burnBEE(uint256 amount) public onlyWhitelistAdmin returns (bool) {
        TransferHelper.safeTransfer(bee, burnPool, amount);
        return true;
    }
    ///////////////////////////////////////////////////////////
}


//SourceUnit: Context.sol

pragma solidity ^0.5.8;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
contract Context {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    constructor () internal { }
    // solhint-disable-previous-line no-empty-blocks

    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

//SourceUnit: Counters.sol

pragma solidity ^0.5.8;

import "./SafeMath.sol";

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented or decremented by one. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 * Since it is not possible to overflow a 256 bit integer with increments of one, `increment` can skip the {SafeMath}
 * overflow check, thereby saving gas. This does assume however correct usage, in that the underlying `_value` is never
 * directly accessed.
 */
library Counters {
    using SafeMath for uint256;

    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        // The {SafeMath} overflow check can be skipped here, see the comment at the top
        counter._value += 1;
    }

    function decrement(Counter storage counter) internal {
        counter._value = counter._value.sub(1);
    }
}

//SourceUnit: IERC20.sol

pragma solidity ^0.5.8;

/**
 * @title TRC20 interface
 */
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function totalSupply() external view returns (uint256);
    function balanceOf(address who) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

//SourceUnit: Ownable.sol

pragma solidity ^0.5.8;

import "./Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}


//SourceUnit: Roles.sol

pragma solidity ^0.5.8;

/**
 * @title Roles
 * @dev Library for managing addresses assigned to a Role.
 */
library Roles {
    struct Role {
        mapping (address => bool) bearer;
    }

    /**
     * @dev Give an account access to this role.
     */
    function add(Role storage role, address account) internal {
        require(!has(role, account), "Roles: account already has role");
        role.bearer[account] = true;
    }

    /**
     * @dev Remove an account's access to this role.
     */
    function remove(Role storage role, address account) internal {
        require(has(role, account), "Roles: account does not have role");
        role.bearer[account] = false;
    }

    /**
     * @dev Check if an account has this role.
     * @return bool
     */
    function has(Role storage role, address account) internal view returns (bool) {
        require(account != address(0), "Roles: account is the zero address");
        return role.bearer[account];
    }
}


//SourceUnit: SafeMath.sol

pragma solidity ^0.5.8;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     *
     * _Available since v2.4.0._
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}


//SourceUnit: StringLibrary.sol

pragma solidity ^0.5.8;

import "./UintLibrary.sol";

library StringLibrary {
    using UintLibrary for uint256;

    function append(string memory _a, string memory _b) internal pure returns (string memory) {
        bytes memory _ba = bytes(_a);
        bytes memory _bb = bytes(_b);
        bytes memory bab = new bytes(_ba.length + _bb.length);
        uint k = 0;
        for (uint i = 0; i < _ba.length; i++) bab[k++] = _ba[i];
        for (uint i = 0; i < _bb.length; i++) bab[k++] = _bb[i];
        return string(bab);
    }

    function append(string memory _a, string memory _b, string memory _c) internal pure returns (string memory) {
        bytes memory _ba = bytes(_a);
        bytes memory _bb = bytes(_b);
        bytes memory _bc = bytes(_c);
        bytes memory bbb = new bytes(_ba.length + _bb.length + _bc.length);
        uint k = 0;
        for (uint i = 0; i < _ba.length; i++) bbb[k++] = _ba[i];
        for (uint i = 0; i < _bb.length; i++) bbb[k++] = _bb[i];
        for (uint i = 0; i < _bc.length; i++) bbb[k++] = _bc[i];
        return string(bbb);
    }

    function recover(string memory message, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        bytes memory msgBytes = bytes(message);
        bytes memory fullMessage = concat(
            bytes("\x19Ethereum Signed Message:\n"),
            bytes(msgBytes.length.toString()),
            msgBytes,
            new bytes(0), new bytes(0), new bytes(0), new bytes(0)
        );
        return ecrecover(keccak256(fullMessage), v, r, s);
    }

    function concat(bytes memory _ba, bytes memory _bb, bytes memory _bc, bytes memory _bd, bytes memory _be, bytes memory _bf, bytes memory _bg) internal pure returns (bytes memory) {
        bytes memory resultBytes = new bytes(_ba.length + _bb.length + _bc.length + _bd.length + _be.length + _bf.length + _bg.length);
        uint k = 0;
        for (uint i = 0; i < _ba.length; i++) resultBytes[k++] = _ba[i];
        for (uint i = 0; i < _bb.length; i++) resultBytes[k++] = _bb[i];
        for (uint i = 0; i < _bc.length; i++) resultBytes[k++] = _bc[i];
        for (uint i = 0; i < _bd.length; i++) resultBytes[k++] = _bd[i];
        for (uint i = 0; i < _be.length; i++) resultBytes[k++] = _be[i];
        for (uint i = 0; i < _bf.length; i++) resultBytes[k++] = _bf[i];
        for (uint i = 0; i < _bg.length; i++) resultBytes[k++] = _bg[i];
        return resultBytes;
    }
}


//SourceUnit: TransferHelper.sol

pragma solidity ^0.5.8;

// helper methods for interacting with TRC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, ) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success, 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, ) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success, 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferTRX(address to, uint value) internal {
        (bool success,) = to.call.value(value)(new bytes(0));
        require(success, 'TransferHelper: TRX_TRANSFER_FAILED');
    }
}

//SourceUnit: UintLibrary.sol

pragma solidity ^0.5.8;

library UintLibrary {
    function toString(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len - 1;
        while (_i != 0) {
            bstr[k--] = byte(uint8(48 + _i % 10));
            _i /= 10;
        }
        return string(bstr);
    }
}


//SourceUnit: WhitelistAdminRole.sol

pragma solidity ^0.5.8;

import "./Context.sol";
import "./Roles.sol";

/**
 * @title WhitelistAdminRole
 * @dev WhitelistAdmins are responsible for assigning and removing Whitelisted accounts.
 */
contract WhitelistAdminRole is Context {
    using Roles for Roles.Role;

    event WhitelistAdminAdded(address indexed account);
    event WhitelistAdminRemoved(address indexed account);

    Roles.Role private _whitelistAdmins;

    constructor () internal {
        _addWhitelistAdmin(_msgSender());
    }

    modifier onlyWhitelistAdmin() {
        require(isWhitelistAdmin(_msgSender()), "WhitelistAdminRole: caller does not have the WhitelistAdmin role");
        _;
    }

    function isWhitelistAdmin(address account) public view returns (bool) {
        return _whitelistAdmins.has(account);
    }

    function addWhitelistAdmin(address account) public onlyWhitelistAdmin {
        _addWhitelistAdmin(account);
    }

    function renounceWhitelistAdmin() public {
        _removeWhitelistAdmin(_msgSender());
    }

    function _addWhitelistAdmin(address account) internal {
        _whitelistAdmins.add(account);
        emit WhitelistAdminAdded(account);
    }

    function _removeWhitelistAdmin(address account) internal {
        _whitelistAdmins.remove(account);
        emit WhitelistAdminRemoved(account);
    }
}