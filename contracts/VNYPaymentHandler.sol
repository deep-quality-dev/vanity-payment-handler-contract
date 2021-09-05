// SPDX-License-Identifier: MIT

// $VNY Marketplace Payments Handler.
// Audited by Solidity.Finance: https://solidity.finance/audits/VanityShopPayments/

// __      __         _ _
// \ \    / /        (_) |
//  \ \  / /_ _ _ __  _| |_ _   _
//   \ \/ / _` | '_ \| | __| | | |
//    \  / (_| | | | | | |_| |_| |
//     \/ \__,_|_| |_|_|\__|\__, |
//                           __/ |
//                          |___/

// #Features:
// When a user makes a purchase using the platform, the tokens are stored in the contract address and are allocated as follows:
//
// 30% of the $VNY Tokens paid are sent to the Burn Address, to reduce circulating supply.
// 15% are sent to the $VNY contract address, which manages LP Deposit.
// 10% are swapped for BNB and sent to the Dev's Wallet.
// 45% are swapped for BNB and sent to the contract address to support the buyback functionality.

// Meet Hydra.

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IPancakeSwapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
      uint amountOutMin,
      address[] calldata path,
      address to,
      uint deadline
    ) external payable;
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
}

contract VNYPaymentHandler is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;
    
    IPancakeSwapV2Router02 private pancakeV2Router; // pancakeswap v2 router
    address private pancakeV2Pair; // pancakeswap v2 pair

    ERC20 public feeToken;
    uint256 public burnPercent;
    uint256 public divider;

    address public contractWallet;
    uint256 public contractPercent;

    address public teamWallet;
    uint256 public teamPercent;

    address public immutable deadAddress = 0x000000000000000000000000000000000000dEaD;

    address public operatorAddress;

    modifier onlyOperator() {
        require(operatorAddress == _msgSender(), "Only for operator");
        _;
    }

    constructor( ) {
        feeToken = ERC20(0xa300372112EF4e7499bDb7699B9627F354FB78C9);
        burnPercent = 30;
        divider = 100;

        contractPercent = 15;
        contractWallet = 0xa300372112EF4e7499bDb7699B9627F354FB78C9;

        teamPercent = 10;
        teamWallet = 0xDEAD1337F2Ede31413CB39B0cf97909b6F107DB6;

        pancakeV2Router = IPancakeSwapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3); // pancakeswap v2 router
    }

    function setOperatorAddress(address _operatorAddress) external {
        operatorAddress = _operatorAddress;
    }

    function pay(uint256 feeAmount) external {
        require(feeAmount > 0, "fee must be greater than zero");

        uint256 initVanityAmount = feeToken.balanceOf(address(this));

        feeToken.safeTransferFrom(
            msg.sender,
            address(this),
            feeAmount
        );

        feeAmount = feeToken.balanceOf(address(this)).sub(initVanityAmount);

        uint256 burnAmount = feeAmount.mul(burnPercent).div(divider);
        uint256 contractAmount = feeAmount.mul(contractPercent).div(divider);
        uint256 buybackPercent = divider.sub(burnPercent).sub(contractPercent).sub(teamPercent);
        uint256 teamBuybackAmount = feeAmount.sub(burnAmount).sub(contractAmount);

        uint256 initialBalance = address(this).balance;
        swapTokensForEth(teamBuybackAmount);
        uint256 transferredBalance = address(this).balance.sub(initialBalance);

        feeToken.safeTransfer(deadAddress, burnAmount); // burn
        feeToken.safeTransfer(contractWallet, contractAmount);
        transferToAddressETH(payable(teamWallet), transferredBalance.mul(teamPercent).div(teamPercent.add(buybackPercent)));
    }

    function swapAllTokensForEth() external onlyOperator {
        uint256 amount = feeToken.balanceOf(address(this));
        if (amount > 0) {
            swapTokensForEth(amount);
        }
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(feeToken);
        path[1] = pancakeV2Router.WETH();
        feeToken.approve(address(pancakeV2Router), tokenAmount);
        pancakeV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(tokenAmount, 0, path, address(this), block.timestamp);
    }

    function swapETHForTokens(uint256 amount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = pancakeV2Router.WETH();
        path[1] = address(feeToken);

        // make the swap
        pancakeV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0, // accept any amount of Tokens
            path,
            deadAddress, // Burn address
            block.timestamp.add(300)
        );
    }

    function buyback(uint256 bAmount) external onlyOwner {
        uint256 contractBalance = address(this).balance;

        if (contractBalance > bAmount) {
    	    swapETHForTokens(bAmount);
	    }
    }

    function transferToAddressETH(address payable recipient, uint256 amount) private {
        recipient.transfer(amount);
    }

    function setTeamWallet(address _teamWallet) external onlyOwner {
        teamWallet = _teamWallet;
    }

    function setTeamPercent(uint256 _teamPercent) external onlyOwner {
        teamPercent = _teamPercent;
    }

    function setContractWallet(address _contractWallet) external onlyOwner {
        contractWallet = _contractWallet;
    }

    function setContractPercent(uint256 _contractPercent) external onlyOwner {
        contractPercent = _contractPercent;
    }

    function setBurnPercent(uint256 _burnPercent) external onlyOwner {
        burnPercent = _burnPercent;
    }

    function setDivider(uint256 _divider) external onlyOwner {
        divider = _divider;
    }

    receive() external payable {}
}