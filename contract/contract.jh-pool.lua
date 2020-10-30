CONTRACT_CONFIGS = "contract.jh-configs"
CONTRACT_SELF = "contract.jh-pool"
PRE_SHOVEL_GID = "g11040001"

local function _public_data()
    return chainhelper:get_contract_public_data(CONTRACT_SELF)
end

local function _read_data() 
    read_list = {private_data={}}
    chainhelper:read_chain()
end

local function _save_data()
    write_list = {private_data={}}
    chainhelper:write_chain()
end 

local function _ContractConfig()
    if G_CONFIG == nil then
        G_CONFIG = import_contract(CONTRACT_CONFIGS) 
    end
end

-- invoke其它合约的方法
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


function StartMining(args) 
    local _args = cjson.decode(args)
    assert(#_args == 1, "#参数不对！")
    assert(type(_args[1]) == "string", "#参数1类型不对！#")
    local cid = _args[1]
    assert(string.sub(cid, 1, 9) == PRE_SHOVEL_GID,
            "#参数shovle_id不正确#")
    local star = private_data.package.goods[shovel_id].base_info.star
    CPlayerPackage.spent_item(cid, 1)
    private_data.pool = {star=star,timestamp=chainhelper:time()}
    chainhelper:log("开始挖矿");
end

function _StopMining() 
    assert(private_data.pool~= nil,"#你还没有请矿工挖矿呢！#")
    local pool = {star=star,timestamp=chainhelper:time()}
    private_data.pool = {star=star, timestamp=chainhelper:time()}
end

function StopMining() 
end