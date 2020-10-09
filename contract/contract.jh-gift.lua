--
-- Created by IntelliJ IDEA.
-- User: wang
-- Date: 2020/10/9
-- Time: 下午4:08
-- To change this template use File | Settings | File Templates.
--
CONTRACT_NAME = "contract.jh-gift"

local function _public_data()
    return chainhelper:get_contract_public_data(CONTRACT_NAME)
end

function UpdateGiftInfo(gift_hash,gift_info)
    assert(chainhelper:is_owner(), "#没有权限！#")
    read_list = {public_data=true}
    chainhelper:read_chain()
    public_data[gift_hash] = gift_info
    chainhelper:write_chain()
end

function _AfterReceiveGift(gift_hash)
    read_list = {private_data=true }
    chainhelper:read_chain()
    assert(private_data[gift_hash] == nil,"#已经领取过了#")
    private_data[gift_hash] = true
    write_list = {private_data=true }
    chainhelper:write_chain()
end

function ReceiveGift(secret_code)
    local gift_hash = chainhelper:hash256(secret_code)
    local _public_data = _public_data()
    local gift_info =  _public_data[gift_hash]
    assert(gift_info ~= nil, "#暗号不正确！#")
    for i =1,#gift_info do CPlayerPackage.pickup_item(gift_info[i].cid, gift_info) end
    local args = {
        { 2, { v = gift_hash } }
    }
    chainhelper:invoke_contract_function(CONTRACT_NAME, "_AfterReceiveGift",
        cjson.encode(args))
end