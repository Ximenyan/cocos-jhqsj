-- 每500 COCOS 和 1DSC，为种子库增加1颗义种
-- 10块地都开垦过的玩家，才能种子库中领取义种
-- 义种收获后的DSC 5% 归勤劳的少侠所有, 95%归提供种子的人按份额瓜分
-- 提供种子的人可以在任何时候领取收益和本金，但是，提前领取会扣掉5/1000
-- 提供种子的人在领取时，将会支付5/1000手续费
 
PRECISION = 100000
MIN_PLEDGE_COCOS = 500 * PRECISION
MIN_PLEDGE_DSC = 10 * PRECISION
LOCK_ACCOUNT = "jhqsj-farms-otc"
CONTRACT_TOKEN_OTC = "contract.jh-token-otc"
CONTRACT_CONFIGS = "contract.jh-configs"
CONTRACT_NAME = "contract.jh-farms-otc-test"
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


function Pledge(num) 
    --  为奸商 种子库 添加种子
    _ContractTokenOTC()
    _read_data()
    assert(type(num) == "number", "#num不正确#")
    num = math.floor(num)
    local cocos_amount = math.floor(num * MIN_PLEDGE_COCOS)  
    local dsc_balance = chainhelper:get_account_balance(LOCK_ACCOUNT,"DSC")
    local cocos_balance = chainhelper:get_account_balance(LOCK_ACCOUNT,"COCOS")
    if cocos_balance == 0 then cocos_balance = 500 end
    if dsc_balance == 0 then dsc_balance = 10 end
    local dsc_amount = math.floor(cocos_amount * dsc_balance / cocos_balance)   
    if private_data.plegde_cocos_amount == nil then 
        private_data.plegde_cocos_amount = 0
    end
    assert(cocos_amount >= MIN_PLEDGE_COCOS and cocos_amount < chainhelper:number_max(),"#最小为种子库增加1枚种子!#")
    COTCToken.TransferIn("COCOS", cocos_amount) -- 转入COCOS
    COTCToken.TransferIn("DSC", dsc_amount) -- 转入DSC
    chainhelper:log("质押".. (cocos_amount/100000) .. "COCOS")
    chainhelper:log("质押".. (dsc_amount/100000) .. "DSC")
    private_data.plegde_cocos_amount =  private_data.plegde_cocos_amount + cocos_amount
    private_data.timestamp = chainhelper:time()
    if public_data.total_seed == nil then
         public_data.total_plegde_cocos_amount = 0
         public_data.total_seed = 0 
    end
    public_data.total_plegde_cocos_amount = public_data.total_plegde_cocos_amount + cocos_amount
    public_data.total_seed = public_data.total_seed + num
    chainhelper:log(contract_base_info.caller .. "为种子库添加了" .. num .. "枚种子!")
    _save_data()
end

function Withdraw() 
    _ContractTokenOTC()
    _ContractConfig()
    _read_data()
    assert(private_data.timestamp > 0, "#还没有质押或操作！#")
    assert(private_data.plegde_cocos_amount > 0, "#还没有质押或操作！#")
    local dsc_balance = 55000000000-- chainhelper:get_account_balance(LOCK_ACCOUNT,"DSC")
    local cocos_balance = 110000000--chainhelper:get_account_balance(LOCK_ACCOUNT,"COCOS")
    local time_long = chainhelper:time() - private_data.timestamp
    local time_xs = time_long / MAX_TIME_LONG
    if time_xs > 1 then time_xs = 1 end
    -- 计算当前的质押占比
    local plegde_xs =  private_data.plegde_cocos_amount / public_data.total_plegde_cocos_amount
    local cocos_amount = math.floor(cocos_balance * plegde_xs)
    local dsc_amount = math.floor(dsc_balance * plegde_xs)
    -- 发还质押的COCOS金额 和 分得的DSC
    COTCToken.TransferOut("COCOS", cocos_amount)
    COTCToken.TransferOut("DSC", dsc_amount)
    chainhelper:log("赎回".. (cocos_amount /100000) .. "COCOS")
    chainhelper:log("赎回".. (dsc_amount /100000) .. "DSC")
    -- 未到期领取，需要支付千分之5 违约金，千分之一归开发者，千分之4 由其他人瓜分
    if time_xs < 1 then 
        chainhelper:log("支付违约金".. (cocos_amount * 0.004/100000) .. "COCOS")
        chainhelper:log("支付违约金".. (dsc_amount * 0.004/100000) .. "DSC")
        -- 1/1000
        --chainhelper:transfer_from_caller(G_CONFIG.ASSET_ACCEPT_ACCOUNT,
        --    math.floor(cocos_amount * 0.001),
        --    "COCOS",
        --    true)
        --chainhelper:transfer_from_caller(G_CONFIG.ASSET_ACCEPT_ACCOUNT,
        --    math.floor(dsc_amount * 0.001),
        --    "DSC",
        --    true)
        -- 4/1000
        COTCToken.TransferIn("COCOS",math.floor(dsc_amount * 0.004))
        COTCToken.TransferIn("DSC",math.floor(dsc_amount * 0.004))
    end
    -- 减去按时间系数，能赎回的cocos
    public_data.total_plegde_cocos_amount = public_data.total_plegde_cocos_amount - private_data.plegde_cocos_amount
    private_data.plegde_cocos_amount = 0
    _save_data()
end

function _Reap()
    _read_data()
    _ContractConfig()
    assert(contract_base_info.invoker_contract_id ==
               G_CONFIG.PLAYERS_CONTRACT_ID, "#没有权限！#")
    if public_data.reap_num == nil then public_data.reap_num = 0 end
    public_data.reap_num = public_data.reap_num + 1
    _save_data()
end

-- 收割的时候调用
function Reap() 
    chainhelper:invoke_contract_function(CONTRACT_NAME, "_Reap", "[]")
end

function Clear() 
    public_data = {}
    private_data = {}
    _save_data()
end