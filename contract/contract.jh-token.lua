---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by wang.
--- DateTime: 10/7/20 2:45 AM
---
CONTRACT_NAME = "contract.jh-token"
CONTRACT_CONFIGS = "contract.jh-configs"

local function _read_data() 
    read_list = {private_data={}}
    chainhelper:read_chain()
end

local function _save_data()
    write_list = {private_data={}}
    chainhelper:write_chain()
end

function set_guide(account)
    _read_data()
    assert(account ~= contract_base_info.caller,"#邀请人不能是自己！#")
    assert(account ~= "1.2.1254100","#邀请人不能是锁仓人！#")
    assert(account ~= "jhqsj-token","#邀请人不能是锁仓人！#")
    assert(private_data.guide == nil, "#已经填写过接引人了！#")
    local balance = chainhelper:get_account_balance(account, "DSC")
    assert(balance > 100000, "#持有DSC大于1的人，才能当接引人！#")
    -- 填写邀请人 
    private_data.guide = account
    _save_data()
end

local function _ContractConfig()
    if G_CONFIG == nil then
        G_CONFIG = import_contract(CONTRACT_CONFIGS)
    end
end

function _TransferOut(symbol_or_id, amount)
    _ContractConfig()
    assert(amount > 0, "#amount不正确!#")
    local auth = false
    -- 验证调用合约是否正确
    for i = 1,#G_CONFIG.TOKEN_CONTRACT_WHITE_LIST do
        if contract_base_info.invoker_contract_id == G_CONFIG.TOKEN_CONTRACT_WHITE_LIST[i] then
            auth = true
            break
        end
    end
    assert(auth or contract_base_info.caller == G_CONFIG.ASSET_ACCEPT_ACCOUNT,"#没有权限#")
    chainhelper:adjust_lock_asset(symbol_or_id, -amount)
    if contract_base_info.caller ~= G_CONFIG.ASSET_ACCEPT_ACCOUNT then 
        _read_data()
        if  private_data.guide == nil then private_data.guide = G_CONFIG.ASSET_ACCEPT_ACCOUNT end
        local guide_amount = math.floor(G_CONFIG.GUIDE_DIVIDEND_RATE * amount)
        if guide_amount > 0 then 
            chainhelper:transfer_from_owner(private_data.guide, guide_amount, symbol_or_id, true) 
            amount = amount - guide_amount
        end
    end
    chainhelper:transfer_from_owner(contract_base_info.caller, amount, symbol_or_id, true)
    
end

function _TransferIn(symbol_or_id, amount)
    _ContractConfig()
    assert(amount > 0, "#amount不正确!#")
    local dev_amount = math.floor(amount * G_CONFIG.DEV_DIVIDEND_RATE)
    local com_amount = math.floor(amount * G_CONFIG.COMMUNITY_DIVIDEND_RATE)
    local lock_amount = math.floor(amount - dev_amount -com_amount)
    --local accept_amount = amount - lock_amount
    chainhelper:transfer_from_caller(contract_base_info.owner, lock_amount, symbol_or_id, true)
    chainhelper:adjust_lock_asset(symbol_or_id, lock_amount)
    -- 转给开发账户
    chainhelper:transfer_from_caller(G_CONFIG.ASSET_ACCEPT_ACCOUNT, dev_amount, symbol_or_id, true)
    -- 转给社区
    chainhelper:transfer_from_caller(G_CONFIG.COMMUNITY_ACCEPT_ACCOUNT, com_amount, symbol_or_id, true)
end

function _LockAsset(symbol_or_id, amount)
    assert(type(amount) == "number","#amount不确#")
    assert(amount > 0, "#amount不正确!#")
    chainhelper:transfer_from_caller(contract_base_info.owner, amount, symbol_or_id, true)
    chainhelper:adjust_lock_asset(symbol_or_id, amount)
end

function TransferIn(symbol_or_id, amount)
    chainhelper:invoke_contract_function(CONTRACT_NAME, "_TransferIn", cjson.encode({
        { 2, { v = symbol_or_id } },
        { 1, { v = amount } }
    }))
end

function TransferOut(symbol_or_id, amount)
    chainhelper:invoke_contract_function(CONTRACT_NAME, "_TransferOut", cjson.encode({
        { 2, { v = symbol_or_id } },
        { 1, { v = amount } }
    }))
end

function test() chainhelper:log('!- 3') end