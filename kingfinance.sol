// website: https://kingworld.finance/
// telegram: https://t.me/kingannouncements
// twitter: https://twitter.com/kingfinance
// discord: https://kingworld.finance/discord
//  */
// Written by Krakovia | KKTeam with 💓 o/
//auto pair
pragma solidity 0.8.17;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
//interfaces
interface IPancakeV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}
interface IPancakeV2Router02 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}
interface IKingPass {
    function checkIfPassActive(address who) external view returns(bool);
}
contract King is ERC20, Ownable {
    //custom
    IPancakeV2Router02 public pancakeV2Router;
    //bool
    bool public swapAndLiquifyEnabled = true;
    bool public sendToMarketing = true;
    bool public sendToDev = true;
    bool public sendToBuyback = true;
    bool public limitSells = true;
    bool public limitBuys = true;
    bool public feeStatus = true;
    bool public buyFeeStatus = true;
    bool public sellFeeStatus = true;
    bool public vestingActive = true;
    bool public blockMultiBuys = true;
    bool public kingPassActive;
    bool public marketActive;
    bool public KKLaunched;
    bool private isInternalTransaction;
    //address
    address public marketingAddress = 0x2EEcdB4631c3D2F49D56b4CbfEdE4C7B23151337;
    address public devAddress = 0x0af6fef0248d666f0Bfd73e65485186526411337;
    address public buybackAddress = 0x0af6fef0248d666f0Bfd73e65485186526411337;
    address public pancakeV2Pair;
    address public kingPassContract;
    //uint
    uint public buyMarketingFee = 40;
    uint public sellMarketingFee = 60;
    uint public buyDevFee = 50;
    uint public sellDevFee = 70;
    uint public buyBuybackFee = 10;
    uint public sellBuybackFee = 20;
    uint public kingPassFeeDiscount = 600;
    uint public totalBuyFee = buyMarketingFee + buyDevFee + buyBuybackFee;
    uint public totalSellFee = sellMarketingFee + sellDevFee + sellBuybackFee;
    uint public minimumTokensBeforeSwap = 5500 * 10 ** decimals();
    uint public tokensToSwap = 5500 * 10 ** decimals();
    uint public intervalSecondsForSwap = 30;
    uint public minimumWeiForTokenomics = 1 * 10**17; // 0.1 BNB
    uint public maxBuyTxAmount;
    uint public maxSellTxAmount;
    uint private startTimeForSwap;
    uint private marketActiveAt;
    //struct
    struct userData {uint lastBuyTime;}
    //mapping
    mapping (address => bool) public premarketUser;
    mapping (address => bool) public VestedUser;
    mapping (address => bool) public excludedFromFees;
    mapping (address => bool) public automatedMarketMakerPairs;
    mapping (address => uint) public kingPassLockedTokens;
    mapping (address => userData) public userLastTradeData;
    //events
    event DevelopmentFeeCollected(uint amount);
    event MarketingFeeCollected(uint amount);
    event BuybackFeeCollected(uint amount);
    event PancakeRouterUpdated(address indexed newAddress, address indexed newPair);
    event PancakePairUpdated(address indexed newAddress, address indexed newPair);
    event TokenRemovedFromContract(address indexed tokenAddress, uint256 amount);
    event BnbRemovedFromContract(uint256 amount);
    event MarketStatusChanged(bool status, uint256 date);
    event LimitSellChanged(bool status);
    event LimitBuyChanged(bool status);
    event VestingDisabled(uint256 date);
    event FeesSendToWalletStatusChanged(bool marketing, bool buyback, bool dev);
    event MinimumWeiChanged(uint256 amount);
    event MaxSellChanged(uint256 amount);
    event MaxBuyChanged(uint256 amount);
    event FeesChanged(uint256 buyDevFee, uint256 buyMarketingFee, uint256 buyBuybackFee,
                      uint256 sellDevFee, uint256 sellMarketingFee, uint256 sellBuybackFee);
    event FeesAddressesChanged(address indexed marketing, address indexed buyback, address indexed dev);
    event FeesStatusChanged(bool feesActive, bool buy, bool sell);
    event SwapSystemChanged(bool status, uint256 intervalSecondsToWait, uint256 minimumToSwap, uint256 tokensToSwap);
    event PremarketUserChanged(bool status, address indexed user);
    event ExcludeFromFeesChanged(bool status, address indexed user);
    event MessengerChanged(bool status, address indexed user);
    event AutomatedMarketMakerPairsChanged(bool status, address indexed target);
    event VestedUsersChanged(bool status, address[] indexed users);
    event ContractSwap(uint256 date, uint256 amount);
    event BlockMultiBuysChange(bool status);
    event KingPassAddressChanged(address kingpass);
    event KingPassState(bool enabled);
    event KingPassLockedTokens(address indexed user, uint amount);
    event SetKingPassFeeDiscount(uint discountAmount);
    // constructor
    constructor() ERC20("King", "KING") {
        uint total_supply = 100_000_000 * 10 ** decimals();
        IPancakeV2Router02 _pancakeV2Router = IPancakeV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        pancakeV2Router = _pancakeV2Router;
        maxSellTxAmount = total_supply / 100; // 1% supply
        maxBuyTxAmount = total_supply / 100; // 1% supply
        //spawn pair
        pancakeV2Pair = IPancakeV2Factory(_pancakeV2Router.factory())
        .createPair(address(this), _pancakeV2Router.WETH());
        // mappings
        excludedFromFees[address(this)] = true;
        excludedFromFees[owner()] = true;
        excludedFromFees[devAddress] = true;
        excludedFromFees[buybackAddress] = true;
        excludedFromFees[marketingAddress] = true;
        premarketUser[owner()] = true;
        automatedMarketMakerPairs[pancakeV2Pair] = true;
        // mint is used only here
        _mint(owner(), total_supply);
        // burn the old dead supply
        burn(23164530898000000);
        // used only here to avoid some bots
        KKPunishOn();
    }
    // KingPass check
    modifier onlyKingPass {
        require(msg.sender == kingPassContract,"only KingPass contract can do that");
        _;
    }
    // accept bnb for autoswap
    receive() external payable {}
    
    function decimals() public pure override returns(uint8) {
        return 9;
    }

    // burn function
    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }

    // called at deploy and never used anymore
    function KKPunishOn() internal {
        buyMarketingFee = 330;
        sellMarketingFee = 330;
        buyDevFee = 330;
        sellDevFee = 330;
        buyBuybackFee = 330;
        sellBuybackFee = 330;
        totalBuyFee = buyMarketingFee + buyDevFee + buyBuybackFee;
        totalSellFee = sellMarketingFee + sellDevFee + sellBuybackFee;
    }
    // change router if needed
    function updatePancakeV2Router(address newAddress, bool _createPair, address _pair) external onlyOwner {
        pancakeV2Router = IPancakeV2Router02(newAddress);
        if(_createPair) {
            address _pancakeV2Pair = IPancakeV2Factory(pancakeV2Router.factory())
                .createPair(address(this), pancakeV2Router.WETH());
            pancakeV2Pair = _pancakeV2Pair;
            emit PancakePairUpdated(newAddress,pancakeV2Pair);
        } else {
            pancakeV2Pair = _pair;
        }
        emit PancakeRouterUpdated(newAddress,pancakeV2Pair);
    }
    // to take leftover(tokens) from contract
    function transferToken(address _token, address _to, uint _value) external onlyOwner returns(bool _sent){
        if(_value == 0) {
            _value = IERC20(_token).balanceOf(address(this));
        } 
        _sent = IERC20(_token).transfer(_to, _value);
        emit TokenRemovedFromContract(_token, _value);
    }
    // to take leftover(bnb) from contract
    function transferBNB() external onlyOwner {
        uint balance = address(this).balance;
        (bool success,) = owner().call{value: balance}("");
        if(success) {
            emit BnbRemovedFromContract(balance);
        }
    }
    // market status
    function switchMarketActive(bool _state) external onlyOwner {
        marketActive = _state;
        if(_state) {
            marketActiveAt = block.timestamp;
        }
        emit MarketStatusChanged(_state, block.timestamp);
    }
    // limit sells
    function switchLimitSells(bool _state) external onlyOwner {
        limitSells = _state;
        emit LimitSellChanged(_state);
    }
    // limit buys
    function switchLimitBuys(bool _state) external onlyOwner {
        limitBuys = _state;
        emit LimitBuyChanged(_state);
    }
    // vesting status
    function disableVesting() external onlyOwner {
        // there is no coming back after disabling vesting.
        vestingActive = false;
        emit VestingDisabled(block.timestamp);
    }
    //set functions
    // launch fee
    function setLaunchFee() external onlyOwner {
        buyMarketingFee = 40;
        sellMarketingFee = 60;
        buyDevFee = 50;
        sellDevFee = 70;
        buyBuybackFee = 10;
        sellBuybackFee = 20;
        KKLaunched = true;
        totalBuyFee = buyMarketingFee + buyDevFee + buyBuybackFee;
        totalSellFee = sellMarketingFee + sellDevFee + sellBuybackFee;
        emit FeesChanged(buyDevFee,buyMarketingFee,buyBuybackFee,
                         sellDevFee, sellMarketingFee, sellBuybackFee);
    }
    // multi buy
    function setBlockMultiBuys(bool _status) external onlyOwner {
        blockMultiBuys = _status;
        emit BlockMultiBuysChange(_status);
    }
    // redistribution status (enable/disable)
    function setsendFeeStatus(bool marketing, bool dev, bool buyback) external onlyOwner {
        sendToMarketing = marketing;
        sendToBuyback = buyback;
        sendToDev = dev;
        emit FeesSendToWalletStatusChanged(marketing,buyback,dev);
    }
    // min BNB to activate redistribution
    function setminimumWeiForTokenomics(uint _value) external onlyOwner {
        minimumWeiForTokenomics = _value;
        emit MinimumWeiChanged(_value);
    }
    // fee wallets
    function setFeesAddress(address marketing, address dev, address buyback) external onlyOwner {
        marketingAddress = marketing;
        devAddress = dev;
        buybackAddress = buyback;
        emit FeesAddressesChanged(marketing,dev,buyback);
    }
    // maxTx - sell
    function setMaxSellTxAmount(uint _value) external onlyOwner {
        maxSellTxAmount = _value*10**decimals();
        require(maxSellTxAmount >= totalSupply() / 1000,"maxSellTxAmount should be at least 0.1% of total supply.");
        emit MaxSellChanged(_value);
    }
    // maxTx - buy
    function setMaxBuyTxAmount(uint _value) external onlyOwner {
        maxBuyTxAmount = _value*10**decimals();
        require(maxBuyTxAmount >= totalSupply() / 1000,"maxBuyTxAmount should be at least 0.1% of total supply.");
        emit MaxBuyChanged(maxBuyTxAmount);
    }
    // KingPass status
    function setKingPassState(bool state) external onlyOwner {
        kingPassActive = state;
        emit KingPassState(state);
    }
    // KingPass address
    function setKingPassAddress(address _target) external onlyOwner {
        kingPassContract = _target;
        require(kingPassContract.code.length > 0,"KingPass must be a contract.");
        emit KingPassAddressChanged(_target);
    }
    // Lock tokens to activate KingPass
    function setKingPassLockedTokens(address user, uint amount) external onlyKingPass {
        kingPassLockedTokens[user] = amount;
        emit KingPassLockedTokens(user,amount);
    }
    // KingPass fee discount amount
    function setKingPassFeeDiscount(uint discountAmount) external onlyOwner {
        kingPassFeeDiscount = discountAmount;
        require(kingPassFeeDiscount <= 1000,"KingPass fee discount cannot be over 100%");
        emit SetKingPassFeeDiscount(discountAmount);
    }
    // set fee numbers
    function setFee(bool is_buy, uint marketing, uint dev, uint buyback) external onlyOwner {
        if(is_buy) {
            buyDevFee = dev;
            buyMarketingFee = marketing;
            buyBuybackFee = buyback;
            totalBuyFee = buyMarketingFee + buyDevFee + buyBuybackFee;
        } else {
            sellDevFee = dev;
            sellMarketingFee = marketing;
            sellBuybackFee = buyback;
            totalSellFee = sellMarketingFee + sellDevFee + sellBuybackFee;
        }
        require(totalBuyFee + totalSellFee <= 250,"Total fees cannot be over 25%");
        emit FeesChanged(buyDevFee,buyMarketingFee,buyBuybackFee,
             sellDevFee,sellMarketingFee,sellBuybackFee);
    }
    // fee status (enable/disable)
    function setFeeStatus(bool buy, bool sell, bool _state) external onlyOwner {
        feeStatus = _state;
        buyFeeStatus = buy;
        sellFeeStatus = sell;
        emit FeesStatusChanged(_state,buy,sell);
    }
    // swap system settings
    function setSwapAndLiquify(bool _state, uint _intervalSecondsForSwap, uint _minimumTokensBeforeSwap, uint _tokensToSwap) external onlyOwner {
        swapAndLiquifyEnabled = _state;
        intervalSecondsForSwap = _intervalSecondsForSwap;
        minimumTokensBeforeSwap = _minimumTokensBeforeSwap*10**decimals();
        tokensToSwap = _tokensToSwap*10**decimals();
        require(tokensToSwap <= minimumTokensBeforeSwap,"You cannot swap more then the minimum amount");
        require(tokensToSwap <= totalSupply() / 1000,"token to swap limited to 0.1% supply");
        emit SwapSystemChanged(_state,_intervalSecondsForSwap,_minimumTokensBeforeSwap,_tokensToSwap);
    }
    // mappings functions
    // premarket users
    function editPremarketUser(address _target, bool _status) external onlyOwner {
        premarketUser[_target] = _status;
        emit PremarketUserChanged(_status,_target);
    }
    // excluded from fees
    function editExcludedFromFees(address _target, bool _status) external onlyOwner {
        excludedFromFees[_target] = _status;
        emit ExcludeFromFeesChanged(_status,_target);
    }
    // liquidity pools
    function editAutomatedMarketMakerPairs(address _target, bool _status) external onlyOwner {
        automatedMarketMakerPairs[_target] = _status;
        emit AutomatedMarketMakerPairsChanged(_status,_target);
    }
    // account vesting for special events
    function VestingMultipleAccounts(address[] calldata accounts, bool _state) external onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            VestedUser[accounts[i]] = _state;
        }
        emit VestedUsersChanged(_state,accounts);
    }
    // migration function
    function KKMigration(address[] memory _address, uint256[] memory _amount) external onlyOwner {
        for(uint i=0; i< _amount.length; i++){
            address adr = _address[i];
            uint amnt = _amount[i];
            super._transfer(owner(), adr, amnt);
        }
        // events from ERC20
    }
    // swap token > bnb
    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeV2Router.WETH();
        _approve(address(this), address(pancakeV2Router), tokenAmount);
        pancakeV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
        emit ContractSwap(block.timestamp, tokenAmount);
    }
    // swap token > bnb
    function swapTokens(uint256 contractTokenBalance) private {
        isInternalTransaction = true;
        swapTokensForEth(contractTokenBalance);
        isInternalTransaction = false;
    }
    // check if KingPass is active
    function isKingPassActive(address user) private view returns(bool status) {
        // try-catch to avoid breaking the tx on the external call
        try IKingPass(kingPassContract).checkIfPassActive(user) {
            if (IKingPass(kingPassContract).checkIfPassActive(user)) status = true;
        } catch {}
        return status;
    }
    // transfer
    function _transfer(address from, address to, uint256 amount) internal override {
        // trade type, default = transfer
        uint trade_type = 0;
        // normal transaction
        if(!isInternalTransaction) {
            // market status flag
            if(!marketActive) {
                require(premarketUser[from],"cannot trade before the market opening");
            }
            // KingPass check - lock token in-place to use KingPass
            if(kingPassActive && kingPassLockedTokens[from] != 0) {
                require(balanceOf(from) - amount >= kingPassLockedTokens[from],"Cannot trade KingPass tokens");
            }
            // vesting, used to lock vested users, no tranfer, no sell, buy allowed.
            // can be disabled and cannot be enabled again
            if(vestingActive) {
                if(trade_type == 0 || trade_type == 2) {
                    require(!VestedUser[from],"your account is locked.");
                }
            }
            //buy
            if(automatedMarketMakerPairs[from]) {
                trade_type = 1;
                // if not excluded from fees
                if(!excludedFromFees[to]) {
                    // tx limit
                    if(limitBuys) {
                        require(amount <= maxBuyTxAmount, "maxBuyTxAmount Limit Exceeded");
                        // multi-buy limit
                        if(blockMultiBuys) {
                            require(marketActiveAt + 7 < block.timestamp,"You cannot buy at launch.");
                            require(userLastTradeData[tx.origin].lastBuyTime + 3 <= block.timestamp,"You cannot do multi-buy orders.");
                            userLastTradeData[tx.origin].lastBuyTime = block.timestamp;
                        }
                    }
                }
            }
            //sell
            else if(automatedMarketMakerPairs[to]) {
                trade_type = 2;
                bool overMinimumTokenBalance = balanceOf(address(this)) >= minimumTokensBeforeSwap;
                // marketing auto-bnb
                if (swapAndLiquifyEnabled && balanceOf(pancakeV2Pair) > 0) {
                    // if contract has X tokens, not sold since Y time, sell Z tokens
                    if (overMinimumTokenBalance && startTimeForSwap + intervalSecondsForSwap <= block.timestamp) {
                        startTimeForSwap = block.timestamp;
                        // sell to bnb
                        swapTokens(tokensToSwap);
                    }
                }
                // if not excluded from fees
                if(!excludedFromFees[from]) {
                    // tx limit
                    if(limitSells) {
                    require(amount <= maxSellTxAmount, "maxSellTxAmount Limit Exceeded");
                    }
                }
            }
            // fees redistribution
            if(address(this).balance > minimumWeiForTokenomics) {
                //marketing
                uint256 caBalance = address(this).balance;
                if(sendToMarketing) {
                    uint256 marketingTokens = caBalance * sellMarketingFee / totalSellFee;
                    (bool success,) = address(marketingAddress).call{value: marketingTokens}("");
                    if(success) {
                        emit MarketingFeeCollected(marketingTokens);
                    }
                }
                //development
                if(sendToDev) {
                    uint256 devTokens = caBalance * sellDevFee / totalSellFee;
                    (bool success,) = address(devAddress).call{value: devTokens}("");
                    if(success) {
                        emit DevelopmentFeeCollected(devTokens);
                    }
                }
                //buyback
                if(sendToBuyback) {
                    uint256 buybackTokens = caBalance * sellBuybackFee / totalSellFee;
                    (bool success,) = address(buybackAddress).call{value: buybackTokens}("");
                    if(success) {
                        emit BuybackFeeCollected(buybackTokens);
                    }
                }
            }
            // fees management
            if(feeStatus) {
                // buy
                uint txFees;
                if(trade_type == 1 && buyFeeStatus && !excludedFromFees[to]) {
                    if(kingPassActive && isKingPassActive(to)) {
                        txFees = amount * (totalBuyFee * kingPassFeeDiscount / 1000) / 1000;
                    } else {
                	    txFees = amount * totalBuyFee / 1000;
                    }
                	amount -= txFees;
                    super._transfer(from, address(this), txFees);
                }
                //sell
                else if(trade_type == 2 && sellFeeStatus && !excludedFromFees[from]) {
                    if(kingPassActive && isKingPassActive(from)) {
                        txFees = amount * (totalSellFee * kingPassFeeDiscount / 1000) / 1000;
                    } else {
                	    txFees = amount * totalSellFee / 1000;
                    }
                	amount -= txFees;
                    super._transfer(from, address(this), txFees);
                }
                // no wallet to wallet tax
            }
        }
        // transfer tokens
        super._transfer(from, to, amount);
    }
    //heheboi.gif
}