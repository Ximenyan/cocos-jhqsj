---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by wang.
--- DateTime: 10/7/20 2:21 AM
---

-- 每个人的土地总量
LAND_TOTAL = 10
-- 奸商刷新时间
REFRESH_TIME = 60 * 60 * 24
CONTRACT_FARMS = "contract.jh-farms"
CONTRACT_CONFIGS = "contract.jh-configs"
PRE_SHOVEL_GID = "g11040001"
PRE_SEED_GID = "g200101"
-- 铁锹单价
SHOVEL_PRICE = 10000
-- 产出效率
OUTPUT_EFFICIENCY = { 1, 1.3, 1.7, 2.2, 2.8, 3.5 }

local function _ContractConfig()
    if G_CONFIG == nil then
        G_CONFIG = import_contract(CONTRACT_CONFIGS)
    end
end

local function _check_farm()
    assert(private_data.farm ~= nil, "#还没有农场，请先注册！#")
end

local function _public_data()
    return chainhelper:get_contract_public_data(CONTRACT_FARMS)
end

local function _save()
    write_list = { private_data = { farm = true } }
    chainhelper:write_chain()
end

function rand_seed()
    _ContractConfig()
    -- 随机卖5种
    assert(chainhelper:is_owner(), "#没有权限！#")
    read_list = { public_data = {}}
    chainhelper:read_chain()
    local shop = {}
    local seed_id_table = {}
    local n = 1
    for k in pairs(public_data.seed) do
        seed_id_table[n] = k
        n = n + 1
    end
    local num = 0
    local len = #seed_id_table
    while (num < 3 and num < len) do
        local seed_id = seed_id_table[chainhelper:random() % n + 1]
        if shop[seed_id] == nil then
            num = num + 1
            shop[seed_id] = public_data.seed[seed_id]
        end
    end
    public_data.shop = shop
    write_list = { public_data = { shop = true } }
    chainhelper:write_chain()
end

function sell_seed(id, num)
    -- 卖掉部分种子
    _ContractConfig()
    assert(contract_base_info.invoker_contract_id == G_CONFIG.PLAYERS_CONTRACT_ID,
            "#没有权限！#")
    assert(num > 0, "#参数num不正确!#")
    read_list = { public_data = {} }
    chainhelper:read_chain()
    public_data.shop[id].num = public_data.shop[id].num - num
    assert(public_data.shop[id].num >= 0, "#已经没有那么多库存了！#")
    write_list = { public_data = { shop = true } }
    chainhelper:write_chain()
end

function init()
    assert(chainhelper:is_owner(), "#没有权限！")
    -- 初始化
    public_data = {}
    public_data.shop = {}
    public_data.seed = {}
    chainhelper:write_chain()
end

function UpdateSeed(id, args)
    -- 更新种子配置
    assert(chainhelper:is_owner(), "#没有权限！")
    read_list = { public_data = {} }
    chainhelper:read_chain()
    public_data.seed[id] = cjson.decode(args)
    write_list = { public_data = {} }
    chainhelper:write_chain()
end

function create()
    -- 创建农场
    assert(private_data.farm == nil, '#已有农场不需要再创建！#')
    private_data.farm = { balance = 0,
                          lands = {} }
    chainhelper:write_chain()
end

function BuyShovel(args)
    -- 购买铲子
    -- 转账
    _ContractConfig()
    CToken.TransferIn("COCOS",SHOVEL_PRICE)
    -- 放进背包
    CPlayerItems.create_item_to_package("g11040001", 1)
    _save()
end

