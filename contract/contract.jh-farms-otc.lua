-- 每500 COCOS 和 1DSC，为种子库增加1颗义种
-- 10块地都开垦过的玩家，才能种子库中领取义种
-- 义种收获后的DSC 2% 归玩家所有, 98% 锁定在本合约
-- 锁定在本合约的DSC和COCOS，玩家随时可领取属于自己的份额
-- 注意，提供义种之后无法赎回，只能在25天左右时间内，慢慢领取回去
-- 提供种子的人在领取时，将会支付5/1000手续费
 
PRECISION = 100000
MIN_PLEDGE_COCOS = 500 * PRECISION
MIN_PLEDGE_DSC = 10 * PRECISION
LOCK_ACCOUNT = "jhqsj-farms-otc"
CONTRACT_TOKEN_OTC = "contract.jh-token-otc"
CONTRACT_CONFIGS = "contract.jh-configs"
MAX_TIME_LONG = 25 * 24 * 60 * 60

local function _read_data() 
    read_list = {private_data={},public_data={}}
    chainhelper:read_chain()
end

local function _save_data()
    write_list = {private_data={},public_data={}}
    chainhelper:write_chain()
end

local function _ContractConfig()
    if G_CONFIG == nil then
        G_CONFIG = import_contract(CONTRACT_CONFIGS)
    end
end

local function _ContractTokenOTC()
    if COTCToken == nil then
        COTCToken = import_contract(CONTRACT_TOKEN_OTC)
    end
end

function init() 
    _read_data()
    _ContractConfig()
    assert(chainhelper:is_owner(), "#没有权限#");
end

function Pledge(num) 
    --  为奸商 种子库 添加种子
    _ContractTokenOTC()
    _read_data()
    assert(type(num) == "number", "#num不正确#")
    num = math.floor(num)
    local cocos_amount = math.floor(num * MIN_PLEDGE_COCOS)  
    local dsc_balance = chainhelper:get_account_balance(LOCK_ACCOUNT,"DSC")
    local cocos_balance = chainhelper:get_account_balance(LOCK_ACCOUNT,"COCOS")
    if cocos_balance = 0 then cocos_balance == 500 end
    if dsc_balance = 0 then dsc_balance = 10 end
    local dsc_amount = math.floor(cocos_amount * dsc_balance / cocos_balance)   
    if private_data.plegde_num == nil then 
        --private_data.plegde_dsc_amount = 0,
        private_data.plegde_cocos_amount = 0,
        private_data.plegde_num = 0 
    end
    assert(cocos_amount >= MIN_PLEDGE_COCOS and cocos_amount < chainhelper:number_max(),"#最小为种子库增加1枚种子!#")
    COTCToken.TransferIn("COCOS", cocos_amount) -- 转入COCOS
    COTCToken.TransferIn("DSC", dsc_amount) -- 转入DSC
    --private_data.plegde_dsc_amount = private_data.plegde_dsc_amount + dsc_amount
    private_data.plegde_cocos_amount =  private_data.plegde_cocos_amount + cocos_amount
    private_data.plegde_num = private_data.plegde_num + num
    private_data.timestamp = chainhelper:time()
    if public_data.total == nil then
         public_data.total = 0 
    end
    if public_data.now_seed == nil then
         public_data.now_seed = 0 
    end
    public_data.total = public_data.total + num
    public_data.now_seed = public_data.now_seed + num
    chainhelper:log(contract_base_info.caller .. "为种子库添加了" .. num .. "枚种子!")
    _save_data()
end

function Withdraw() 
    _ContractTokenOTC()
    _ContractConfig()
    _read_data()
    assert(private_data.timestamp > 0, "#还没有质押或操作！#")
    assert(private_data.plegde_cocos_amount > 0, "#还没有质押或操作！#")
    local dsc_balance = chainhelper:get_account_balance(LOCK_ACCOUNT,"DSC")
    local time_long = chainhelper:time() - private_data.timestamp
    local time_xs = time_long / MAX_TIME_LONG
    if time_xs > 1 then time_xs = 1 end
    local plegde_xs = private_data.plegde_num / public_data.total
    local cocos_amount = private_data.plegde_cocos_amount * time_xs
    -- local dsc_amount = private_data.plegde_dsc_amount * time_xs
    -- 发还质押的COCOS金额 和 分得的DSC
    COTCToken.TransferOut("COCOS",math.floor(dsc_balance))
    chainhelper:transfer_from_caller(G_CONFIG.ASSET_ACCEPT_ACCOUNT,
        math.floor(dsc_balance * time_xs * 0.001),
        "COCOS",
        true)
    COTCToken.TransferOut("DSC",math.floor(dsc_balance * plegde_xs))
    chainhelper:transfer_from_caller(G_CONFIG.ASSET_ACCEPT_ACCOUNT,
        math.floor(dsc_balance * time_xs * 0.001),
        "dsc",
        true)
    private_data.plegde_cocos_amount = dsc_balance
    _save_data()
end

function Destroy()
end

function LockAsset()
end

function ReceiveSeed() 
end