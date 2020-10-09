---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by wang.
--- DateTime: 10/7/20 2:20 AM
---

-- 其它子合约
PACKAGE_CONTRACT = "contract.jh-package"
ITEMS_CONTRACT = "contract.jh-itemfactory"
ATTRS_CONTRACT = "contract.jh-player"
FARMS_CONTRACT  = "contract.jh-farms"
TOKEN_CONTRACT = "contract.jh-token"
GIFT_CONTRACT = "contract.jh-gift"
CONTRACT_CONFIGS = "contract.jh-configs"

local function _ContractConfig()
    if G_CONFIG == nil then
        G_CONFIG = import_contract(CONTRACT_CONFIGS)
    end
end

local function _initPrivateData()
    read_list = { private_data = {} }
    chainhelper:read_chain()
end
local function c(name)
    if G_CONFIG == nil then _ContractConfig() end
    local contract = import_contract(name)
    contract.G_CONFIG = G_CONFIG
    contract.private_data = private_data
    return contract
end

local function PlayerAttr() return c(ATTRS_CONTRACT) end
local function PlayerPackage() return c(PACKAGE_CONTRACT)end
local function PlayerFarms() return c(FARMS_CONTRACT) end
local function PlayerItems() return c(ITEMS_CONTRACT) end
local function TokenContract() return c(TOKEN_CONTRACT) end
local function GiftContract() return c(GIFT_CONTRACT) end

local function _check_account()
    _ContractConfig()
    if G_CONFIG.TEST then
        assert(contract_base_info.caller == G_CONFIG.TEST_ACCOUNT,
                "#测试账户不对！")
    end
end

-- 注销账号
function destroy()
    private_data = {}
    chainhelper:write_chain()
end

-- 注册
function register(args)
    _check_account()
    -- 读取数据
    _initPrivateData()
    private_data.ver = G_CONFIG.VER
    -- 创建角色属性
    PlayerAttr().register(args)
    -- 创建角色背包
    PlayerPackage().create()
    -- 创建农田
    PlayerFarms().create()
    chainhelper:write_chain()
end

-- 农场相关接口
function farms(method, args)
    _check_account()
    _initPrivateData()
    local CPlayerFarms = PlayerFarms()
    CPlayerFarms.CToken = TokenContract()
    CPlayerFarms.CPlayerItems = PlayerItems()
    CPlayerFarms.CPlayerPackage = PlayerPackage()
    CPlayerFarms.CPlayerItems.CPlayerPackage =  CPlayerFarms.CPlayerPackage
    CPlayerFarms[method](args)
    chainhelper:write_chain()
end

-- 提取NFT
function WithdrawNFT(cid,num)
    _check_account()
    _initPrivateData()
    local CPlayerPackage = PlayerPackage()
    CPlayerPackage.withdraw(cid,num)
    chainhelper:write_chain()
end

-- 充值NFT
function RechargeNFT(nft_id)
    _check_account()
    _initPrivateData()
    local CPlayerPackage = PlayerPackage()
    CPlayerPackage.recharge(nft_id)
    chainhelper:write_chain()
end

-- 丢弃
function Discard(cid, num)
    _check_account()
    _initPrivateData()
    local CPlayerPackage = PlayerPackage()
    CPlayerPackage.spent_item(cid,num)
    chainhelper:write_chain()
end

--暗号领取礼物
function ReceiveGift(secret_code)
    _check_account()
    _initPrivateData()
    local CGiftContract = GiftContract()
    CGiftContract.CPlayerPackage = PlayerPackage()
    CGiftContract.ReceiveGift(secret_code)
    chainhelper:write_chain()
end