function BuySeed(args)
    -- 购买种子
    _check_farm()
    local _args = cjson.decode(args)
    assert(#_args == 2, "#参数不对！#")
    local seed_id = _args[1]
    local seed_num = _args[2]
    assert(type(seed_id) == "string", "#seed_id不对！#")
    assert(type(seed_num) == "number", "#seed_num不对！#")
    seed_num = math.floor(seed_num)
    local args = {
        { 2, { v = seed_id } },
        { 1, { v = seed_num } }
    }
    local _public_data = _public_data()
    local seed = _public_data.shop[seed_id]
    chainhelper:invoke_contract_function(CONTRACT_FARMS, "sell_seed",
            cjson.encode(args))
    -- 转账
    CToken.TransferIn("COCOS",seed.price)
    -- 生成种子放进背包
    CPlayerItems.create_item_to_package(seed_id, seed_num)
    _save()
end

function BuyLand(args)
    -- 买地\升级
    local _args = cjson.decode(args)
    assert(#_args == 2, "#参数不对！")
    assert(type(_args[1]) == "string", "#参数1类型不对！#")
    assert(type(_args[2]) == "string", "#参数2类型不对！#")
    local land_key = _args[1]
    local shovel_id = _args[2]
    -- 检查铁锹ID是否正确
    assert(string.sub(shovel_id, 1, 9) == PRE_SHOVEL_GID,
            "#参数shovle_id不正确#")
    local farm = private_data.farm
    local package = private_data.backpack
    local attrs = private_data.attrs
    assert(farm.balance <= LAND_TOTAL, "#土地数量最多8块！")
    local land = farm.lands[land_key]
    if land == nil then
        farm.balance = farm.balance + 1
        land = { status = false, star = 0 }
    else
        assert(land.status == false, "#土地上有植物,暂时不能升级!#")
    end
    assert(land.star < package.goods[shovel_id].base_info.star, "#请使用"..land.star.."星以上的铁锹升级土地!#")
    land.star = land.star + 1
    farm.lands[land_key] = land
    -- 消耗一把铁锹
    CPlayerPackage.spent_item(shovel_id, 1)
    chainhelper:log(attrs.name..land_key.."升级到了"..farm.lands[land_key].star.."级")
    _save()
end

function Plant(args)
    -- 种植
    local _args = cjson.decode(args)
    assert(#_args == 2, "#参数不对！")
    local farm = private_data.farm
    local land_key = _args[1]
    local seed_id = _args[2]
    assert(string.sub(seed_id, 1, 7) == PRE_SEED_GID, "#别乱种！#")
    assert(farm.lands[land_key] ~= nil, "#这块土地还未开垦！")
    assert(farm.lands[land_key].status == false, "#这块土地已经种上了!#")
    -- 消耗一颗种子
    CPlayerPackage.spent_item(seed_id, 1)
    local seed_config = _public_data().seed
    local land = farm.lands[land_key]
    local plant = {}
    land.status = true
    plant.star = seed_config[seed_id].star
    plant.gid = seed_id
    plant.time = seed_config[seed_id].time
    plant.uint = seed_config[seed_id].uint
    plant.timestamp = chainhelper:time()
    plant.token_id = seed_config[seed_id].token_id
    land.plant = plant
    _save()
end

function Reap(args)
    -- 收割的季节到了
    local _args = cjson.decode(args)
    assert(#_args == 1, "#参数不对！#")
    local farm = private_data.farm
    local land_key = _args[1]
    local land = farm.lands[land_key]
    assert(land ~= nil, "#土地未开垦！#")
    assert(land.status, "#土地未种植！#")
    local plant = land.plant
    local timestamp = plant.timestamp
    local token_id = plant.token_id
    local plant_time = plant.time
    local now_time = chainhelper:time()
    local time_long = now_time - timestamp
    if now_time >= timestamp + plant_time then
        time_long = plant_time
    end
    land.plant = nil
    land.status = false
    -- 保存数据
    local efficiency = OUTPUT_EFFICIENCY[land.star]
    local total = plant.uint * time_long * efficiency / 10
    total = math.floor(total)
    chainhelper:log('收获' .. total .. token_id)
    -- 解锁并转发到账户
    CToken.TransferOut(token_id, total)
    _save()
end
function test() chainhelper:log('!- 3') end