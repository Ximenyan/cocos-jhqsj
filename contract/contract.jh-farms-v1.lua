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
NFT_CONTRACT_INFO = "NFT_CONTRACT_INFO"
PRE_SHOVEL_GID = "g11040001"
PRE_SEED_GID = "g200101"
-- 最大偷菜次数
MAX_STEAL_COUNT = 5
-- 铁锹单价
SHOVEL_PRICE = 500000000
-- 产出效率
OUTPUT_EFFICIENCY = { 1, 1.2, 1.6, 2.5, 4.2, 8 }
local function _ContractConfig()
    if G_CONFIG == nil then
        G_CONFIG = import_contract(CONTRACT_CONFIGS)
    end
end
local function _get_dsc_price() 
    local nft = cjson.decode(chainhelper:get_nft_asset("4.2.1176342"))
    for _, contract in pairs(nft.describe_with_contract) do
        if contract[1] == "1.16.165" then
            for _, describe in pairs(contract[2]) do
                if describe[1] == "pair" then
                    local pair = cjson.decode(describe[2])
                    return pair.c / pair.t
                end
            end
            return 100
        end
    end
    return 100
end
local function _check_farm()
    assert(private_data.farm ~= nil, "#还没有农场，请先注册！#")
end

local function _public_data()
    return chainhelper:get_contract_public_data(CONTRACT_FARMS)
end

local function _get_nft_contract_info(nft_id) 
    local nft = cjson.decode(chainhelper:get_nft_asset(nft_id))
    assert(nft.world_view == G_CONFIG.FARMS_WORLD_VIEW, "#世界观不正确！#")
    for _, contract in pairs(nft.describe_with_contract) do
        if contract[1] == contract_base_info.id then
            for _, describe in pairs(contract[2]) do
                if describe[1] == NFT_CONTRACT_INFO then
                    return cjson.decode(describe[2])
                end
            end
            return {}
        end
    end
    return {}
end

function create()
    -- 创建农场
    assert(private_data.farm == nil, '#已有农场不需要再创建！#')
    local attrs = private_data.attrs
    -- 创建nft共享数据
    local base_info = {
        name= attrs.name.."的农田",
    }
    local nft_id = chainhelper:create_nft_asset(contract_base_info.owner, G_CONFIG.FARMS_WORLD_VIEW,
            cjson.encode(base_info),true,true)
    chainhelper:change_nht_active_by_owner(contract_base_info.caller, nft_id, false)
    -- 10块农田写入信息
    local nft_contract_info = {}
    for i=0,9 do 
        nft_contract_info["land_" .. i] = {}
    end
    nft_contract_info.owner = contract_base_info.caller
    -- 记录农田信息
    private_data.farm = { 
        nft_id = nft_id
    }
    chainhelper:nht_describe_change(nft_id, NFT_CONTRACT_INFO, cjson.encode(nft_contract_info), false)
    chainhelper:change_nht_active_by_owner(contract_base_info.owner, nft_id, false)
    chainhelper:write_chain()
end

function update_shop(ids)
    _ContractConfig()
    assert(chainhelper:is_owner(), "#没有权限！#")
    read_list = { public_data = {}}
    ids = cjson.decode(ids)
    chainhelper:read_chain()
    local shop = {}
    local n = 1
    local len = #ids
    while (n <= len) do
        local seed_id = ids[n]
        shop[seed_id] = public_data.seed[seed_id]
        n = n + 1
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

function BuyShovel(args)
    -- 购买铲子
    -- 转账
    _ContractConfig()
    CToken.TransferIn("COCOS",SHOVEL_PRICE)
    -- 放进背包
    CPlayerItems.create_item_to_package("g11040001", 1)
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
    CToken.TransferIn("COCOS",seed.price * seed_num)
    -- 生成种子放进背包
    CPlayerItems.create_item_to_package(seed_id, seed_num)
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
    assert(string.sub(land_key,1,4) == "land","#参数land_id不正确#")
    assert(string.sub(shovel_id, 1, 9) == PRE_SHOVEL_GID,
            "#参数shovle_id不正确#")
    local farm = private_data.farm
    local nft_id = farm.nft_id
    local nft_land = _get_nft_contract_info(nft_id)
    local land = nft_land[land_key]
    assert(land ~= nil,"#土地编号不正确！#")
    local package = private_data.backpack
    local attrs = private_data.attrs
    if land.status == nil then
        land = { status = false, star = 0 }
    else
        assert(land.status == false, "#土地上有植物,暂时不能升级!#")
    end
    assert(land.star < package.goods[shovel_id].base_info.star, "#请使用"..land.star.."星以上的铁锹升级土地!#")
    land.star = land.star + 1
    -- 消耗一把铁锹
    CPlayerPackage.spent_item(shovel_id, 1)
    chainhelper:log(attrs.name..land_key.."升级到了"..land.star.."级")
    -- 记录到nft以备共享数据
    nft_land[land_key] = land
    chainhelper:change_nht_active_by_owner(contract_base_info.caller, nft_id, false)
    chainhelper:nht_describe_change(nft_id,NFT_CONTRACT_INFO,cjson.encode(nft_land),false)
    chainhelper:change_nht_active_by_owner(contract_base_info.owner, nft_id, false)
