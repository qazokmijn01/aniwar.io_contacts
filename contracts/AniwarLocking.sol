// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./AniwarToken.sol";

// Aniwar locking
contract AniwarLocking is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 private constant MAX_RATE = 1e18;

    // Info of each term.
    struct TermInfo {
        uint256 allocPoint; // how many allocation points assigned to this term
        uint256 lockingTerm; // seconds
    }

    // Info of each user locking
    struct UserLocking {
        uint256 currentTerm; // pid of current locking term
        uint256 principal; // principal locking amount
        uint256 releaseTime; // time when user can unlock
    }

    // Info for each user vesting
    struct UserVesting {
        uint256 payout; // total AniwarToken reward
        uint256 vesting; // vesting period (in seconds)
        uint256 lastTime; // last claim reward time
    }

    AniwarToken public aniwarToken;
    // how many AniwarToken reward per second per AniwarToken locked
    uint256 public aniwarTokenPerShare;
    uint256 public totalAllocPoint;

    // AniwarToken balance for payout
    // update only by admin functions
    uint256 public totalReward;

    // Total AniwarToken pending payout for all users
    // Debts increases when users lock AniwarToken
    // Debts decrease when users claim AniwarToken
    uint256 public totalDebts;

    TermInfo[] public terms;
    mapping(address => UserLocking) public lockings;
    mapping(address => UserVesting) public vestings;

    event Locking(
        address indexed locker,
        uint256 indexed amount,
        uint256 lockingTerm,
        uint256 payout
    );
    event LockingIncreased(address indexed locker, uint256 indexed amount, uint256 indexed lockingTerm);
    event Unclocking(address indexed locker, uint256 indexed amount);
    event RewardClaimed(address indexed locker, uint256 indexed amount);

    constructor(
        AniwarToken _aniwar, 
        uint256 _aniwarTokenPerShare
    ) {  
        aniwarToken = _aniwar; 
        aniwarTokenPerShare = _aniwarTokenPerShare;

        totalAllocPoint = 0;

        add(1000, 7 days);
        add(5000, 30 days);
        add(16000, 90 days);
        add(35000, 180 days);
        add(80000, 365 days);
        add(300000, 1095 days);
    }

    // estimate reward with given term
    function estimateReward(uint256 _term, uint256 _amount) public view returns (uint256) {
        TermInfo memory term = terms[_term];
        return _amount.mul(aniwarTokenPerShare).mul(term.lockingTerm).mul(term.allocPoint).div(totalAllocPoint).div(1e18);
    }

    // estimate governance power with given term
    // governance power = principal * 1000 * term point / total term point
    function estimateGovPower(uint256 _term, uint256 _amount) public view returns (uint256) {
        TermInfo memory term = terms[_term];
        return _amount.mul(1000).mul(term.allocPoint).div(totalAllocPoint);
    }

    function percentRewardFor(address _locker) public view returns (uint256) {
        uint256 secsSinceLast = block.timestamp.sub(vestings[_locker].lastTime);
        uint256 vesting = vestings[_locker].vesting;

        if (vesting > 0) {
            return secsSinceLast.mul(MAX_RATE).div(vesting);
        } else {
            return 0;
        }
    }

    function pendingRewardFor(address _locker) external view returns (uint256) {
        uint256 percentVested = percentRewardFor(_locker);
        uint256 payout = vestings[_locker].payout;

        if (percentVested >= MAX_RATE) {
            return payout;
        } else {
            return payout.mul(percentVested).div(MAX_RATE);
        }
    }

    function startLock(uint256 _term, uint256 _amount) external nonReentrant {
        UserLocking storage user = lockings[msg.sender];
        TermInfo memory term = terms[_term];
        require(user.principal == 0, "already have lock");

        uint256 payout = estimateReward(_term, _amount);
        _updateRewardFor(msg.sender, term.lockingTerm, payout);

        user.currentTerm = _term;
        user.principal = _amount;
        user.releaseTime = block.timestamp.add(term.lockingTerm);

        aniwarToken.transferFrom(msg.sender, address(this), _amount);

        emit Locking(msg.sender, _amount, term.lockingTerm, payout);
    }

    function increaseLockTime(uint256 _term) external nonReentrant {
        UserLocking storage user = lockings[msg.sender];
        require(user.principal != 0, "no lock");

        // require current lock less then 3 years
        uint256 remainTime = user.releaseTime > block.timestamp ? user.releaseTime.sub(block.timestamp) : 0;
        require(remainTime + terms[_term].lockingTerm < 1095 days, "max 3 years lock");

        uint256 payout = estimateReward(_term, user.principal);
        _updateRewardFor(msg.sender, terms[_term].lockingTerm, payout);

        user.releaseTime = user.releaseTime.add(terms[_term].lockingTerm);

        emit LockingIncreased(msg.sender, user.principal, terms[_term].lockingTerm);
    }

    function increaseLockAmount(uint256 _amount) external nonReentrant {
        UserLocking storage user = lockings[msg.sender];
        require(user.principal != 0, "no lock");

        uint256 payout = estimateReward(user.currentTerm, _amount);
        // reduce reward to match to current remaining locking period
        uint256 remainLockSecs = user.releaseTime > block.timestamp ? user.releaseTime.sub(block.timestamp) : 0;
        payout = payout.mul(remainLockSecs).div(terms[user.currentTerm].lockingTerm);

        // Do not update vesting period
        _updateRewardFor(msg.sender, 0, payout);

        user.principal = user.principal.add(_amount);

        aniwarToken.transferFrom(msg.sender, address(this), _amount);

        emit LockingIncreased(msg.sender, lockings[msg.sender].principal, terms[user.currentTerm].lockingTerm);
    }

    function endLock() external nonReentrant {
        UserLocking memory user = lockings[msg.sender];
        require(user.principal > 0, "no lock");
        require(user.releaseTime <= block.timestamp, "still locked");

        if (vestings[msg.sender].payout > 0) {
            _claimRewardFor(msg.sender);
        }
 
        delete lockings[msg.sender];
        delete vestings[msg.sender];

        _safeAniwarTokenTransfer(msg.sender, user.principal);

        emit Unclocking(msg.sender, user.principal);
    }

    function claimReward() external nonReentrant {
        if (vestings[msg.sender].payout > 0) {
            _claimRewardFor(msg.sender);
        }
    }

    function _updateRewardFor(
        address _locker,
        uint256 _term,
        uint256 _payout
    ) internal {
        UserVesting memory info = vestings[_locker];
        if (info.payout > 0) {
            _claimRewardFor(_locker);
        }

        totalDebts = totalDebts.add(_payout);
        totalReward = totalReward.sub(_payout);
        vestings[_locker].payout = vestings[_locker].payout.add(_payout);
        vestings[_locker].vesting = vestings[_locker].vesting.add(_term);
        vestings[_locker].lastTime = block.timestamp;
    }

    function _claimRewardFor(address _locker) internal {
        UserVesting memory info = vestings[_locker];
        uint256 percentVested = percentRewardFor(_locker); // (secs since last interaction / vesting term remaining)

        if (percentVested >= MAX_RATE) {
            totalDebts = totalDebts.sub(vestings[_locker].payout);
            // if fully vested
            delete vestings[_locker];

            emit RewardClaimed(_locker, info.payout); // emit claim data

            _safeAniwarTokenTransfer(_locker, info.payout);
        } else {
            // if unfinished
            // calculate payout vested
            uint256 payout = info.payout.mul(percentVested).div(MAX_RATE);

            // store updated deposit info
            totalDebts = totalDebts.sub(payout);
            vestings[_locker].payout = vestings[_locker].payout.sub(payout);
            vestings[_locker].vesting = vestings[_locker].vesting.sub(block.timestamp.sub(info.lastTime));
            vestings[_locker].lastTime = block.timestamp;

            emit RewardClaimed(_locker, payout);

            _safeAniwarTokenTransfer(_locker, payout);
        }
    }

    // Safe aniwarToken transfer function, just in case if rounding error causes pool to not have enough XOXOs.
    function _safeAniwarTokenTransfer(address _to, uint256 _amount) internal {
        uint256 aniwarTokenBal = aniwarToken.balanceOf(address(this));
        if (_amount > aniwarTokenBal) {
            aniwarToken.transfer(_to, aniwarTokenBal);
        } else {
            aniwarToken.transfer(_to, _amount);
        }
    }

    function setAniwarTokenPerShare(uint256 _aniwarTokenPerShare) external onlyOwner {
        aniwarTokenPerShare = _aniwarTokenPerShare;
    }

    // deposit AniwarToken as reward
    function deposit(uint256 _amount) external onlyOwner {
        totalReward = totalReward.add(_amount);
        aniwarToken.transferFrom(msg.sender, address(this), _amount);
    }

    // withdraw AniwarToken reward
    function withdraw(uint256 _amount) external onlyOwner {
        totalReward = totalReward.sub(_amount);
        aniwarToken.transfer(msg.sender, _amount);
    }

    function add(uint256 _allocPoint, uint256 _lockingTerm) public onlyOwner {
        terms.push(TermInfo({allocPoint: _allocPoint, lockingTerm: _lockingTerm}));
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
    }
}
