// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./utils/SafeMath.sol";
import "./interface/IUniSwapV2.sol";
import "./interface/IERC20Burnable.sol";
// import "./utils/LogExpMath.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BondingCurve is AccessControl, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    bytes32 public immutable ORACLE = keccak256("ORACLE_ROLE");
    bool public lock = false;
    address private constant ROUTER =
        0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008; //testnet - sepolia

    mapping(address => uint) public balance;
    // 267055730.190118203404023538

    uint256 public exact_eth_supply;
    uint256 public eth_supply;
    uint public token_supply;
    uint256 public tokenSold;
    uint256 public totalTokenSupply;
    uint256 public maxSupply;
    uint16 public fee_percent;
    address public owner_pair;
    address public fee_receiver;
    address public oracle;
    address public TOKEN;
    // 63653723
    constructor(
        address _tokenAddress,
        address _ownerAddress,
        address _feeReceiver,
        address _oracle,
        uint16 _fee
    ) {
        eth_supply = 0.5 * 1e18;

        token_supply = 880_240722_166499_498495_486460; // ~= 880 MILLION TOKEN
        maxSupply = 800_000_000e18;
        fee_percent = 10; //1
        fee_receiver = _feeReceiver;
        owner_pair = _ownerAddress;
        oracle = _oracle;
        fee_percent = _fee;
        _grantRole(DEFAULT_ADMIN_ROLE, owner_pair);
        _grantRole(ORACLE, oracle);

        TOKEN = _tokenAddress;
    }

    event Log(string str, uint256 totalCost);
    event LogMint(uint256 amountMinted, uint256 totalCost);
    event LogWithdraw(uint256 amountWithdrawn, uint256 reward);

    modifier reachLimit(uint amount) {
        require(exact_eth_supply + amount <= 5e18, "you reach the limit");
        _;
    }
    modifier checkLock() {
        require(!lock, "buying , selling is not allow");

        _;
    }

    function buy()
        public
        payable
        nonReentrant
        reachLimit(msg.value)
        checkLock
        returns (bool)
    {
        require(msg.value > 0, "NOOOOO");

        if (exact_eth_supply == 5e18) {
            lock = true;
        }
        uint256 tokensToMint = getAmountOut(
            msg.value,
            eth_supply,
            token_supply
        );
        // require(tokensToMint <= maxSupply, "you reached max supply");
        uint fee = (msg.value * fee_percent) / 1000;
        (bool sent, ) = payable(fee_receiver).call{value: fee}("");
        require(sent, "Failed to send Ether");
        tokenSold = tokenSold.add(tokensToMint);
        balance[msg.sender] = balance[msg.sender].add(tokensToMint);
        eth_supply = eth_supply.add(msg.value - fee);
        exact_eth_supply = exact_eth_supply.add(msg.value - fee);
        token_supply = token_supply.sub(tokensToMint);

        IERC20(TOKEN).safeTransfer(msg.sender, tokensToMint);

        emit LogMint(tokensToMint, msg.value);
        return true;
    }

    function sell(
        uint256 sellAmount
    ) public payable nonReentrant checkLock returns (bool) {
        if (sellAmount > IERC20(TOKEN).balanceOf(msg.sender)) {
            revert("Insufficient inventory");
        }
        uint256 ethAmount = getSellAmount(sellAmount);
        uint fee = (ethAmount * fee_percent) / 1000;
        (bool sent_, ) = payable(fee_receiver).call{value: fee}("");
        require(sent_, "Failed to send Ether");
        IERC20(TOKEN).safeTransferFrom(msg.sender, address(this), sellAmount);
        (bool sent, ) = payable(msg.sender).call{value: ethAmount - fee}("");
        require(sent, "Failed to send Ether");
        eth_supply = eth_supply.sub(ethAmount);
        balance[msg.sender] = balance[msg.sender].sub(sellAmount);
        tokenSold = tokenSold.sub(sellAmount);
        token_supply = token_supply.add(sellAmount);
        emit LogWithdraw(sellAmount, ethAmount);
        return true;
    }

    function addLiquidityETH() external nonReentrant onlyRole(ORACLE) {
        if (tokenSold > maxSupply) {
            uint burn_amount = tokenSold - maxSupply;
            IERC20Burnable(TOKEN).burn(burn_amount);
        }
        require(address(this).balance > 0, "ETH must be provided");

        // Approve the router to spend tokens
        IERC20(TOKEN).approve(ROUTER, IERC20(TOKEN).balanceOf(address(this)));

        // Add liquidity using ETH and tokens
        (uint amountToken, uint amountETH, uint liquidity) = IUniSwapV2(ROUTER)
            .addLiquidityETH{value: address(this).balance}(
            TOKEN,
            IERC20(TOKEN).balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp + 200
        );

        emit Log("amountToken", amountToken);
        emit Log("amountETH", amountETH);
        emit Log("liquidity", liquidity);
    }

    function changeFee(uint16 fee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        fee_percent = fee;
    }
    function changeFeeReceiver(
        address _fee_receiver
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        fee_receiver = _fee_receiver;
    }
    function changeFeeOracle(
        address _oracle
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(ORACLE, oracle);
        _grantRole(ORACLE, _oracle);
        oracle = _oracle;
    }
    function changeAdmin(address _admin) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(ORACLE, owner_pair);
        _grantRole(ORACLE, _admin);
        owner_pair = _admin;
    }

    function ethToToken(uint amount) public view returns (uint256) {
        uint256 tokensToMint = getAmountOut(amount, eth_supply, token_supply);
        return tokensToMint;
    }
    function maxReceiveInETH() public view returns (uint256) {
        uint max_receive = 5e18 - eth_supply;

        return max_receive;
    }
    function maxReceiveInToken() public view returns (uint256) {
        uint max_receive = 5e18 - eth_supply;
        uint tokenAmount = ethToToken(max_receive);

        return tokenAmount;
    }

    function tokenToEth(uint sellAmount) public view returns (uint) {
        uint ethAmount = getAmountOut(sellAmount, token_supply, eth_supply);

        return ethAmount;
    }
    function getSellAmount(uint sellAmount) public view returns (uint) {
        uint256 ethAmount = getAmountOut(
            sellAmount,
            token_supply,
            exact_eth_supply
        );
        return ethAmount;
    }
    function eth_balance() public view returns (uint) {
        uint256 ethAmount = address(this).balance;
        return ethAmount;
    }
    function balanceOf(address _add) public view returns (uint) {
        return balance[_add];
    }
    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) public pure returns (uint amountOut) {
        require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }
}

// 146_339_836_584