end

function Plant(args)
    -- 种植
    local _args = cjson.decode(args)
    assert(#_args == 2, "#参数不对！")
    local farm = private_data.farm
    local nft_id = farm.nft_id
    local land_key = _args[1]
    local seed_id = _args[2]
    assert(string.sub(seed_id, 1, 7) == PRE_SEED_GID, "#别乱种！#")
    local nft_land = _get_nft_contract_info(nft_id)
    local land = nft_land[land_key]
    assert(land.status ~= nil,"#土地还未开垦！#")
    assert(land.status == false, "#这块土地已经种上了!#")
    -- 消耗一颗种子
    CPlayerPackage.spent_item(seed_id, 1)
    local seed_config = _public_data().seed
    local plant = {}
    land.status = true
    plant.star = seed_config[seed_id].star
    plant.gid = seed_id
    plant.time = seed_config[seed_id].time
    plant.uint = seed_config[seed_id].uint
    plant.timestamp = chainhelper:time()
    plant.token_id = seed_config[seed_id].token_id
    plant.item_id = seed_config[seed_id].item_id
    -- 记录到NFT
    land.plant = plant
    -- 记录到nft以备共享数据
    nft_land[land_key] = land
    chainhelper:change_nht_active_by_owner(contract_base_info.caller, nft_id, false)
    chainhelper:nht_describe_change(nft_id,NFT_CONTRACT_INFO,cjson.encode(nft_land),false)
    chainhelper:change_nht_active_by_owner(contract_base_info.owner, nft_id, false)
end

function Reap(args)
    -- 收割的季节到了
    local _args = cjson.decode(args)
    assert(#_args == 1, "#参数不对！#")
    local farm = private_data.farm
    local nft_id = farm.nft_id
    local land_key = _args[1]
    local nft_land = _get_nft_contract_info(nft_id)
    local land =  nft_land[land_key]
    assert(land ~= nil,"#土地未开垦！#")
    assert(land.status, "#土地未种植！#")
    if land.steal_count == nil then land.steal_count = 0 end
    local plant = land.plant
    local timestamp = plant.timestamp
    local token_id = plant.token_id
    local item_id = plant.item_id
    local plant_time = plant.time
    local now_time = chainhelper:time()
    local time_long = now_time - timestamp
    if now_time >= timestamp + plant_time then
        time_long = plant_time
    end
    -- 保存数据
    local efficiency = OUTPUT_EFFICIENCY[land.star]
    local steal_success_count = 0
    if  land.steal_info then 
        for _, value in pairs(land.steal_info) do
            if value[1] then steal_success_count = steal_success_count + 1 end
        end
    end
    local total = plant.uint * time_long * efficiency * (1 - 0.1 * steal_success_count)/ 10
    total = math.floor(total)
    -- 解锁并转发到账户
    if string.sub(token_id,1,1) ~= "[" then 
        chainhelper:log('收获' .. (total/100000) .. token_id)
        CToken.TransferOut(token_id, total)
    else 
        chainhelper:log('收获' .. total .. token_id)
        CPlayerItems.create_item_to_package(item_id, total)
    end
    -- 记录到nft以备共享数据
    land.plant = nil
    land.steal_count = nil
    land.steal_info = nil
    land.status = false
    nft_land[land_key] = land
    chainhelper:change_nht_active_by_owner(contract_base_info.caller, nft_id, false)
    chainhelper:nht_describe_change(nft_id,NFT_CONTRACT_INFO,cjson.encode(nft_land),false)
    chainhelper:change_nht_active_by_owner(contract_base_info.owner, nft_id, false)
end

function Steal(args)
    -- 开始偷菜了
    local _args = cjson.decode(args)
    assert(#_args == 2, "#参数不对！#")
    local farm = private_data.farm
    local _self_nft_id = farm.nft_id
    local _self_nft_land = _get_nft_contract_info(_self_nft_id)
    local _self_land_num = 0
    for i=0,9 do 
        if _self_nft_land["land_"..i].status ~= nil then 
            _self_land_num = _self_land_num + 1
            if _self_land_num >= 2 then
                break
            end
        end
    end
    assert(_self_land_num >= 2,"#你自己的土地数太少，不能偷窃！#");
    local attrs = private_data.attrs
    assert(farm.Sacrifice ,"#还没献祭呢！#")
    local nft_id = _args[1]
    local land_key = _args[2]
    assert(nft_id ~= farm.nft_id, "#不能偷自己的！#")
    local nft_land = _get_nft_contract_info(nft_id)
    local dog_info =  nft_land.dog_info
    if dog_info == nil then 
        dog_info = {
            growt = 0,
            timestamp = 0,
            kill_timestamp = 0
        } 
    end
    local now_time = chainhelper:time()
    -- 狗防御两小时,被揍5钟内可偷
    assert( (now_time < (dog_info.kill_timestamp + 300)) or (now_time > (dog_info.timestamp + (240 * 60))), "#狗很凶，没法偷窃！#") 
    local land =  nft_land[land_key]
    assert(land.status ~= nil,"#土地未开垦！#")
    assert(land.status, "#土地未种植！#")
    if land.steal_count == nil then land.steal_count = 0 end
    if land.steal_info == nil then land.steal_info = {} end
    assert(land.steal_info[contract_base_info.caller] == nil, "#这块地你已经偷过了，给主人留点吧！#")
    assert(land.steal_count < MAX_STEAL_COUNT, "#这块地已经损失了操过一半了，给主人留点吧！#")
    local plant = land.plant
    local timestamp = plant.timestamp
    local token_id = plant.token_id
    local item_id = plant.item_id
    local plant_time = plant.time
    local time_long = now_time - timestamp
    if now_time >= timestamp + plant_time then
        time_long = plant_time
    end
    -- 偷取
    local efficiency = OUTPUT_EFFICIENCY[land.star]
    -- 计算成功还是失败
    -- 星级越高，防御力越高，哈哈哈，完美
    -- 失败概率
    -- 1 星 50%
    -- 2 星 52%
    -- 3 星 54%
    -- 4 星 56%
    -- 5 星 58%
    -- 6 星 60%
    local random_number = chainhelper:random() % 10000
    local steal_success_count = 0
    for _, value in pairs(land.steal_info) do
        if value[1] then steal_success_count = steal_success_count + 1 end
    end
    local total = plant.uint * time_long * efficiency * (1 - 0.1 * steal_success_count) / 10
    total = math.floor(total * 0.1)
    local dsc_price = _get_dsc_price()
    local status = true

    -- 先质押罚金
    local forfeit = math.floor(total * dsc_price * 0.9)
    chainhelper:transfer_from_caller(contract_base_info.owner, forfeit,"COCOS",true)
    local luck_num = attrs.innate_attr.luck * 10 -- 福源加成
    local dog_num = dog_info.growt / 10 --狗提供的防御
    if random_number > ((land.star-1) * 200 + 5000 - luck_num + dog_num) then 
        chainhelper:log(contract_base_info.caller .. '偷取' .. (total/100000) .. token_id)
        -- 解锁并转发到账户
        if string.sub(token_id,1,1) ~= "[" then 
            chainhelper:log('收获' .. (total/100000) .. token_id)
            CToken.TransferOut(token_id, total)
        else 
            chainhelper:log('收获' .. total .. token_id)
            CPlayerItems.create_item_to_package(item_id, total)
        end
        -- 返还罚金
        chainhelper:transfer_from_owner(contract_base_info.caller, forfeit, "COCOS", true)
    else 
        status = false
        -- 把罚金95%送给农田主人
        local player_forfeit = math.floor(forfeit * 0.95)
        -- 返还罚金
        chainhelper:transfer_from_owner(nft_land.owner, player_forfeit, "COCOS", true) 
        -- log
        chainhelper:log(contract_base_info.caller .. '偷窃被抓,罚款' .. (forfeit/100000) .. "COCOS")
        total = player_forfeit
    end
    -- 记录到nft以备共享数据
    land.steal_count = land.steal_count + 1 -- 被偷次数+1
    land.steal_info[contract_base_info.caller] = {status, total} -- 记录偷盗者信息，方便报仇，雪恨
    nft_land[land_key] = land
    chainhelper:change_nht_active_by_owner(contract_base_info.caller, nft_id, false)
    chainhelper:nht_describe_change(nft_id,NFT_CONTRACT_INFO,cjson.encode(nft_land),false)
    chainhelper:change_nht_active_by_owner(contract_base_info.owner, nft_id, false)
end 

function KeepADog(args) 
    -- 喂狗可以减少被偷次数
    -- 喂狗消耗40DSC, 防御2个小时,冷却2小时10分钟，没喂一次增加成长值，成长值提高防御力
    CToken.TransferIn("DSC", 4000000)
    local farm = private_data.farm
    local attrs = private_data.attrs
    -- 狗的悟性，跟随人的悟性，狗即使是你，你既是狗，狗人合一，人狗不分
    local nft_id = private_data.farm.nft_id
    local nft_land = _get_nft_contract_info(nft_id)
    local dog_info =  nft_land.dog_info
    local now_time = chainhelper:time()
    if dog_info == nil then 
        dog_info = {
            growt = attrs.innate_attr.understanding,
            timestamp=now_time,
            kill_timestamp = 0,
            kill_acct = ""
        } 
    else 
        -- 冷却4小时
        assert((dog_info.timestamp + 240 * 60) < now_time, "#这条狗已经吃饱了，还没消化呢！#")
        dog_info.growt = dog_info.growt + attrs.innate_attr.understanding
        if dog_info.growt > 10000 then dog_info.growt = 10000 end
        dog_info.timestamp = now_time
    end
    nft_land.dog_info = dog_info
    chainhelper:log("喂狗成功,卞成苟暴走了...")
    chainhelper:change_nht_active_by_owner(contract_base_info.caller, nft_id, false)
    chainhelper:nht_describe_change(nft_id,NFT_CONTRACT_INFO,cjson.encode(nft_land),false)
    chainhelper:change_nht_active_by_owner(contract_base_info.owner, nft_id, false)
end

function KillADog(args) 
    -- 打狗 10 DSC一次
    local _args = cjson.decode(args)
    assert(#_args == 1, "#参数不对！#")
    local nft_id = _args[1]
    CToken.TransferIn("DSC", 1000000)
    local farm = private_data.farm
    local attrs = private_data.attrs
    assert(nft_id ~= farm.nft_id, "#不要打自己的狗#")
    local nft_land = _get_nft_contract_info(nft_id)
    local dog_info =  nft_land.dog_info
    assert(dog_info ~= nil,"#这条狗快饿死了，求放过！#")
    if dog_info.kill_timestamp == nil then dog_info.kill_timestamp = 0 end
    -- 30分钟可打一次
    assert((chainhelper:time() - dog_info.kill_timestamp) > (30 * 60), "#这条狗刚被打，求放过！#")
    -- 取决于打狗人的根骨，造成伤害
    dog_info.growt = dog_info.growt - math.floor(attrs.innate_attr.root_bone / 10)
    if dog_info.growt < 0 then dog_info.growt = 0 end
    dog_info.kill_timestamp = chainhelper:time()
    dog_info.kill_acct = contract_base_info.caller
    nft_land.dog_info = dog_info
    chainhelper:log("卞成苟被爆揍了一顿了...")
    chainhelper:change_nht_active_by_owner(contract_base_info.caller, nft_id, false)
    chainhelper:nht_describe_change(nft_id,NFT_CONTRACT_INFO,cjson.encode(nft_land),false)
    chainhelper:change_nht_active_by_owner(contract_base_info.owner, nft_id, false)
end

function Sacrifice(args) 
    local _args = cjson.decode(args)
    assert(#_args == 1, "#参数不对！#")
    local farm = private_data.farm
    assert(farm.Sacrifice ~= true, "#你已经献祭过了，不信可以刷新刷新！#")
    local COIN_SYMBOL = _args[1]
    local amount = G_CONFIG.SACRIFICE_COINS[COIN_SYMBOL]
    assert(amount ~= nil,"#不能用这个货币献祭！#")
    CToken.TransferIn(COIN_SYMBOL,amount)
    chainhelper:log("献祭成功！")
    farm.Sacrifice = true
end

function test() chainhelper:log('!- 3') end