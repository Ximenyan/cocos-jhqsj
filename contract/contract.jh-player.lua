---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by wang.
--- DateTime: 10/7/20 2:20 AM
---
BASE_HP = 300
BASE_MP = 50
BASE_ATTACK = 10
BASE_DEFENSE = 5
BASE_ANALYSIS = 2
BASE_DODGE = 1
BASE_CRIT = 0
BASE_KNOWLEDGE = 0

function init()
    read_list = {private_data = {attrs = true}}
    chainhelper:read_chain()
end

function write_attrs()
    write_list = {private_data = {attrs = true}}
    chainhelper:write_chain()
end

-- 更新根骨
local function update_root_bone(root_bone,isAdd)
    local root_bone_num =  root_bone - attrs.innate_attr.root_bone
    local acquired_attr = attrs.acquired_attr
    acquired_attr.attack = math.floor(root_bone_num * 0.4 + acquired_attr.attack)
    acquired_attr.defense= math.floor(root_bone_num * 0.2 + acquired_attr.defense)
    acquired_attr.hp  = math.floor(root_bone_num * 10 + acquired_attr.hp)
    acquired_attr.mp  = math.floor(root_bone_num * 3 + acquired_attr.mp)
    attrs.innate_attr.root_bone = root_bone
end

-- 更新悟性
local function update_understanding(understanding, isAdd)
    local understanding_num =  understanding - attrs.innate_attr.understanding
    local acquired_attr = attrs.acquired_attr
    acquired_attr.crit = math.floor(understanding_num * 0.1 + acquired_attr.crit)
    acquired_attr.mp = math.floor(understanding_num * 8 + acquired_attr.mp)
    acquired_attr.analysis = math.floor(understanding_num * 0.1 + acquired_attr.analysis)
    attrs.innate_attr.understanding = understanding
end

-- 更新福缘
local function update_luck(luck)
    local luck_num =  luck - attrs.innate_attr.luck
    local acquired_attr = attrs.acquired_attr
    acquired_attr.dodge = math.modf(luck_num * 0.3 + acquired_attr.dodge)
    acquired_attr.hp = math.modf(luck_num * 15 + acquired_attr.dodge)
    attrs.innate_attr.luck = luck
end

local functab = {
    root_bone=update_root_bone,
    understanding=update_understanding,
    unluck=update_luck
}

function update_innate_attr(k,value)
    local _new_value = value + attrs.innate_attr[k]
    functab[k](_new_value)
end

-- 创建角色
function register(args)
    assert(type(args) == "string", "#1#Error::register args mast be string!!!")
    assert(attrs == nil, '#2#Error:must be not register!')
    local args_table = cjson.decode(args)
    assert(type(args_table) == "table", "#2#Error::args error!!!!")
    assert(type(args_table.name) == "string", "#2#Error::args error!!!!")
    assert(type(args_table.gender) == "number", "#2#Error::args error!!!!")
    assert(type(args_table.root_bone) == "number", "#2#Error::args error!!!!")
    assert(type(args_table.understanding) == "number",
            "#2#Error::args error!!!!")
    assert(type(args_table.luck) == "number", "#2#Error::args error!!!!")
    private_data.attrs = {
        name = "",
        cid=contract_base_info.caller,
        gender = 0,
        master = "",--师父
        sects = "mp00",--门派 平民
        exps = 100,
        age = 14, -- 年龄
        innate_attr = {root_bone = 0, understanding = 0, luck = 0},
        acquired_attr = {
            attack = BASE_ATTACK,
            defense = BASE_DEFENSE,
            dodge = BASE_DODGE,
            analysis = BASE_ANALYSIS,
            hp = BASE_HP,
            mp = BASE_MP,
            crit = BASE_CRIT,
            knowledge = BASE_KNOWLEDGE
        }
    }
    attrs = private_data.attrs
    assert(args_table.name ~= nil and args_table.name ~= "",
            "#3#Error:args error!") -- 姓名
    assert(args_table.gender ~= nil and args_table.gender <= 1 and 0 <=
            args_table.gender, "#Error:args error!") -- 性别
    assert(args_table.root_bone ~= nil and args_table.root_bone <= 60 and 0 <
            args_table.root_bone, "#Error:args error!") -- 根骨
    assert(
            args_table.understanding ~= nil and args_table.understanding <= 60 and 0 <
                    args_table.understanding, "#Error:args error!") -- 悟性

    assert(args_table.luck ~= nil and args_table.luck <= 60 and 0 <
            args_table.luck, "#Error:args error!") -- 福源
    -- 三种先天属性必须不多不少90点
    assert(args_table.luck + args_table.root_bone + args_table.understanding ==
            90, "#Error:args error!")
    -- 更新这该死的属性
    update_luck(args_table.luck)
    update_understanding(args_table.understanding)
    update_root_bone(args_table.root_bone)
    attrs.name = args_table.name
    attrs.gender = args_table.gender
    -- 存储
    write_attrs()
end
function test() chainhelper:log('!- 3') end