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
TIMES = 24 * 60 * 60
COIN_SYMBOL = "DSC"
CONTRACT_TOKEN = "contract.jh-token"
CONTRACT_CONFIGS = "contract.jh-configs"
local CONTRACT_CROSWAP = "contract.croswap"

local function _encodeValueType(value)
    local tp = type(value)
    return tp == "number" and 1
            or tp == "string" and 2
            or tp == "boolean" and 3
            or tp == "table" and 4
            or tp == "function" and 5
            or 2
end

-- 调用其它合约的方法
local function _invokeContractFunction(contract_name, function_name, ...)
    local args = {...}
    local value_list = {}
    for i = 1, #args do
        local value = args[i]
        if type(value) == "table" then
            value = cjson.encode(value)
        end
        table.insert(value_list, {
            _encodeValueType(value),
            {v = value},
        })
    end
    value_list = cjson.encode(value_list)
    chainhelper:invoke_contract_function(contract_name, function_name, value_list)
end

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

function Pledge(lp_id) 
    --  持质押持股
    _read_data()
    -- 主网放开
    --assert(contract_base_info.caller == "1.2.29340","#测试中，仅owner可用！#")
    lp_id=tostring(lp_id)
    _invokeContractFunction(CONTRACT_CROSWAP, "checkLP", lp_id)
    local lp = cjson.decode(cjson.decode(chainhelper:get_nft_asset(lp_id)).base_describe)
    assert(lp ~= nil ,"lp not found")
    local lpname = lp.name
    assert(lpname == "COCOS-DSC-LP", "#质押的LP类型不对！#")
    local lpversion = tonumber(lp.version)
    assert(lp.version == 1, "#质押的lp版本不对#")
    local new_num = lp.liquidity
    if private_data.plegde_num == nil then private_data.plegde_num = 0 end
    assert((private_data.plegde_num > 0) or (new_num >= 50000000 ),"#最小质押50000000 liquidity!#")
    if private_data.lp_ids == nil then
        private_data = {
            plegde_num=new_num, 
            timestamp=chainhelper:time(),
            lp_ids = {lp_id}
        }
    else
        private_data.plegde_num= private_data.plegde_num + new_num
        table.insert(private_data.lp_ids, lp_id)
    end
    if public_data.total == nil then public_data.total = 0 end
    public_data.total = public_data.total + new_num
    chainhelper:transfer_nht_from_caller(contract_base_info.owner, lp_id, true)
    chainhelper:log(contract_base_info.caller .. "质押了" .. new_num .. "COCOS-DSC-LP liquidity!")
    _save_data()
end

function Withdraw()
    -- 领取
    _read_data()
    _ContractConfig()
    _CToken()
    -- 主网放开
    --assert(contract_base_info.caller == "1.2.29340","#测试中，仅owner可用！#")
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
                --chainhelper:log('transfer '.. coin_symbol .. withdraw_balance)
                CToken.TransferOut(coin_symbol, withdraw_balance)
            end
        end
    end
    _save_data()
end

function Redeem()
    -- 赎回
    _read_data()
    -- 主网放开
    --assert(contract_base_info.caller == "1.2.29340","#测试中，仅owner可用！#")
    assert(private_data.plegde_num ~= nil and private_data.plegde_num > 0,"#还没质押持股呢！#")
    assert(chainhelper:time() > (private_data.timestamp + TIMES),"#领取分红24小时后可赎回！#")
    chainhelper:log(contract_base_info.caller .. "赎回了" .. private_data.plegde_num .. " COCOS-DSC-LP liquidity!")
    public_data.total = public_data.total - private_data.plegde_num
    private_data.plegde_num = 0
    private_data.timestamp = chainhelper:time()
    for i=1,#private_data.lp_ids do 
        chainhelper:transfer_nht_from_owner(contract_base_info.caller, private_data.lp_ids[i], true)
    end
    private_data.lp_ids = {}
    _save_data()
end