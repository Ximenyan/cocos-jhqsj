--
-- Created by IntelliJ IDEA.
-- User: wang
-- Date: 2020/10/9
-- Time: 上午10:22
-- To change this template use File | Settings | File Templates.
--
PRECISION = 100000
MIN_PLEDGE = 100 * PRECISION
MAX_PLEDGE = 30000000 * PRECISION
TIMES = 1 * 60
COIN_SYMBOL = "DSC"
CONTRACT_TOKEN = "contract.jh-token"
CONTRACT_CONFIGS = "contract.jh-configs"

local function _CToken() 
    CToken = import_contract(CONTRACT_TOKEN)
end

local function _ContractConfig()
    if G_CONFIG == nil then
        G_CONFIG = import_contract(CONTRACT_CONFIGS)
    end
end

local function _read_data() 
    read_list = {private_data={},public_data={}}
    chainhelper:read_chain()
end

local function _save_data()
    write_list = {private_data={},public_data={}}
    chainhelper:write_chain()
end


function Pledge(num) 
    --  持质押持股
    _read_data()
    assert(type(num) == "number", "#num不正确#")
    local new_num = math.floor(num * PRECISION)
    assert(new_num >= MIN_PLEDGE and new_num < MAX_PLEDGE,"#最小质押100DSC!#")
    chainhelper:transfer_from_caller(contract_base_info.owner, new_num, COIN_SYMBOL, true)
    chainhelper:adjust_lock_asset(COIN_SYMBOL, new_num)--锁仓
    if private_data.plegde_num == nil then
        private_data = {plegde_num=new_num, timestamp=chainhelper:time()}
    else
        private_data = {plegde_num=private_data.plegde_num + new_num,timestamp=chainhelper:time()}
    end
    if public_data.total == nil then public_data.total = 0 end
    public_data.total = public_data.total + new_num
    chainhelper:log(contract_base_info.caller .. "质押了" .. num .. "DSC!")
    _save_data()
end

function Withdraw()
    -- 领取
    _read_data()
    _ContractConfig()
    _CToken()
    assert(private_data.plegde_num ~= nil and private_data.plegde_num > 0, "#还没质押持股呢！#")
    assert(chainhelper:time() > (private_data.timestamp + TIMES), "#每24小时可领取收益一次！#")
    local DIVIDEND_COINS = G_CONFIG.DIVIDEND_COINS
    local balance = 0
    local withdraw_balance = 0
    local coin_symbol = ""
    private_data.timestamp = chainhelper:time()
    for i=1,#DIVIDEND_COINS do 
        coin_symbol = DIVIDEND_COINS[i]
        balance = chainhelper:get_account_balance(G_CONFIG.TOKEN_POOL_ACCOUNT, coin_symbol)
        if(balance > 0) then
            -- 当前池的百分之一,在乘以持股率,就是分红的金额
            withdraw_balance = (balance / 100) * (private_data.plegde_num / public_data.total)
            withdraw_balance = math.floor(withdraw_balance)
            if withdraw_balance > 0 then 
                CToken.TransferOut(coin_symbol, withdraw_balance)
            end
        end
    end
    _save_data()
end

function Redeem()
    -- 赎回
    _read_data()
    assert(private_data.plegde_num ~= nil and private_data.plegde_num > 0,"#还没质押持股呢！#")
    assert(chainhelper:time() > (private_data.timestamp + TIMES),"#领取或质押24小时后可赎回！#")
    chainhelper:adjust_lock_asset(COIN_SYMBOL, -private_data.plegde_num)--解锁仓
    chainhelper:transfer_from_owner(contract_base_info.caller, private_data.plegde_num, COIN_SYMBOL,true)
    chainhelper:log(contract_base_info.caller .. "赎回了" .. private_data.plegde_num .. "DSC!")
    private_data.plegde_num = 0
    private_data.timestamp = chainhelper:time()
    public_data.total = public_data.total - private_data.plegde_num
    _save_data()
end