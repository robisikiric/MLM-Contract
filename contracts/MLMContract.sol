// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MLMContract {
    using SafeMath for uint256;

    struct Participant {
        address upline;
        uint256 balance; // Earnings available for withdrawal
        uint256 totalEarned; // Total earnings including withdrawn amounts
        uint level; // Participant level
    }

    mapping(address => Participant) public participants;
    mapping(address => bool) public registered;

    address public owner;
    uint256 public registrationFee = 0.1 ether;
    uint256 public commissionPercentage = 10;
    uint256 public constant MAX_LEVELS = 5; // Max tiers for member to earn commissions from

    event ParticipantRegistered(address indexed participant, address indexed upline);
    event CommissionPaid(address indexed recipient, uint256 amount);
    event Withdrawal(address indexed participant, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyRegistered() {
        require(registered[msg.sender], "Not a registered participant");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function register(address _upline) external payable {
        require(msg.value == registrationFee, "Incorrect registration fee");
        require(!registered[msg.sender], "Already registered");
        require(registered[_upline] || _upline == owner, "Invalid upline");

        _addParticipant(msg.sender, _upline);

        if (_upline != owner) {
            _distributeCommission(msg.value, _upline);
        }

        emit ParticipantRegistered(msg.sender, _upline);
    }

    function _addParticipant(address _participant, address _upline) internal {
        participants[_participant] = Participant({
            upline: _upline,
            balance: 0,
            totalEarned: 0,
            level: participants[_upline].level + 1
        });
        registered[_participant] = true;
    }

    function _distributeCommission(uint256 _amount, address _upline) internal {
        address currentUpline = _upline;
        uint256 remainingAmount = _amount;

        for (uint256 i = 0; i < MAX_LEVELS && currentUpline != owner; i++) {
            uint256 commission = _amount.mul(commissionPercentage).div(100);

            participants[currentUpline].balance = participants[currentUpline].balance.add(commission);
            participants[currentUpline].totalEarned = participants[currentUpline].totalEarned.add(commission);

            remainingAmount = remainingAmount.sub(commission);
            currentUpline = participants[currentUpline].upline;
        }

        // Return any undistributed funds to the owner
        if (remainingAmount > 0) {
            payable(owner).transfer(remainingAmount);
        }
    }

    function withdraw() external onlyRegistered {
        uint256 balance = participants[msg.sender].balance;
        require(balance > 0, "No funds available for withdrawal");

        participants[msg.sender].balance = 0;
        payable(msg.sender).transfer(balance);

        emit Withdrawal(msg.sender, balance);
    }

    function getParticipantInfo(address _participant) external view returns (address, uint256, uint256, uint) {
        Participant storage participant = participants[_participant];
        return (participant.upline, participant.balance, participant.totalEarned, participant.level);
    }

    function changeRegistrationFee(uint256 _newFee) external onlyOwner {
        registrationFee = _newFee;
    }

    function withdrawContractBalance() external onlyOwner {
        uint256 contractBalance = address(this).balance;
        payable(owner).transfer(contractBalance);
    }
}