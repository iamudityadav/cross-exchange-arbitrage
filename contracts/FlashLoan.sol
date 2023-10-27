// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./libraries/SafeERC20.sol";

contract FlashLoan {
    using SafeERC20 for IERC20;

    // UniswapV2 factory and router addresses
    address private constant UNISWAP_V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address private constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    // SushiswapV2 factory and router addresses
    address private constant SUSHISWAP_V2_FACTORY = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
    address private constant SUSHISWAP_V2_ROUTER = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;

    //token addresses
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant LINK = 0x514910771AF9Ca656af840dff83E8264EcF986CA;

    uint256 private deadline = block.timestamp + 1 days;
    uint256 private constant MAX_INT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    function checkResult(uint256 _repayAmount, uint256 _finalTrade) private pure returns(bool) {
        return _finalTrade > _repayAmount;
    }

    function getBalanceOfToken(address _token) public view returns(uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    function placeTrade(address _from, address _to, uint256 _amount, address _factory, address _router) private returns(uint256) {
        address liquidity_pool = IUniswapV2Factory(_factory).getPair(_from, _to);
        require(liquidity_pool != address(0), "Liquidity pool does not exist.");
        
        address[] memory path = new address[](2);
        path[0] = _from;
        path[1] = _to;

        uint256 amountRequired = IUniswapV2Router(_router).getAmountsOut(_amount, path)[1];
        uint256 amountReceived = IUniswapV2Router(_router)
                                    .swapExactTokensForTokens(
                                        _amount,
                                        amountRequired,
                                        path,
                                        address(this),
                                        deadline
                                    )[1];

        require(amountReceived > 0, "Transaction aborted.");

        return amountReceived;    
    }

    function initiateArbitrage(address _tokenBorrow, uint256 _amount) external {
        IERC20(_tokenBorrow).safeApprove(UNISWAP_V2_ROUTER, MAX_INT);
        IERC20(LINK).safeApprove(SUSHISWAP_V2_ROUTER, MAX_INT);


        address liquidity_pool = IUniswapV2Factory(UNISWAP_V2_FACTORY).getPair(_tokenBorrow, WETH);
        require(liquidity_pool != address(0), "Liquidity pool does not exist.");

        address token0 = IUniswapV2Pair(liquidity_pool).token0();
        address token1 = IUniswapV2Pair(liquidity_pool).token1();        

        uint256 amount0Out = _tokenBorrow==token0?_amount:0;
        uint256 amount1Out = _tokenBorrow==token1?_amount:0;

        bytes memory data = abi.encode(_tokenBorrow, _amount, msg.sender);
        IUniswapV2Pair(liquidity_pool).swap(amount0Out, amount1Out, address(this), data);
    }

    function uniswapV2Call(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external {
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();

        address liquidity_pool = IUniswapV2Factory(UNISWAP_V2_FACTORY).getPair(token0, token1);

        require(msg.sender == liquidity_pool, "Liquidity pool does not match.");
        require(_sender == address(this), "_sender  does not match.");

        (address tokenBorrow, uint256 amount, address myAccount) = abi.decode(_data, (address, uint256, address));

        uint256 fee = ((amount * 3) / 997) + 1;
        uint256 repayAmount = amount + fee;
        uint256 loanAmount = _amount0 > 0 ? _amount0 : _amount1;

        // cross exchange arbitrage
        uint256 trade1 = placeTrade(tokenBorrow, LINK, loanAmount, UNISWAP_V2_FACTORY, UNISWAP_V2_ROUTER);
        uint256 trade2 = placeTrade(LINK, tokenBorrow, trade1, SUSHISWAP_V2_FACTORY, SUSHISWAP_V2_ROUTER);

        bool isProfitable = checkResult(repayAmount, trade2);
        require(isProfitable, "Arbitrage is not profitable.");

        uint256 profit = trade2 - repayAmount;
        IERC20(tokenBorrow).safeTransfer(myAccount, profit);
        IERC20(tokenBorrow).safeTransfer(liquidity_pool, repayAmount);
    }
}