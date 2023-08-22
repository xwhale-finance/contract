// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;
import "./Ownable.sol";
import "./IERC20.sol";

contract IDO is Ownable {
    uint256 public xwhalePerEther = 200000;
    address public xwhale;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public softcap = 0.5 ether;
    uint256 public hardcap = 2 ether;
    uint256 public max = 10 ether;
    uint256 public _duration;
    bool public softcapmet = true;
    bytes32 public root;
    uint256 public totalBuy;
    uint256 public totalWithdraw;
    uint256 public totalWithdrawAutostake;
    address public TreasuryReceiver;
    mapping (address => uint256) public payAmount;
    mapping (address => uint256) private _xwhaleReleased;

    event XwhaleReleased(address user, uint256 amount);
    constructor(address _xwhale, uint256 _start, uint256 _end, uint256 durationSeconds, address _treasury) {
        xwhale = _xwhale;
        startTime = _start;
        endTime = _end;
        _duration = durationSeconds;
        TreasuryReceiver = _treasury;
    }

    function setPrice(uint256 _price) external onlyOwner {
        require(block.timestamp < startTime, "IDO has started, the price cannot be changed");
        xwhalePerEther = _price;
    }

    function setTime(uint256 _start, uint256 _end) external onlyOwner {
        if(startTime > 0) {
            require(block.timestamp < startTime);
        }
        startTime = _start;
        endTime = _end;
    }

  function join() external payable {
        require(block.timestamp >= startTime && block.timestamp < endTime, "The public sale hasn't started yet");
        require(msg.value >= 1e17 && (payAmount[msg.sender] + msg.value) <= max, "Exceeded the allowed amount");
        require(address(this).balance <= hardcap, "IDO quota has been reached");
        payAmount[msg.sender] += msg.value;
        totalBuy += msg.value;
        if(address(this).balance >= softcap) {
            softcapmet = true;
        }
    }

    function leave(uint256 amount) external {
        require(!softcapmet, "Refunds are not possible as the soft cap has been exceeded");
        require(payAmount[msg.sender] >= amount, "The exit amount is greater than the invested amount");
        payAmount[msg.sender] -= amount;
        totalBuy -= amount;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed.");
    }

    function released(address _user) public view returns(uint256){
        //withdraw
        return _xwhaleReleased[_user];
    }

    function releasable(address _user) public view returns(uint256){
        //available
        return _vestingSchedule( getTotalAllocation(_user) , block.timestamp) - released(_user);
    }

    function release() external {
        require(softcapmet, "VIB cannot be claimed as the soft cap for IDO has not been reached");
        uint256 amount = releasable(msg.sender);
        _xwhaleReleased[msg.sender] += amount;
        totalWithdraw += amount;
        emit XwhaleReleased(msg.sender, amount);
        IERC20(xwhale).transfer(msg.sender, amount);
    }

    function startVesting() public view returns(uint256){
        return endTime;
    }

    function duration() public view returns(uint256){
        return _duration;
    }

    function getTotalAllocation(address _user) public view returns (uint256){
        return payAmount[_user] * xwhalePerEther;
    }

    function _vestingSchedule(uint256 totalAllocation, uint256 timestamp) internal view returns (uint256) {
        if (timestamp < startVesting()) {
            return 0;
        } else if (timestamp > startVesting() + duration()) {
            return totalAllocation;
        } else {
            return totalAllocation * (timestamp - startVesting()) / duration();
        }
    }


    function withdrawEther() external onlyOwner {
        require(block.timestamp >= endTime, "The owner can only withdraw ETH after the IDO ends");
        require(softcapmet, "The owner cannot withdraw ETH as the soft cap for IDO has not been reached");
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    // to help users who accidentally send their tokens to this contract
    function sendToken(address token, address to, uint256 amount) external onlyOwner {
        require(block.timestamp >= endTime);
        IERC20(token).transfer(to, amount);
    }

    function claimAutostaking() external {
        uint256 amount = IERC20(xwhale).balanceOf(address(this)) + totalWithdraw - totalBuy * xwhalePerEther ;
        IERC20(xwhale).transfer(TreasuryReceiver, amount);
        totalWithdrawAutostake += amount;
    }
}