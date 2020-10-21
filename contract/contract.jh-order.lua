PRECISION = 100000
CONTRACT_FARMS = "contract.jh-farms"
CONTRACT_CONFIGS = "contract.jh-configs"
NFT_CONTRACT_INFO = "NFT_CONTRACT_INFO"

local RATE = { 
    DSC=0.01,
    COCOS=0.05
}

local function _ContractConfig()
    if G_CONFIG == nil then
        G_CONFIG = import_contract(CONTRACT_CONFIGS)
    end
end

local function _get_nft_contract_info(nft_id) 
    local nft = cjson.decode(chainhelper:get_nft_asset(nft_id))
    assert(nft.world_view == G_CONFIG.MATCH_UP_WORLD_VIEW, "#世界观不正确！#")
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

local function _create_match_up() 
    local base_info = {
        name =  private_data.attrs.name .. "的市场"
    }
    local nft_id = chainhelper:create_nft_asset(
        contract_base_info.owner,
        G_CONFIG.MATCH_UP_WORLD_VIEW,
        cjson.encode(base_info),true,true)
    private_data.match_up = nft_id
end


function sell_order(args) 
    -- 挂单
    _ContractConfig()
    assert(contract_base_info.caller == "1.2.29340","#测试中。。。#")
    local _args = cjson.decode(args)
    assert(#_args == 4, "#参数不对！")
    local cid = _args[1]
    local price = _args[2]
    local count = _args[3]
    local coin_type = _args[4]
    assert(type(cid) == "string", "#参数1类型不对！#") -- CID
    assert(type(price) == "number", "#参数2类型不对！#") -- 价格
    assert(price > 0, "#单价需要大于0！#") -- 价格
    assert(count > 0, "#数量需要大于0！#") -- 数量
    count = math.floor(count)
    assert(type(coin_type) == "string", "#参数2类型不对！#") -- 数量
    assert(coin_type == "DSC" or coin_type == "COCOS", "#货币类型类型不对！#") -- 数量
    local max_number = chainhelper:number_max()
    assert(price * count * PRECISION < max_number, "#定价超过最大值了！#")
    local package = private_data.backpack
    local nft_id = private_data.match_up
    local nft = nil
    if private_data.match_up == nil then 
        _create_match_up() 
        nft_id = private_data.match_up
        nft = {
            owner = contract_base_info.caller,
            order_id = 0,
            sell = {},
            purchase = {},
            auction = {}
        }
    else
        nft = _get_nft_contract_info(nft_id)
    end
    local good = package.goods[cid]
    assert(good ~= nil,"#你没有这个物品！#")
    assert(good.count >= count, "#数量不够！#")
    assert(good.base_info.isNft == true, "#绑定道具不能出售！#")
    local order_id = cid .."-".. nft_id .. "-" .. nft.order_id
    nft.sell[order_id] = {}
    nft.sell[order_id].base_info = good.base_info
    nft.sell[order_id].price = price
    nft.sell[order_id].coin_type = coin_type
    nft.sell[order_id].count = count
    nft.order_id = nft.order_id+1
    -- 先释放掉这部分 物品
    CPlayerPackage.spent_item(cid, count)
    -- 写入NFT
    chainhelper:change_nht_active_by_owner(contract_base_info.caller, nft_id, false)
    chainhelper:nht_describe_change(nft_id,NFT_CONTRACT_INFO,cjson.encode(nft),false)
    chainhelper:change_nht_active_by_owner(contract_base_info.owner, nft_id, false)
    -- 打印log
    chainhelper:log('创建订单：'.. order_id  ..",数量:" ..count .. ",价格:"..price)
end

function fill_order(args) 
    -- 吃单
    assert(contract_base_info.caller == "1.2.29340","#测试中。。。#")
    _ContractConfig()
    local _args = cjson.decode(args)
    assert(#_args == 4, "#参数不对！")
    local nft_id = _args[1]
    local order_id = _args[2]
    local count = _args[3]
    local coin_type = _args[4]
    assert(type(nft_id) == "string", "#nft_id类型不对！#") -- nft_id
    assert(type(order_id) == "string", "#order_id类型不对！#") -- CID
    assert(type(count) == "number", "#count类型不对！#") -- 价格
    count = math.floor(count)
    assert(count > 0, "#购买数量需要大于0#")
    assert(coin_type == "DSC" or coin_type == "COCOS", "#货币类型类型不对！#") -- 数量
    local nft = _get_nft_contract_info(nft_id)
    assert(nft.sell ~= nil, "#nft_id 错误！#")
    assert(nft.owner ~= contract_base_info.caller,"#不能买自己的东西！#")
    local sell_good = nft.sell[order_id]
    assert(sell_good ~= nil,"#物品已经不在了！#")
    local cid = sell_good.base_info.cid
    assert(sell_good.count >= count, "#剩余的没那么多了！#")
    -- 先转钱
    local amount = math.floor(sell_good.price * count * PRECISION) 
    local rate_amount =  math.floor(amount * RATE[coin_type])
    chainhelper:transfer_from_caller(nft.owner,amount,coin_type,true)
    -- 买家出手续费
    chainhelper:transfer_from_caller(G_CONFIG.ASSET_ACCEPT_ACCOUNT, rate_amount, coin_type, true)
    -- 放入买家背包
    sell_good.base_info.count = count
    CPlayerPackage.pickup_item(cid,sell_good.base_info)
    if sell_good.count > count then 
        sell_good.count = sell_good.count - count 
    else
        nft.sell[order_id] = nil
    end
    -- 写入市场
    chainhelper:change_nht_active_by_owner(contract_base_info.caller, nft_id, false)
    chainhelper:nht_describe_change(nft_id,NFT_CONTRACT_INFO,cjson.encode(nft),false)
    chainhelper:change_nht_active_by_owner(contract_base_info.owner, nft_id, false)
    -- 打印log
    chainhelper:log(contract_base_info.caller .. "购买了" .. order_id .. ",数量:" .. count .. ",价格:".. sell_good.price)
end

function del_order(args) 
    assert(contract_base_info.caller == "1.2.29340","#测试中。。。#")
    -- 撤单
    _ContractConfig()
    local _args = cjson.decode(args)
    assert(#_args == 1, "#参数不对！")
    -- 这能保证撤自己的单
    local nft_id = private_data.match_up
    local order_id = _args[1]
    assert(type(order_id) == "string", "#order_id类型不对！#") -- CID
    local nft = _get_nft_contract_info(nft_id)
    assert(nft.sell ~= nil, "#nft_id 错误！#")
    local sell_good = nft.sell[order_id]
    assert(sell_good ~= nil,"#物品已经不在了！#")
    local cid = sell_good.base_info.cid
    -- 放入玩家背包
    sell_good.base_info.count = count
    CPlayerPackage.pickup_item(cid,sell_good.base_info)
    nft.sell[order_id] = nil
    -- 写入市场
    chainhelper:change_nht_active_by_owner(contract_base_info.caller, nft_id, false)
    chainhelper:nht_describe_change(nft_id,NFT_CONTRACT_INFO,cjson.encode(nft),false)
    chainhelper:change_nht_active_by_owner(contract_base_info.owner, nft_id, false)
    -- 打印log
    chainhelper:log(contract_base_info.caller .. "撤销了" .. order_id )
end


function purchase_order(args) 
    assert(false,"功能暂不开放！")
    -- 收购单
end

function auction_order(args) 
    -- 拍卖单
    assert(false,"功能暂不开放！")
end