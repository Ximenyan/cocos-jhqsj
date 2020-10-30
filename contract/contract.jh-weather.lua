NFT_TIMES = 2 * 60 * 60
WEATHER_TIMES = 5 * 60
TOTAL = 21
PRICE = 10000000
CONTRACT_NAME = "contract.jh-weather"
CONTRACT_TOKEN = "contract.jh-token"
CONTRACT_CONFIGS = "contract.jh-configs"
NFT_CONTRACT_INFO = "nft_contract_info"
ITEMS_ID_1 = "g000100000"
ITEMS_ID_2 = "g000100001"
COIN_SYMBOL = "DSC"
local function _CToken() 
    CToken = import_contract(CONTRACT_TOKEN)
end

local function _ContractConfig()
    if G_CONFIG == nil then
        G_CONFIG = import_contract(CONTRACT_CONFIGS)
    end
end

local function _get_nft_contract_info(describe_with_contract) 
    for _, contract in pairs(describe_with_contract) do
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

local function _CreateWeatherBadge() 
    local base_info = {
        name="天气徽章",
        describe="据说每个村子里都有一个命运悲惨的少女被选作为掌控天气的人,她们的每一次祈祷都会燃烧自己的部分生命,直到整个人变成一块徽章！",
        icon="http://i2.tiimg.com/728062/e1fdb890ab749c53.png"
    }
    local id = chainhelper:create_nft_asset(contract_base_info.caller, 
        G_CONFIG.WORLD_VIEW,
        cjson.encode(base_info),false,false)
end
function init() 
    read_list = {public_data={}}
    chainhelper:read_chain()
    public_data.weather_table = {
        sunny=1,
        fog=1,
        rain=1,
        snow=2,
        cloud=1
    }
    public_data.timestamp = chainhelper:time()
    public_data.now_weather = "snow"
    public_data.hp = 100
    chainhelper:write_chain()
end

function _read_data() 
    read_list = {public_data={}}
    chainhelper:read_chain()
end

function _save_data() 
    chainhelper:write_chain()
end

function _Attack() 
    _ContractConfig()
    assert(contract_base_info.invoker_contract_id == G_CONFIG.PLAYERS_CONTRACT_ID,
            "#没有权限！#")
    _read_data()
    assert(public_data.hp > 0,"#小恶魔已经被击败了！#")
    public_data.hp = public_data.hp - (chainhelper:random() % 100 + 100)
    if public_data.hp < 0 then 
        public_data.hp = 0 
        _CreateWeatherBadge()
    end
    _save_data()
end

function BuyWeatherBadge(args) 
    _ContractConfig()
    -- 消耗150碎片
    CPlayerPackage.spent_item(ITEMS_ID_2, 150)
    -- 发放徽章
    _CreateWeatherBadge()
end

function Attack(args) 
    -- 消耗100南瓜
    CPlayerPackage.spent_item(ITEMS_ID_1, 100)
    -- 收入1-7碎片
    local item_amount = chainhelper:random() % 6 + 1
    CPlayerItems.create_item_to_package(ITEMS_ID_2, chainhelper:random() % 6 + 1)
    -- 收入随机数量的cocos
    local cocos_amount = chainhelper:random() % 60000000 + 90000000
    --CToken.TransferOut("COCOS",cocos_amount)
    chainhelper:log("获得" .. (cocos_amount/100000) .. "COCOS," .. item_amount .. "碎片")
    chainhelper:invoke_contract_function(CONTRACT_NAME, "_Attack", "[]")
end

function SetWeather(nft_id,weather)  
    _read_data() 
    assert(type(nft_id) == "string", "#参数NFT_ID不正确#")
    _ContractConfig()
    assert(string.sub(nft_id, 1, 4) == "4.2.",
            "#参数NFT_ID不正确#")
    local nft = cjson.decode(chainhelper:get_nft_asset(nft_id))
    local describe = cjson.decode(nft.base_describe)
    assert(nft.world_view == G_CONFIG.WORLD_VIEW, "#不是同一个世界观#")
    local describe_with_contract = _get_nft_contract_info(nft.describe_with_contract)  
    assert(describe.name == "天气徽章", "#这个不是天气徽章！#")  
    assert(nft.nh_asset_active == contract_base_info.caller,
            "#没有使用权!#")
    local old_weather = describe_with_contract.weather
    if describe_with_contract.timestamp == nil then describe_with_contract.timestamp = 0 end WEATHER_TIMES
    assert((chainhelper:time() - describe_with_contract.timestamp) > NFT_TIMES,"#nft冷却中！#") 
    assert((chainhelper:time() - public_data.timestamp) > WEATHER_TIMES,"#少女的祈祷正在冷却中！#") 

    local weather_table = public_data.weather_table
    assert(weather_table[weather]~=nil,"#参数错误！#")
    if old_weather ~= nil then weather_table[old_weather] = weather_table[old_weather] - 1 end
    weather_table[weather] = weather_table[weather] + 1
    describe_with_contract.timestamp = chainhelper:time()
    public_data.timestamp = chainhelper:time()
    describe_with_contract.weather = weather
    chainhelper:nht_describe_change(nft_id, NFT_CONTRACT_INFO, cjson.encode(describe_with_contract), false)
    _save_data()
end 


