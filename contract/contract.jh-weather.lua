TIMES = 24 * 60 * 60
TOTAL = 21
PRICE = 10000000
CONTRACT_TOKEN = "contract.jh-token"
CONTRACT_CONFIGS = "contract.jh-configs"
COIN_SYMBOL = "DSC"
local function _CToken() 
    CToken = import_contract(CONTRACT_TOKEN)
end

local function _ContractConfig()
    if G_CONFIG == nil then
        G_CONFIG = import_contract(CONTRACT_CONFIGS)
    end
end

function init() 
    read_list = {public_data={}}
    chainhelper:read_chain()
    public_data.weather_table = {
        sunny=1,
        rain=1,
        snow=1,
        cloud=1
    }
    public_data.total = 0
    chainhelper:write_chain()
end

function _read_data() 
    read_list = {public_data={}}
    chainhelper:read_chain()
end

function _save_data() 
    chainhelper:write_chain()
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
    local describe_with_contract = nft.describe_with_contract  
    assert(describe.name == "天气徽章", "#这个不是天气徽章！#")  
    assert(nft.nh_asset_active == contract_base_info.caller,
            "#没有使用权!#")
    local old_weather = describe_with_contract.weather
    if describe_with_contract.timestamp == nil then describe_with_contract.timestamp = 0 end
    assert((chainhelper:time() - describe_with_contract.timestamp) > TIMES,"#冷却中！#") 
    local weather_table = public_data.weather_table
    assert(weather_table[weather]~=nil,"#参数错误！#")
    if old_weather ~= nil then weather_table[old_weather] = weather_table[old_weather] - 1 end
    weather_table[weather] = weather_table[weather] + 1
    chainhelper:nht_describe_change(nft_id, "timestamp", chainhelper:time(), true)
    chainhelper:nht_describe_change(nft_id, "weather", weather, true)
    _save_data()
end 

function BuyWeatherBadge() 
    _read_data() 
    _ContractConfig()
    assert(public_data.total < TOTAL, "#天选之人数量已经足够了！#")
    public_data.total = public_data.total + 1
    _CToken()
    CToken.TransferIn(COIN_SYMBOL, PRICE)
    local base_info = {
        name="天气徽章",
        describe="据说每个村子里都有一个命运悲惨的少女被选作为掌控天气的人,她们的每一次祈祷都会燃烧自己的部分生命,直到整个人变成一块天气徽章！",
        icon="http://i2.tiimg.com/728062/e1fdb890ab749c53.png"
    }
    local id = chainhelper:create_nft_asset(contract_base_info.caller, 
        G_CONFIG.WORLD_VIEW,
        cjson.encode(base_info),false,false)
    chainhelper:log(id)
    _save_data()
end
