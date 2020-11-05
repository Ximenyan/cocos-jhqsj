DEVELOPER_PROPORTION = 0.02 --开发者占比
BOUNS_PROPORTION = 0.48 --分红占比
FINAL_PRIZE = 0.35 --最终大奖
WIN_COUNTRY = 0.15 --获胜国家分红

local function _read_data()
    -- 读数据
    read_list = {public_data = {}, private_data = {}}
    chainhelper:read_chain()
end

local function _save_data()
    -- 写数据
    write_list = {public_data = {}, private_data = {}}
    chainhelper:write_chain()
end

function init()
    assert(chainhelper:is_owner(), "#没有权限#")
    _read_data()
    --assert(public_data.count == nil, "#游戏已经开始了#");
    public_data = {
        count = 0, -- 轮数
        total_amout = 0,--总流水
        count_amount = 0,--本轮总流水
        win_country_amount = 0,--获胜国家分红
        final_prize = 0,--最终大奖
        timestamp = chainhelper:time() + 24 * 60 * 60,
        countrys = {
            Wei = {num = 0, price = 0},
            Shu = {num = 0, price = 0},
            Wu = {num = 0, price = 0}
        }
    }
    _save_data()
end

function Buy(arg_country, arg_num)
    _read_data()
    arg_num = math.floor(arg_num)
    if public_data.winner ~= nil and chainhelper:time() > public_data.timestamp then
        -- 这一轮战争已经结束了，作为开奖人，将获得最终大奖的1%，然后开启下一轮战争
        -- 最终大奖的99% 将归终结者所有
        local winner_amount = math.floor(public_data.final_prize * 0.99) --这是发给获胜人的
        chainhelper:log(public_data.winner .. '  Won the war！amount :' .. (winner_amount/100000))
        local call_amount = public_data.final_prize - winner_amount -- 这是发给开奖人的
        chainhelper:log(contract_base_info.caller .. ' Draw a prize! amount :' .. (call_amount/100000))
        local win_country = public_data.countrys[public_data.win_country]
        chainhelper:log(public_data.win_country .. ' Carve Up Amount :' .. (public_data.win_country_amount/100000))
        win_country.price = win_country.price + math.floor(public_data.win_country_amount/win_country.num) --分红给战胜国
        public_data.count = public_data.count + 1
        public_data.count_amount = 0
        public_data.win_country_amount = 0
        public_data.final_prize = 0
        public_data.timestamp = chainhelper:time() + 24 * 60 * 60 --战争时间新增一天
        chainhelper:log(public_data.win_country .. " Won the war!A new round of war has begun!")
    end
    if private_data.countrys == nil then 
        private_data.countrys ={
            Wei = {num = 0, price = 0},
            Shu = {num = 0, price = 0},
            Wu = {num = 0, price = 0}
        }
    end
    local public_country = public_data.countrys[arg_country]
    local private_country = private_data.countrys[arg_country]
    local amount = arg_num * 10000000
    local bonus_amount = math.floor(amount * BOUNS_PROPORTION / 3)
    local final_prize = math.floor(amount * FINAL_PRIZE)
    local dev_amount = math.floor(amount * DEVELOPER_PROPORTION)
    local win_country_amount = math.floor(amount * WIN_COUNTRY)
    for name, country in pairs(public_data.countrys) do
        if country.num ~= 0 then 
            public_data.countrys[name].price = country.price + math.floor(bonus_amount/country.num)
        end
    end
    if private_country.num == 0 then
        private_country.price = public_country.price
    else
        local sub_price = public_country.price - private_country.price
        local bonus_total = sub_price * private_country.num
        local proportion = bonus_total / (private_country.num + arg_num)
        local new_sub_price =  math.ceil(public_country.price - proportion)
        private_country.price = new_sub_price
    end
    private_country.num = private_country.num + arg_num
    public_country.num = public_country.num + arg_num
    public_data.total_amout = public_data.total_amout + math.floor(amount/100000) -- 总流水
    public_data.final_prize = public_data.final_prize + final_prize --最终大奖
    public_data.timestamp = public_data.timestamp + arg_num * 10 -- 战争时间延长
    public_data.win_country = arg_country -- 记录领先国家
    public_data.winner = contract_base_info.caller -- 记录领先玩家
    public_data.win_country_amount = public_data.win_country_amount + win_country_amount
    _save_data()
end

function Withdraw()
    -- public_data = {}
    private_data = {}
    write_list = {private_data = {}}
    chainhelper:write_chain()
end

function clear()
    -- public_data = {}
    private_data = {}
    write_list = {private_data = {}}
    chainhelper:write_chain()
end
