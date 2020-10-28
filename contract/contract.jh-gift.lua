--
-- Created by IntelliJ IDEA.
-- User: wang
-- Date: 2020/10/9
-- Time: 下午4:08
-- To change this template use File | Settings | File Templates.
--
CONTRACT_NAME = "contract.jh-gift"
CONTRACT_CONFIGS = "contract.jh-configs"

local function _ContractConfig()
    if G_CONFIG == nil then
        G_CONFIG = import_contract(CONTRACT_CONFIGS)
    end
end

local function _public_data()
    return chainhelper:get_contract_public_data(CONTRACT_NAME)
end

function DelGiftInfo(gift_hash)
    assert(chainhelper:is_owner(), "#没有权限！#")
    read_list = {public_data={}}
    chainhelper:read_chain()
    public_data[gift_hash] = nil
    chainhelper:write_chain()
end

function AddGiftCount(gift_hash,user)
    assert(chainhelper:is_owner(), "#没有权限！#")
    read_list = {public_data={}}
    chainhelper:read_chain()
    local gift = public_data[gift_hash]
    gift.count = gift.count + 1
    if gift.receiver == nil then gift.receiver = {} end
    gift.receiver[user] = true
    chainhelper:write_chain()
end

function UpdateGiftInfo(gift_hash,gift_info)
    assert(chainhelper:is_owner(), "#没有权限！#")
    read_list = {public_data={}}
    chainhelper:read_chain()
    public_data[gift_hash] = cjson.decode(gift_info)
    chainhelper:write_chain()
end

function _AfterReceiveGift(gift_hash)
    _ContractConfig()
    assert(contract_base_info.invoker_contract_id == G_CONFIG.PLAYERS_CONTRACT_ID,
            "#没有权限！#")
    read_list = {private_data={},public_data={}}
    chainhelper:read_chain()
    assert(private_data[gift_hash] == nil,"#已经领取过了#")
    private_data[gift_hash] = {}
    if public_data[gift_hash].count then
        public_data[gift_hash].count = public_data[gift_hash].count - 1
    end
    local gift = public_data[gift_hash]
    if gift.receiver ~= nil then 
        assert(gift.receiver[contract_base_info.caller],"#你已经领过了，请到背包查看！#")
        gift.receiver[contract_base_info.caller] = nil
    end
    write_list = {private_data={}, public_data={}}
    chainhelper:write_chain()
end

function ReceiveGift(secret_code)
    local gift_hash = chainhelper:hash256(secret_code)
    local _public_data = _public_data()
    local gift_info =  _public_data[gift_hash]
    assert(gift_info ~= nil, "#暗号不正确！#")
    if gift_info.players ~= nil then 
        local player_in = false
        for i = 1,#player_in do
            if contract_base_info.caller == player_in[i] then 
                player_in = true
                break
            end
            assert(player_in, "#你沒有权限领取该礼包！#")
        end
    end
    if gift_info.count then
        assert(gift_info.count > 0, "#礼包被领光了，下次请早！#")
    end
    -- 减去礼包数量，记录已领取
    local args = {
        { 2, { v = gift_hash } }
    }
    chainhelper:invoke_contract_function(CONTRACT_NAME, "_AfterReceiveGift",
        cjson.encode(args))
    -- 将物品放进背包
    local gifts = gift_info.gifts
    for i =1,#gifts do CPlayerPackage.pickup_item(gifts[i].cid, gifts[i]) end
end